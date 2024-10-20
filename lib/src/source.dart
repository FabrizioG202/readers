// Copyright (c) 2024 Fabrizio Guidotti
//
// This software is released under the MIT License.
// https://opensource.org/licenses/MIT

import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

/// A read source allows for reading
/// A [DataSource] is a source that provides a single method to read bytes.
///
/// See [SyncFileSource] for a synchronous file source,
/// the only current implementation.
abstract interface class DataSource {
  FutureOr<Uint8List> read(int count, {int offset});
}

/// A synchronous file source.
class SyncFileSource implements DataSource {
  SyncFileSource(this.file);

  /// The underlying file.
  final File file;
  RandomAccessFile? _raf;

  /// Opens the file for reading.
  void open() => _raf = file.openSync();

  /// If [start] is not provided, the internal cursor will
  @override
  Uint8List read(int count, {int? offset}) {
    if (_raf case final raf?) {
      if (offset != null) {
        raf.setPositionSync(offset);
      }
      return raf.readSync(count);
    }

    throw StateError('The file is not open');
  }

  /// *Does nothing if the file is not open.
  void close() => _raf?.closeSync();
}
