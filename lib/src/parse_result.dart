// Copyright (c) 2024 Fabrizio Guidotti
//
// This software is released under the MIT License.
// https://opensource.org/licenses/MIT

import 'package:meta/meta.dart';

@immutable
sealed class PartialParseResult<T> {
  const PartialParseResult();
}

/// Represents a request to read data.
@immutable
final class ReadRequest extends PartialParseResult<Never> {
  const ReadRequest({
    this.count,
    this.position,
    this.allowPartial = true,
  }) : assert(
          count != null || allowPartial,
          'If count is not provided, allowPartial must be true',
        );

  const ReadRequest.require(int this.count, {this.position})
      : allowPartial = false;

  /// The number of bytes to read.
  final int? count;

  /// The position to start reading from.
  /// If not provided, the internal position of the source is used.
  final int? position;

  /// Whether to allow partial reads.
  /// If `false`, the source must return the exact number of bytes requested,
  /// otherwise the source is considered exhausted and parsing stops.
  /// If `true`, the source can return less than the requested number of bytes.
  /// It is assumed to be the parser's responsibility to check enough data is
  /// available.
  final bool allowPartial;

  @override
  String toString() => 'ReadRequest(count: $count, position: $position)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ReadRequest &&
          runtimeType == other.runtimeType &&
          count == other.count &&
          position == other.position &&
          allowPartial == other.allowPartial;

  @override
  int get hashCode =>
      count.hashCode ^ position.hashCode ^ allowPartial.hashCode;
}

/// Represents a successfully parsed result.
@immutable
final class CompleteParseResult<T> extends PartialParseResult<T> {
  const CompleteParseResult(this.value);
  final T value;

  @override
  String toString() => 'CompleteParseResult($value)';
}
