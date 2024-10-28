import 'package:readers/src/parse_result.dart';

/// Passes through parse results, optionally handling completion.
/// Effectively, this casts the inner iterable to a different type.
/// allowing to yield the given type of results, even if [inner] yields a different type.
@pragma("vm:prefer-inline")
Iterable<PartialParseResult<X>> passthrough<Y, X>(
  Iterable<PartialParseResult<Y>> inner, {
  void Function(Y)? onComplete,
}) sync* {
  for (final i in inner) {
    switch (i) {
      case ReadRequest():
        yield i;
      case CompleteParseResult<Y>(:final value):
        onComplete?.call(value);
        return;
    }
  }
}
