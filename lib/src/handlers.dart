import 'package:readers/readers.dart';

typedef ManagedIncrementalParser<T> = Iterable<PartialParseResult<T>> Function(
  BytesBuffer buffer,
);

// API: Handle the case when the function does not return a CompleteParseResult.
// API: Maybe add a default value to return in case of an exception.
T handleSync<T>(
  ManagedIncrementalParser<T> createIterable,
  SyncFileSource source,
) {
  final buffer = BytesBuffer();
  final iterable = createIterable(buffer);

  for (final partial in iterable) {
    if (partial
        case ReadRequest(
          :final count,
          :final position,
          :final allowPartial,
        )) {
      final newData = source.read(count ?? 2, offset: position);
      if (newData.isEmpty) break;

      // Not enough data.
      // FIX: In theory, if allowPartial is not set, it does not make
      // sense for the count to be null.
      if (!allowPartial && count != null && newData.length < count) {
        break;
      }

      buffer.grow(newData);
    } else if (partial case CompleteParseResult<T>(:final value)) {
      return value;
    }
  }

  // FIXME: Choose wether to throw an exception or errors.
  throw Exception('Not enough data!');
}
