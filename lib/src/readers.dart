import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:meta/meta.dart';

typedef ParseIterable<T> = Iterable<ParseEvent<T>>;
typedef ParserGenerator<T> = ParseIterable<T> Function(ByteAccumulator buffer);

@immutable
sealed class ParseEvent<T> {
  const ParseEvent();
}

@immutable
final class ParseResult<T> extends ParseEvent<T> {
  final T result;
  const ParseResult(this.result);

  @override
  String toString() => 'ParseResult($result)';
}

/// Just an utility class so that we can quickly create
/// a dichotomy between ParseResults and type-independent
/// events, such as [CollapseBuffer] or [RequestRangeForReading].
/// so that they can be easily passed around in nested parse generators.
sealed class TransitEvent extends ParseEvent<Never> {
  const TransitEvent();
}

/// Request for the underlying buffer to be collapsed at the current position.
/// This is useful to let the parser known that we no longer care about the contents
/// of the buffer, and is useful since we will then be able to reuse the buffer
/// for the next read.
///
/// TODO (?) Might be useful to add a parameter to specify the new offset.
@immutable
final class CollapseBuffer extends TransitEvent {
  const CollapseBuffer();
}

/// Ensures that the specified range is available in the buffer.
/// NOTE: this does not guarantee that the buffer will be filled with bytes
/// but only that we have the space to both read and write the bytes.
@immutable
final class RequestRangeForReading extends TransitEvent {
  const RequestRangeForReading(this.firstOffset, this.lastOffset);

  // ignore: avoid_multiple_declarations_per_line
  final int firstOffset, lastOffset;

  @override
  String toString() => 'RangeReadRequest($firstOffset, $lastOffset)';

  @override
  bool operator ==(Object other) {
    return other is RequestRangeForReading &&
        other.firstOffset == firstOffset &&
        other.lastOffset == lastOffset;
  }

  @override
  int get hashCode => firstOffset.hashCode ^ lastOffset.hashCode;
}

/// A source of bytes.
abstract class Source {
  void open();
  void close();
}

/// A source that can read bytes into a buffer.
abstract mixin class SourceReadIntoMixin {
  FutureOr<int> readInto<T extends List<int>>(T buffer, int start, int end);
}

/// Synchronous file source that reads bytes from a file.
class SyncFileSource implements SourceReadIntoMixin, Source {
  SyncFileSource(this.file);

  final File file;
  RandomAccessFile? _raf;

  @override
  void open() => _raf = file.openSync();

  @override
  void close() => _raf?.closeSync();

  @override
  int readInto<T extends List<int>>(T buffer, int start, int end) {
    if (_raf case final raf?) {
      raf.setPositionSync(start);
      return raf.readIntoSync(buffer, 0, end - start);
    }

    throw StateError('The file is not open');
  }
}

/// Provides a plarform upon which buffer generators can be run
/// handling the buffer management and the reading of bytes from
/// the provided [source].
Iterable<T> parseSync<T>(
  ParserGenerator<T> generator,
  SyncFileSource source, {
  int initialBufferSize = 1024,
}) sync* {
  final buffer = ByteAccumulator.zeros(initialSize: initialBufferSize);

  for (final message in generator(buffer)) {
    switch (message) {
      case CollapseBuffer():
        buffer.softClampEnd(buffer.offset);

      case RequestRangeForReading(
        firstOffset: final start,
        lastOffset: final end,
      ):
        // ensure that the buffer hass space for the bytes
        buffer.trimToRange(startOffset: start, endOffset: end);

        // read the bytes into the buffer
        // TODO (?) we might not need to create a view here,
        // TODO (?) since the readInto method should be able to handle
        // TODO (?) the offset.
        final int readCount = source.readInto(
          buffer.viewRelative(start),
          start,
          end,
        );

        // soft clamp it to be sure that if we read, for example 0 bytes,
        // the user knows that we have read nothing.
        buffer.softClampEnd(start + readCount);

      case ParseResult(:final result):
        yield result;
    }
  }
}

/// A simple buffer with capacity management.
@pragma('vm:isolate-unsendable')
class ByteAccumulator {
  ByteAccumulator.zeros({int initialSize = 16, int offset = 0, int length = 0})
    : _offset = offset,
      _length = length,
      _buffer = Uint8List(initialSize);

  /// Underlying buffer of data.
  Uint8List _buffer;

  @visibleForTesting
  Uint8List get buffer {
    return _buffer;
  }

  @visibleForTesting
  int get capacity {
    return _buffer.length;
  }

  /// the length of the written bytes
  /// this can be different from the length of the
  /// buffer.
  int _length;

  @visibleForTesting
  int get length {
    return _length;
  }

  /// Allows to offset the buffer, this will make the
  /// FIRST byte of the array (not including the leftPad)
  /// to be at the specified offset.
  int _offset;

  @visibleForTesting
  int get offset {
    return _offset;
  }

  int get lastOffset {
    return _offset + _length;
  }

  Uint8List get bytes {
    return _buffer.sublist(0, 0 + _length);
  }

  void softClampEnd(int end) {
    _length = end - _offset;
  }

