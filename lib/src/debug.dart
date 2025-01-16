import 'package:collection/collection.dart';

/// Prints a list of bytes as a list of hexes.
/// (used only for debugging)
String formatBytes<T extends List<int>>(T bytes) {
  final StringBuffer buffer = StringBuffer();

  for (final chunks in bytes.slices(8)) {
    buffer.writeln(
      chunks
          .map((e) => e.toRadixString(16).toUpperCase().padLeft(2, '0'))
          .join(' '),
    );
  }

  return buffer.toString();
}
