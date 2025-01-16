import 'dart:io';

import 'package:readers/src/readers.dart';

extension on RawZLibFilter {
  /// Simply a shortcut to make the logic clearer.
  @pragma('vm:prefer-inline')
  void processAll<X extends List<int>>(X data) {
    return process(data, 0, data.length);
  }
}

/// This takes in a buffer representing the
/// bytes of the compressed file, and allows the caller to work
/// on decompressed data, passed into the [inner]'s function
/// This has NO CONTROL over the [compressedBuffer] it gets
/// passed in. It can only read data from it (albeit we have no way to
/// enforce this rn)
ParseIterable<T> zlibDecode<T>(
  ByteAccumulator compressedBuffer,
  ParserGenerator<T> inner, {
  int decompressChunkSize = 1024,
}) sync* {
  // Initialize the filter.
  final libFilter = RawZLibFilter.inflateFilter();

  // Compressed buffer.
  // This is the 'true to life' buffer, which contains
  // the data straight from the file.
  // this cursor's position mirrors the offset of the last
  // bytes that was fed to the decompressor.
  final lastFedCursor = Cursor();

  // Decompressed buffer. It contains the
  // readable data. This is passed on to the
  // inner generator, allowing it to transparently
  // extract the contents of the file
  final decompressedBuffer = ByteAccumulator.zeros(initialSize: 1024);

  // TODO: Inline this
  // ignore: no_leading_underscores_for_local_identifiers
  void _feedToFilter(int startPos, int endPos) {
    /// PERF: Might not need to copy the bytes
    libFilter.processAll(compressedBuffer.getRange(startPos, endPos));
    lastFedCursor.positionAt(endPos);
  }

  // TODO: Inline this
  // ignore: no_leading_underscores_for_local_identifiers
  void _drainFilter() {
    while (true) {
      final out = libFilter.processed(flush: false);
      if (out == null) break;

      // We ensure the range is available
      // TODO (?) Might be worth creating a custom wrapper grow function.
      {
        final last = decompressedBuffer.lastOffset;
        // TODO (?) Set to cascade
        decompressedBuffer.trimToRange(
          startOffset: 0,
          endOffset: decompressedBuffer.lastOffset + out.length,
        );
        decompressedBuffer.setRange(last, out);
      }
    }
  }

  // Performs work until the decompressed data
  // has minimum [requestedLength] bytes
  // TODO: Inline this
  // ignore: no_leading_underscores_for_local_identifiers
  Iterable<RequestRangeForReading> _ensureDecompressedLength(
    int requestedLength,
  ) sync* {
    // Part of the conde performing the 'dirty' work.
    // This reads stuff.
    while (decompressedBuffer.lastOffset < requestedLength) {
      // This is where we will ask the underlying bytes from the data source.
      // 5 is an arbitrary value for the size of a chunk.
      // We have to do this since we are allowing less than 5 bytes to be read,
      // as it will be the case when the file ends.
      final position = compressedBuffer.lastOffset;
      yield RequestRangeForReading(
        lastFedCursor.position,
        lastFedCursor.position + decompressChunkSize,
      );
      final newPosition = compressedBuffer.lastOffset;

      // We reached or are beyond the read length.
      if (newPosition == position) break;

      // We feed the data to the filter.
      // This increments only the
      _feedToFilter(position, newPosition);
      _drainFilter();
    }
  }

  final iterator = inner(decompressedBuffer).iterator;
  while (iterator.moveNext()) {
    final request = iterator.current;

    switch (request) {
      // We were requested bytes up to the given one.
      case RequestRangeForReading(
        // :final firstOffset,
        lastOffset: final end, // (this offset is relative to the decompressed buffer)
      ):

        // Make sure our filter has seen enough bytes
        // and, in turn, that we have enough decompressed bytes.
        yield* _ensureDecompressedLength(end);

      // TODO: Investigate if we need to do this before or after
      // ensuring that we have enough decompressed bytes.
      // Maybe it is a better thing to do it before
      // since when adding to the decompressed buffer, we will be working
      // with a smaller buffer and thus gain in performance.
      // if (purgePreceding) decompressedBuffer.purgeUpTo(start);

      case ParseResult():
        yield request;
      case CollapseBuffer():
      // TODO: Implement this.
      // throw UnimplementedError();
    }
  }

  // TODO: !! Properly close the Zip filter.
}
