import 'dart:io';
import 'dart:typed_data';

import 'package:readers/src/readers.dart';

/// This takes in a buffer representing the
/// bytes of the compressed file, and allows the caller to work
/// on decompressed data, passed into the [inner]'s function
/// This has NO CONTROL over the [compressedBuffer] it gets
/// passed in. It can only read data from it (albeit we have no way to
/// enforce this rn)
ParseIterable<T> zlibDecode<T>(ByteAccumulator compressedBuffer, ParserGenerator<T> inner) sync* {
  // Initialize the filter.
  final libFilter = RawZLibFilter.inflateFilter();

  // Compressed buffer.
  // This is the 'true to life' buffer, which contains
  // the data straight from the file.
  // this cursor's position mirrors the offset of the last
  // bytes that was fed to the decompressor.
  final lastFedCursor = Cursor();

  // TODO: Inline this
  // ignore: no_leading_underscores_for_local_identifiers
  void _feedToFilter(Uint8List newlyRead) {
    libFilter.process(newlyRead, 0, newlyRead.length);
    lastFedCursor.advance(newlyRead.length);
  }

  // Decompressed buffer. It contains the
  // readable data. This is passed on to the
  // inner generator, allowing it to transparently
  // extract the contents of the file
  final decompressedBuffer = ByteAccumulator();

  // TODO: Inline this
  // ignore: no_leading_underscores_for_local_identifiers
  void _drainFilter() {
    while (true) {
      final out = libFilter.processed(flush: false);
      if (out == null) break;
      decompressedBuffer.grow(Uint8List.fromList(out));
    }
  }

  // Performs work until the decompressed data
  // has minimum [requestedLength] bytes
  // TODO: Inline this
  // ignore: no_leading_underscores_for_local_identifiers
  Iterable<ByteRangeRequest> _ensureDecompressedLength(int requestedLength) sync* {
    // Part of the conde performing the 'dirty' work.
    // This reads stuff.
    while (decompressedBuffer.lengthInBytes < requestedLength) {
      // This is where we will ask the underlying bytes from the data source.
      // 5 is an arbitrary value for the size of a chunk.
      // We have to do this since we are allowing less than 5 bytes to be read,
      // as it will be the case when the file ends.
      final position = compressedBuffer.lengthInBytes;
      yield ByteRangeRequest(lastFedCursor.position, lastFedCursor.position + 5);
      final newlyReadData = compressedBuffer.viewRange(
        position,
        compressedBuffer.lengthInBytes,
      );

      // We reached or are beyond the read length.
      if (newlyReadData.isEmpty) break;

      // We feed the data to the filter.
      // This increments only the
      _feedToFilter(newlyReadData);
      _drainFilter();
    }
  }

  final iterator = inner(decompressedBuffer).iterator;
  while (iterator.moveNext()) {
    final request = iterator.current;

    switch (request) {
      // We were requested bytes up to the given one.
      case ByteRangeRequest(
          :final start,
          :final end, // (this offset is relative to the decompressed buffer)
          :final purgePreceding // Wether to purge the DECOMPRESSED data
        ):

        // Make sure our filter has seen enough bytes
        // and, in turn, that we have enough decompressed bytes.
        yield* _ensureDecompressedLength(end);

        // TODO: Investigate if we need to do this before or after
        // ensuring that we have enough decompressed bytes.
        // Maybe it is a better thing to do it before
        // since when adding to the decompressed buffer, we will be working
        // with a smaller buffer and thus gain in performance.
        if (purgePreceding) decompressedBuffer.purgeUpTo(start);

      case ParseResult():
        yield request;
    }
  }

  // TODO: !! Properly close the Zip filter.
}
