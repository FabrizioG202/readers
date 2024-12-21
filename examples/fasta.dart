import 'dart:io';

import 'package:readers/readers.dart';

final class FastaRead {
  final String sequence, header;
  FastaRead(this.header, this.sequence);

  @override
  String toString() => 'FastaRead($header, $sequence)';
}

// Very Naive Implementation of a FastA file parser.
// It is mainly
ParseIterable readFasta(ByteAccumulator buffer) sync* {
  final cursor = Cursor();

  // Fasta Stuff
  var header = '';
  final sequence = StringBuffer();
  var isInHeader = false;
  var hasSequence = false;
  var position = 0;

  while (true) {
    // Request 5 bytes.
    // This is an arbitrary length to not read too much data at the same time.
    yield RangeReadRequest(cursor.position, cursor.position + 5, purgePreceding: true);

    // Get the view bytes and, since exact is false,
    // we might have read less bytes than 5, we advance the cursor only
    // to that point.
    final view = buffer.viewRange(cursor.position, buffer.lengthInBytes);
    cursor.advance(view.length);

    // No more bytes were read.
    if (view.isEmpty) break;

    for (final char in view.map(String.fromCharCode)) {
      position++;

      switch (char) {
        case '>':
          if (hasSequence) {
            if (sequence.isEmpty) {
              throw Exception(
                'Empty sequence for header "$header" at position $position',
              );
            }
            final seq = sequence.toString().replaceAll(RegExp(r'\s'), '');
            yield ResultMessage(FastaRead(header, seq));
            sequence.clear();
          }
          header = '';
          isInHeader = true;
          hasSequence = true;

        case '\n' || '\r':
          isInHeader = false;

        case String s:
          if (!hasSequence && !isInHeader && s.trim().isNotEmpty) {
            throw Exception(
              'Found sequence data before header at position $position',
            );
          }
          if (isInHeader) {
            header += s;
          } else if (s.trim().isNotEmpty) {
            sequence.write(s);
          }
      }
    }
  }

  if (hasSequence) {
    if (sequence.isEmpty) {
      throw Exception(
        'Empty sequence for header "$header" at position $position',
      );
    }
    final seq = sequence.toString().replaceAll(RegExp(r'\s'), '');
    yield ResultMessage(FastaRead(header, seq));
  }
}

void main() {
  final gzippedSource = SyncFileSource(File('./examples/fasta1.fa.gz'))..open();
  final plainSource = SyncFileSource(File('./examples/fasta1.fa'))..open();

  /// Read from a GZipped Source.
  final resultFromGZipped = handleSync(
    (b) {
      return zlibDecode(b, (c) => readFasta(c));
    },
    gzippedSource,
  ).toList();

  print(resultFromGZipped);

  final resultFromPlain = handleSync(
    (b) {
      return readFasta(b);
    },
    plainSource,
  ).toList();

  print(resultFromPlain);

  // Close the source since we do not need it anymore
  gzippedSource.close();
  plainSource.close();
}
