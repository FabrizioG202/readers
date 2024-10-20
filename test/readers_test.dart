// Copyright (c) 2024 Fabrizio Guidotti
//
// This software is released under the MIT License.
// https://opensource.org/licenses/MIT

import 'dart:io';

import 'package:readers/readers.dart';
import 'package:test/test.dart';

void main() {
  group(
    'Unit',
    () {
      late SyncFileSource source;

      setUp(
        () => source = SyncFileSource(
          // A File containing the string "hello world", terminated by a null character
          File('./test/data/hello.bin'),
        )..open(),
      );

      tearDown(
        () => source.close(),
      );

      test(
        'Simple Incremental Parsing through `extendUntil` works',
        () => expect(
          handleSync(
            (b) sync* {
              yield* b.extendUntil((newChunk) => newChunk.contains(0x00));
              yield CompleteParseResult(String.fromCharCodes(b.getBytesView()));
            },
            source,
          ),
          'hello world\x00',
        ),
      );

      test(
        'Requesting more bytes than available throws an exception',
        () {
          expect(
            () => handleSync(
              (b) sync* {
                yield const ReadRequest.require(100);
                yield CompleteParseResult(
                  String.fromCharCodes(b.getBytesView()),
                );
              },
              source,
            ),
            throwsException,
          );
        },
      );

      test(
        'Soft-limiting the number of requested bytes does not throw an exception',
        () => expect(
          () => handleSync(
            (b) sync* {
              yield const ReadRequest(count: 100);
              yield CompleteParseResult(String.fromCharCodes(b.getBytesView()));
            },
            source,
          ),
          returnsNormally,
        ),
      );

      test(
        'The buffer is grown only with the necessary bytes',
        () => expect(
          handleSync(
            (b) sync* {
              yield const ReadRequest(count: 5);
              yield CompleteParseResult(String.fromCharCodes(b.getBytesView()));
            },
            source,
          ),
          'hello',
        ),
      );
    },
  );
}
