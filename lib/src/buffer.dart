// Copyright (c) 2024 Fabrizio Guidotti
//
// This software is released under the MIT License.
// https://opensource.org/licenses/MIT

import 'dart:math';
import 'dart:typed_data';

import 'package:readers/src/cursor.dart';
import 'package:readers/src/parse_result.dart';

abstract base class Buffer {
  /// Current length of the buffer in bytes.
  int get length;

  /// Grows (extends) the buffer with the given bytes.
  void grow(Uint8List bytes);

  /// Returns a view of the buffer from [start] to [end] (exclusive).
  /// If [start] is not provided, it defaults to 0.
  /// if [end] is not provided, it defaults to [length].
  Uint8List getBytesView([int start = 0, int? end]);

  /// Yields read requests until the buffer reaches the given [newLength].
  Iterable<ReadRequest> extendToLength(int newLength) sync* {
    while (length < newLength) {
      yield ExactReadRequest(count: newLength - length);
    }
  }

  /// Requests new chunks until the given predicate is met
  /// [predicate]'s [newDataView] is a view on a range of the buffer,
  /// of the length of the last chunk added.
  Iterable<ReadRequest> extendUntil(
    bool Function(Uint8List newDataView) predicate, {
    int? startFrom,
  }) sync* {
    var newChunkStart = startFrom ?? length;
    var newChunkEnd = newChunkStart;

    do {
      // Problem: this also yields a read request when the range is already in the buffer.
      yield const PartialReadRequest();
      newChunkEnd = length;
    } while (
        // Nothing was added to the buffer.
        // ? Maybe here we might want to notify the user
        // Since we are not making any progress and this might be an infinite loop
        newChunkEnd > newChunkStart &&
            !predicate(
              getBytesView(newChunkStart, newChunkStart = newChunkEnd),
            ));
  }

  /// Positions the cursor at the first occurrence of the byte.
  Iterable<ReadRequest> advanceToByte(
    Cursor cursor, {
    required int byte,
  }) =>
      extendUntil(
        (Uint8List chunk) {
          final index = chunk.indexOf(byte);

          cursor.advance(
            switch (index) {
              -1 => chunk.length,
              _ => index + 1,
            },
          );

          return index >= 0;
        },
        startFrom: cursor.position,
      );

  /// Clear the buffer and dispose any underlying resources.
  void clear();

  /// ! The function below are not implemented
  /// as their utility is currently being evaluated.
  int get capacity => throw UnimplementedError();
  void ensureCapacity() => throw UnimplementedError();
  void trimToSize() => throw UnimplementedError();
}

/// A naive implementation of a buffer that stores bytes in a [Uint8List]
/// and grows the list by copying the old data to a new list.
final class ByteAccumulator extends Buffer {
  ByteAccumulator([int initialSize = 0]) : _data = Uint8List(initialSize);
  ByteAccumulator.withData(Uint8List data) : _data = Uint8List.fromList(data);

  Uint8List _data;

  @override
  int get length => _data.length;

  @override
  void grow(Uint8List bytes, {int? position}) {
    if (position == null || position >= _data.length) {
      // Append mode - same as original behavior
      final newData = Uint8List(_data.length + bytes.length)
        ..setAll(0, _data)
        ..setAll(_data.length, bytes);
      _data = newData;
    } else {
      // Insert/replace at position
      final endPosition = position + bytes.length;
      final newLength = max(endPosition, _data.length);
      final newData = Uint8List(newLength)
        // Copy data before position
        ..setAll(0, _data.sublist(0, position))
        // Insert new bytes
        ..setAll(position, bytes);

      // If we're not at the end, copy remaining data
      if (endPosition < _data.length) {
        newData.setAll(endPosition, _data.sublist(endPosition));
      }

      _data = newData;
    }
  }

  @override
  Uint8List getBytesView([int start = 0, int? end]) {
    if (end != null) end = min(end, length);
    return _data.sublist(start, end);
  }

  @override
  void clear() => _data = Uint8List(0);

  @override
  String toString() => 'BytesBuffer($_data)';
}
