// Copyright (c) 2024 Fabrizio Guidotti
//
// This software is released under the MIT License.
// https://opensource.org/licenses/MIT

import 'dart:math';
import 'dart:typed_data';

import 'package:readers/src/cursor.dart';
import 'package:readers/src/parse_result.dart';

abstract interface class Buffer {
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
      yield ReadRequest(count: newLength - length);
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
    var newChunkEnd = newChunkStart = startFrom ?? length;

    do {
      yield const ReadRequest();
      newChunkEnd = length;
    } while (
        // Nothing was added to the buffer.
        // ? Maybe here we might want to notify the user
        // Since we are not making any progress and this might be an infinite loop
        newChunkEnd >= newChunkStart &&
            !predicate(
              getBytesView(newChunkStart, newChunkStart = newChunkEnd),
            ));
  }

  /// Positions the cursor at the position of the byte.
  Iterable<ReadRequest> findByte(Cursor cursor, {required int byte}) =>
      extendUntil(
        (chunk) {
          final index = chunk.indexOf(byte);
          cursor.advance(
            switch (index) {
              -1 => chunk.length,
              _ => index,
            },
          );

          return index >= 0;
        },
        startFrom: cursor.position,
      );

  /// Clear the buffer and dispose any underlying resources.
  void clear();
}

/// A naive implementation of a buffer that stores bytes in a [Uint8List].
/// and grows the list by copying the old data to a new list.
final class BytesBuffer extends Buffer {
  BytesBuffer([int initialSize = 0]) : _data = Uint8List(initialSize);
  Uint8List _data;

  @override
  int get length => _data.length;

  @override
  void grow(Uint8List bytes) => _data = Uint8List(_data.length + bytes.length)
    ..setAll(0, _data)
    ..setAll(_data.length, bytes);

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
