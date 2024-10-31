import 'package:readers/readers.dart';

typedef ManagedParserGenerator<T> = ParseIterator<T> Function(
  ByteAccumulator buffer,
);

// API: Handle the case when the function does not return a CompleteParseResult.
// API: Maybe add a default value to return in case of an exception.
Iterable<T> handleSync<T>(
  ManagedParserGenerator<T> createIterable,
  SyncFileSource source, {
  int defaultRequestSize = 2,
  bool clearOnPassthrough = false,
}) sync* {
  final buffer = ByteAccumulator();
  final iterable = createIterable(buffer);

  mainLoop:
  for (final partial in iterable) {
    int? missedRequestBytes;
    switch (partial) {
      case ExactReadRequest(
          :final count,
          sourcePosition: final position,
          bufferPosition: final bufferPosition
        ):
        final newData = source.read(count, offset: position);

        // Failure due to not enough data.
        if (newData.isEmpty || newData.length < count) {
          missedRequestBytes = count - newData.length;
          continue notEnoughData;
        }

        buffer.grow(newData, position: bufferPosition);

      case PartialReadRequest(
          :final maxCount,
          sourcePosition: final position,
          bufferPosition: final bufferPosition
        ):
        final requestSize = maxCount ?? defaultRequestSize;
        final newData = source.read(requestSize, offset: position);

        // Softly break.
        if (newData.isEmpty) break;

        buffer.grow(newData, position: bufferPosition);

      case CompleteParseResult<T>(:final value, :final isLast):
        yield value;

        /// We expect no more data to be read.
        if (isLast) break mainLoop;

      case PassthroughRequest():
        if (clearOnPassthrough) buffer.clear();
        continue;

      notEnoughData:
      default:
        throw StateError('Not enough data, missed $missedRequestBytes bytes.');
    }
  }
}
