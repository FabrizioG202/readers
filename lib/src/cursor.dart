// Copyright (c) 2024 Fabrizio Guidotti
//
// This software is released under the MIT License.
// https://opensource.org/licenses/MIT

/// A class that represents a cursor with a position that can be advanced or reset.
///
/// The [Cursor] class provides methods to advance the cursor position by a specified
/// count, either returning the new position or the old position before advancing.
/// It also allows resetting the cursor position to zero.
final class Cursor {
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
