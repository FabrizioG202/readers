import 'package:readers/readers.dart';

typedef ManagedParserGenerator<T> = ParseIterator<T> Function(
  ByteAccumulator buffer,
);

// API: Handle the case when the function does not return a CompleteParseResult.
// API: Maybe add a default value to return in case of an exception.
T handleSync<T>(
  ManagedParserGenerator<T> createIterable,
  SyncFileSource source, {
  int defaultRequestSize = 2,
  bool clearOnPassthrough = false,
}) {
  final buffer = ByteAccumulator();
  final iterable = createIterable(buffer);

  mainLoop:
  for (final partial in iterable) {
    switch (partial) {
      case ExactReadRequest(
          :final count,
          sourcePosition: final position,
          bufferPosition: final bufferPosition
        ):
        final newData = source.read(count, offset: position);
        if (newData.isEmpty || newData.length < count) break mainLoop;

        buffer.grow(newData, position: bufferPosition);

      case PartialReadRequest(
          :final maxCount,
          sourcePosition: final position,
          bufferPosition: final bufferPosition
        ):
        final requestSize = maxCount ?? defaultRequestSize;
        final newData = source.read(requestSize, offset: position);
        if (newData.isEmpty) break;

        buffer.grow(newData, position: bufferPosition);

      case CompleteParseResult<T>(:final value):
        return value;
      case PassthroughRequest():
        if (clearOnPassthrough) buffer.clear();
        continue;
    }
  }

  // EASY-FIXME: Choose wether to throw an exception or errors.
  throw Exception('Not enough data!');
}
