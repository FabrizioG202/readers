// ignore_for_file: avoid_redundant_argument_values

import 'package:readers/readers.dart';
import 'package:test/expect.dart';
import 'package:test/scaffolding.dart';

void main() {
  // Mock data, 128-sized array with bytes from 0 to 127
  final kSourceOrdered = List<int>.generate(128, (index) => index);
  const kInitialBufferTestSizes = [null, 8, 16, 24, 32];

  group('Buffer Operations:', () {
    void testAccumulatorRangeTransform(
      int initStart,
      int initEnd,
      int trimStart,
      int trimEnd, {

      // If null, the accumulator will be initialized with the
      // initial range size.
      int? initialBufferSize,
    }) {
      // Initialize the buffer and trim it.
      final accumulator =
          ByteAccumulator.zeros(
              initialSize: initialBufferSize ?? (initEnd - initStart),
              length: initEnd - initStart,
              offset: initStart,
            )
            ..setRange(initStart, kSourceOrdered.sublist(initStart, initEnd))
            ..trimToRange(startOffset: trimStart, endOffset: trimEnd);

      // verify data consistency
      for (final (index, value) in accumulator.indexedIter()) {
        if (value != 0 && index >= initStart && index < initEnd) {
          expect(
            index,
            equals(value),
            reason: 'Shifted index $index should match its value',
          );
        }
      }
    }

    for (final size in kInitialBufferTestSizes) {
      group('With initial buffer size: ${size ?? "default"}', () {
        test('Equal size', () {
          testAccumulatorRangeTransform(8, 16, 12, 20, initialBufferSize: size);
        });

        if (size != null && size >= 16) {
          // Cannot start with a buffer less than 16 bytes long for this test.
          test('Downsize', () {
            testAccumulatorRangeTransform(
              8,
              24,
              12,
              20,
              initialBufferSize: size,
            );
          });
        }

        test('Upsize', () {
          testAccumulatorRangeTransform(8, 16, 12, 28, initialBufferSize: size);
        });
      });
    }
  });
}
