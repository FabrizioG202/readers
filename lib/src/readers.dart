import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:meta/meta.dart';

typedef ParseIterable = Iterable<ParserMessage>;
typedef ParserGenerator = ParseIterable Function(ByteAccumulator buffer);

@immutable
sealed class ParserMessage {
  const ParserMessage();
}

@immutable
final class ResultMessage extends ParserMessage {
  const ResultMessage(this.result);
  final dynamic result;
}

@immutable
final class RangeReadRequest extends ParserMessage {
  const RangeReadRequest(
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

Iterable<dynamic> handleSync(
  ParseIterable Function(ByteAccumulator) generator,
  SyncFileSource source,
) sync* {
  final buffer = ByteAccumulator();

  for (final message in generator(buffer)) {
    switch (message) {
      case ResultMessage(:final result):
        yield result;

      case RangeReadRequest(
          :final start,
          :final end,
        ):
        final newData = source.readRange(start, end);
        buffer.grow(newData);

      // print('Inside Handle Sync: ${_formatBytes(newData)}');
    }
  }
}

/// A simple buffer.
class ByteAccumulator {
  ByteAccumulator() : _data = Uint8List(0);
  Uint8List _data;

  /// Padding allows to save memory
  /// when we no longer care about bytes before
  /// a given threshold.
  int _removedBytesCount = 0;

  /// The length in bytes of this
  /// This includes the length of the data and the removed bytes.
  int get lengthInBytes {
    return _data.length + _removedBytesCount;
  }

  /// Adds bytes to the end of the buffer.
  /// TODO: Grow the buffer more than the length to optimize
  /// for quick sequential grows.
  void grow(Uint8List bytes) {
    final newData = Uint8List(_data.length + bytes.length)
      ..setAll(0, _data)
      ..setAll(_data.length, bytes);
    _data = newData;
  }

  /// Purges bytes from the start of the buffer until
  /// the given threshold
  void purgeUpTo(int threshold) {
    // FIX: Maybe this could be better with a RangeError.checkValidRange
    // to avoid negative threshold.
    if (threshold > lengthInBytes) {
      throw ArgumentError('Threshold is greater than the buffer length');
    }

    final toPurgeCount = threshold - _removedBytesCount;
    _data = _data.sublist(toPurgeCount);
    _removedBytesCount = threshold;
  }

  /// The beginning of the indexable range
  /// data retrieval is not allowed before this value (included)
  int get _indexableStart {
    return _removedBytesCount;
  }

  /// Get a view of the given range
  /// (does not modify the buffer)
  /// TODO: perform range checks on the [start] and [end] values
  /// Allows reading only non-purged data
  /// (see [_removedBytesCount] for more information about
  /// data purging)
  Uint8List viewRange(int start, int end) {
    return _data.sublist(
      start - _indexableStart,
      end - _indexableStart,
    );
  }

  @override
  String toString() {
    return 'ByteAccumulator(length: $lengthInBytes, padding: $_removedBytesCount)';
  }
}

/// A cursor that tracks position in a buffer.
/// It only wraps an integer position and thus might look
/// overengineered, but in the future
/// we might extend it to provide additional functionalities.
class Cursor {
  int _position = 0;

  /// Current cursor position.
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
