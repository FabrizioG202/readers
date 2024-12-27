import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:meta/meta.dart';
import 'dart:math' as math;

typedef ParseIterable<T> = Iterable<ParseEvent<T>>;
typedef ParserGenerator<T> = ParseIterable<T> Function(ByteAccumulator buffer);

@immutable
sealed class ParseEvent<T> {
  const ParseEvent();
}

@immutable
final class ParseResult<T> extends ParseEvent<T> {
  const ParseResult(this.result);
  final T result;
}

@immutable
final class ByteRangeRequest extends ParseEvent<Never> {
  const ByteRangeRequest(
    this.start,
    this.end, {
    this.exact = false,
    this.purgePreceding = false,
  });

  /// The range to request.
  // ignore: avoid_multiple_declarations_per_line
  final int start, end;

  /// Wether we absolutely need these bytes.
  /// If [exact] is true, if the exact amount of bytes
  /// cannot be read, an error is thrown.
  /// and parsing is terminated.
  final bool exact;

  /// Wether to remove bytes preceding the ones we are
  /// requesting. Use this with caution, since
  /// after purging, bytes from the buffer' start
  /// to [start] will not be readable anymore,
  /// and the memory they occupy will be freed.
  final bool purgePreceding;

  @override
  String toString() {
    return 'RangeReadRequest($start, $end)';
  }
}

/// A source that can be opened and closed.
abstract class Source {
  void open();
  void close();
}

abstract interface class DataSource extends Source {
  FutureOr<Uint8List> readRange(int start, int end);
}

/// A synchronous file source.
class SyncFileSource implements DataSource, Source {
  SyncFileSource(this.file);

  final File file;
  RandomAccessFile? _raf;

  @override
  void open() => _raf = file.openSync();

  @override
  Uint8List readRange(int start, int end) {
    if (_raf case final raf?) {
      raf.setPositionSync(start);
      return raf.readSync(end - start);
    }

    throw StateError('The file is not open');
  }

  @override
  void close() => _raf?.closeSync();
}

Iterable<T> parseSync<T>(
  ParseIterable<T> Function(ByteAccumulator) generator,
  SyncFileSource source,
) sync* {
  final buffer = ByteAccumulator();

  for (final message in generator(buffer)) {
    switch (message) {
      case ParseResult(:final result):
        yield result;

      case ByteRangeRequest(
          :final start,
          :final end,
        ):
        final newData = source.readRange(start, end);
        buffer.grow(newData);
    }
  }
}

/// A simple buffer with capacity management.
/// TODO: Add an initial size parameter.
class ByteAccumulator {
  ByteAccumulator() : _data = Uint8List(16);
  Uint8List _data;
  Uint8List get buffer => _data;
  int _length = 0;

  /// Padding allows to save memory
  /// when we no longer care about bytes before
  /// a given threshold.
  int _removedBytesCount = 0;

  /// The length in bytes of this
  /// This includes the length of the data and the removed bytes.
  int get lengthInBytes {
    return _length + _removedBytesCount;
  }

  /// Adds bytes to the end of the buffer.
  void grow(Uint8List bytes) {
    final neededLength = _length + bytes.length;
    if (neededLength > _data.length) {
      final newCapacity = math.max(_data.length * 2, neededLength);
      final newData = Uint8List(newCapacity)..setAll(0, _data.sublist(0, _length));
      _data = newData;
    }
    _data.setAll(_length, bytes);
    _length += bytes.length;
  }

  /// Purges bytes from the start of the buffer until
  /// the given threshold
  void purgeUpTo(int threshold) {
    if (threshold > lengthInBytes) {
      throw ArgumentError('Threshold is greater than the buffer length');
    }

    final toPurgeCount = threshold - _removedBytesCount;
    _data.setRange(0, _length - toPurgeCount, _data, toPurgeCount);
    _length -= toPurgeCount;
    _removedBytesCount = threshold;
  }

  /// The beginning of the indexable range
  /// data retrieval is not allowed before this value (included)
  int get _indexableStart {
    return _removedBytesCount;
  }

  /// Returns the actual position for the given index.
  int toIndexablePosition(int index) {
    return index - _indexableStart;
  }

  /// Get a view of the given range
  /// (does not modify the buffer)
  Uint8List viewRange(int start, int end) {
    return Uint8List.sublistView(
      _data,
      start - _indexableStart,
      end - _indexableStart,
    );
  }

  @override
  String toString() {
    return 'ByteAccumulator(length: $lengthInBytes, capacity: ${_data.length}, padding: $_removedBytesCount)';
  }
}

/// A cursor that tracks position in a buffer.
/// It only wraps an integer position and thus might look
/// overengineered, but in the future
/// we might extend it to provide additional functionalities.
class Cursor {
  int _position = 0;

  /// Current cursor position.
  @useResult
  int get position {
    return _position;
  }

  /// Advances cursor by n bytes and returns new position.
  int advance(int n) {
    return _position += n;
  }

  /// Explictly sets the cursor position.
  /// TODO: do we really need this?
  /// Maybe we could return the old position
  /// to justify this method's existence,
  /// as something other than a setter.
  void positionAt(int start) {
    _position = start;
  }
}