  void trimToRange({required int startOffset, required int endOffset}) {
    final requiredSize = pow2roundup(endOffset - startOffset);
    final oldRepresentedRange = Interval(_offset, _offset + _length);
    final newRepresentedRange = Interval(startOffset, endOffset);
    final overlap = oldRepresentedRange.computeOverlap(newRepresentedRange);

    // Create new buffer if size needs to change
    if (_buffer.length != requiredSize) {
      final oldBuffer = _buffer;
      _buffer = Uint8List(requiredSize);

      // Copy overlapping data if needed
      if (overlap != null) {
        _copyOverlappingData(
          overlap,
          oldBuffer,
          oldRepresentedRange,
          newRepresentedRange,
        );
      }
    } else if (overlap != null &&
        oldRepresentedRange.start != newRepresentedRange.start) {
      // Same size buffer but needs data shifting
      _copyOverlappingData(
        overlap,
        _buffer,
        oldRepresentedRange,
        newRepresentedRange,
      );
    }

    _offset = startOffset;
    _length = endOffset - startOffset;
  }

  void _copyOverlappingData(
    Interval overlap,
    Uint8List sourceBuffer,
    Interval oldRange,
    Interval newRange,
  ) {
    for (
      var overlapPos = overlap.start;
      overlapPos < overlap.end;
      overlapPos++
    ) {
      final oldPos = overlapPos - oldRange.start;
      final newPos = overlapPos - newRange.start;
      _buffer[newPos] = sourceBuffer[oldPos];
    }
  }

  // returns an iterable with tuples (absolute pos, byte)
  Iterable<(int, int)> indexedIter() sync* {
    for (int i = 0; i < _length; i++) {
      yield (_offset + i, _buffer[i]);
    }
  }

  /// Rounds numbers <= 2^32 up to the nearest power of 2.
  /// (Adapted from bytes_builder)
  @visibleForTesting
  static int pow2roundup(int value) {
    assert(value > 0);
    var x = value;
    --x;
    x |= x >> 1;
    x |= x >> 2;
    x |= x >> 4;
    x |= x >> 8;
    x |= x >> 16;
    return x + 1;
  }

  /// Sets a byte at the specified absolute offset in the buffer.
  ///
  /// The [absoluteOffset] parameter specifies the absolute position in the buffer
  /// where the byte should be set. This offset is absolute, meaning it is not relative
  /// to any other position or offset.
  ///
  /// The [byte] parameter is the value to be set at the specified offset.
  ///
  /// Throws a [RangeError] if the [absoluteOffset] is out of the buffer's bounds.
  void setByte(int absoluteOffset, int byte) {
    if (absoluteOffset < _offset || absoluteOffset >= _offset + _length) {
      throw RangeError('The specified offset is out of bounds');
    }

    _buffer[absoluteOffset - _offset] = byte;
  }

  /// Gets a byte at the specified absolute offset in the buffer.
  int getByte(int absoluteOffset) {
    if (absoluteOffset < _offset || absoluteOffset >= _offset + _length) {
      throw RangeError('The specified offset is out of bounds');
    }

    return _buffer[absoluteOffset - _offset];
  }

  /// Creates a view of the buffer at the specified absolute offset.
  /// meaning that setting the first item of the view will set the
  /// first item of the buffer at the specified offset.
  @internal
  @visibleForTesting
  Uint8List viewRelative(int start) {
    return Uint8List.sublistView(_buffer, start - _offset);
  }

  /// This will COPY the bytes in the given range, if
  /// you want a view of the buffer, use [viewRange].
  Uint8List getRange(int readStart, int position) {
    return _buffer.sublist(readStart - _offset, position - _offset);
  }

  /// This will return a view of the buffer in the specified range
  Uint8List viewRange(int readStart, int position) {
    return Uint8List.sublistView(
      _buffer,
      readStart - _offset,
      position - _offset,
    );
  }

  /// Sets a range of bytes in the buffer.
  // TODO: add range checks
  void setRange(int i, List<int> out) {
    final relativeOffset = i - _offset;
    return buffer.setRange(relativeOffset, relativeOffset + out.length, out);
  }

  @override
  String toString() {
    return 'ByteAccumulator('
        'offset: $_offset, '
        'length: $_length, '
        'bufferSize: ${_buffer.length}'
        ')';
  }
}

/// Utility class just to simplify and streamline
/// overlap computations.
@internal
@visibleForTesting
extension type const Interval._((int a, int b) _) {
  factory Interval(int a, int b) => Interval._((a, b));

  int get start => _.$1;
  int get end => _.$2;
  int get length => end - start;

  Interval? computeOverlap(Interval other) {
    final int start = math.max(this.start, other.start);
    final int end = math.min(this.end, other.end);
    return start < end ? Interval(start, end) : null;
  }
}

/// A cursor that tracks and manipulates a position value.
///
/// The [Cursor] class provides functionality to track a position and perform
/// various operations like advancing, getting the next position, or setting
/// the position directly.
///
/// The main purpose is to provide a mutable reference to a position ([_position])
/// value that can be easily manipulated and passed around.
final class Cursor {
  Cursor([int position = 0]) : _position = position;
  int _position;

  int get position {
    return _position;
  }

  /// Advances the cursor by [amount] positions.
  void advance(int amount) {
    _position += amount;
  }

  /// Advances the cursor by one position.
  /// and returns the new position.
  @pragma('vm:prefer-inline')
  int next() {
    return _position++;
  }

  /// Sets the cursor position to the specified [position].
  void positionAt(int position) {
    _position = position;
  }
}
