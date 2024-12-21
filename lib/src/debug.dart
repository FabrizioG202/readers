import 'dart:typed_data';

/// Prints a list of bytes as a list of hexes
/// (used only for debugging)
String formatBytes(Uint8List bytes) {
  return bytes.map((e) => e.toRadixString(16).padLeft(2, '0')).join(', ');
}
