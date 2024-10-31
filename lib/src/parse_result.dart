import 'package:meta/meta.dart';

@immutable
sealed class PartialParseResult<T> {
  const PartialParseResult();

  /// Stops the parsing operation.
  static const stop = CompleteParseResult<void>(null);
}

/// A full parse result.
/// This is the result of a successful parse operation.
///
/// If [isLast] is true, the parse operation is complete.
/// If [isLast] is false, the caller can expect more data to be available
@immutable
final class CompleteParseResult<T> extends PartialParseResult<T> {
  const CompleteParseResult(this.value, {this.isLast = true});

  /// FIXME: This can't be the definitive name of the object.
  /// it sounds like a joke.
  const CompleteParseResult.incomplete(this.value) : isLast = false;
  final T value;
  final bool isLast;

  @override
  String toString() => 'CompleteParseResult($value)';
}

/// A notification that the parser should continue reading data.
/// Depending on the implementation, it might be wise to
/// clear the buffer on this request.
@immutable
final class PassthroughRequest extends PartialParseResult<Never> {
  const PassthroughRequest();
}

/// Base class for read requests
@immutable
sealed class ReadRequest extends PartialParseResult<Never> {
  const ReadRequest({
    required this.sourcePosition,
    required this.bufferPosition,
  });

  /// The position to start reading from in the source.
  /// If not provided, the internal position of the source is used.
  final int? sourcePosition;

  /// Position in the buffer where the read data should be placed
  /// If null, the data will be appended to the end of the buffer
  final int? bufferPosition;
}

/// Request for reading an exact number of bytes
@immutable
final class ExactReadRequest extends ReadRequest {
  const ExactReadRequest({
    required this.count,
    super.sourcePosition,
    super.bufferPosition,
  });

  /// The exact number of bytes to read
  final int count;

  @override
  String toString() =>
      'ExactReadRequest(count: $count, position: $sourcePosition, bufferPosition: $bufferPosition)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ExactReadRequest &&
          runtimeType == other.runtimeType &&
          count == other.count &&
          sourcePosition == other.sourcePosition &&
          bufferPosition == other.bufferPosition;

  @override
  int get hashCode => Object.hash(count, sourcePosition, bufferPosition);
}

/// Request for reading any available bytes up to a maximum
@immutable
final class PartialReadRequest extends ReadRequest {
  const PartialReadRequest({
    this.maxCount,
    super.sourcePosition,
    super.bufferPosition,
  });

  /// The maximum number of bytes to read
  /// If null, it is up to the implementation to decide
  /// how many bytes to read
  final int? maxCount;

  @override
  String toString() =>
      'PartialReadRequest(maxCount: $maxCount, position: $sourcePosition, bufferPosition: $bufferPosition)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PartialReadRequest &&
          runtimeType == other.runtimeType &&
          maxCount == other.maxCount &&
          sourcePosition == other.sourcePosition &&
          bufferPosition == other.bufferPosition;

  @override
  int get hashCode => Object.hash(maxCount, sourcePosition, bufferPosition);
}
