// Copyright (c) 2024 Fabrizio Guidotti
//
// This software is released under the MIT License.
// https://opensource.org/licenses/MIT

import 'dart:typed_data';

import 'package:readers/src/buffer.dart';

/// A class that represents a cursor with a position that can be advanced or reset.
///
/// The [Cursor] class provides methods to advance the cursor position by a specified
/// count, either returning the new position or the old position before advancing.
/// It also allows resetting the cursor position to zero.
class Cursor {
  /// Creates a [Cursor] with an optional initial position.
  ///
  /// If no initial position is provided, the cursor starts at position 0.
  Cursor([this._position = 0]);

  /// The current position of the cursor.
  int get position => _position;
  int _position;

  /// Advances the cursor position by the given [count] and returns the *new* position.
  ///
  /// [count] The number of positions to advance.
  int advance(int count) => _position += count;

  /// Advances the cursor position by the given [count] and returns the *old* position.
  ///
  /// [count] The number of positions to advance.
  int advancePost(int count) {
    final oldPosition = _position;
    _position += count;
    return oldPosition;
  }

  /// Resets the cursor position to zero.
  void reset() => _position = 0;
}

/// A subclass of Cursor, providing a [pivot] position,
/// which can be used to ease the slicing of buffers.
/// The [pivot] position is used as the starting point for the slice.
/// The [end] position is the current position of the cursor.
///
/// Maybe counterintuitively, the [pivot] position is the starting point of the slice,
/// and any method working with the cursor will use the [position] as the current position.
final class SliceCursor extends Cursor {
  // ignore: use_super_parameters
  SliceCursor.collapsed([this.pivot = 0]) : super(pivot);

  /// The starting position of the slice.
  int pivot;

  /// The end position of the slice.
  /// this is really just a convenience method for the current position,
  /// to try to make the code more intuitive.
  /// (Similarly the [start] property is a convenience method for the [pivot] position.)
  @pragma('vm:prefer-inline')
  int get end => position;

  /// The starting position of the slice.
  @pragma('vm:prefer-inline')
  int get start => pivot;

  /// The length of the slice.
  int get length => end - pivot;

  /// Collapses the slice to the given [position].
  int collapse([int? position]) => pivot = _position = position ?? end;

  /// Slices a portion of the buffer from the current pivot to the specified end position.
  ///
  /// If the end position is not provided, it defaults to the current position.
  /// The pivot is then updated to the current position (effectively collapsing the slice).
  Uint8List slice<B extends Buffer>(B buffer, [int? end]) {
    final sliceEnd = end ?? position;
    final bytes = buffer.getBytesView(pivot, sliceEnd);
    pivot = position;
    return bytes;
  }

  @override
  String toString() => 'Slice(pivot: $pivot, position: $position)';
}
