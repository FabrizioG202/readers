// // Copyright (c) 2024 Fabrizio Guidotti
// //
// // This software is released under the MIT License.
// // https://opensource.org/licenses/MIT

// import 'dart:io';

// import 'package:readers/readers.dart';
// import 'package:test/test.dart';

// void main() {
//   group('Unit', () {
//     late SyncFileSource source;

//     setUp(
//       () => source = SyncFileSource(
//         // A File containing the string "I think, therefore I am", terminated by a null character
//         File('./test/data/hello.bin'),
//       )..open(),
//     );

//     tearDown(
//       () => source.close(),
//     );

//     test(
//       'Reading the full file works.',
//       () => expect(
//         handleSync(
//           (b) sync* {
//             yield* b.extendUntil((newChunk) => newChunk.contains(0x00));
//             yield CompleteParseResult(String.fromCharCodes(b.getBytesView()));
//           },
//           source,
//         ),
//         'I think, therefore I am\x00',
//       ),
//     );

//     test(
//       'Requesting more bytes than available throws an exception',
//       () {
//         expect(
//           () => handleSync(
//             (b) sync* {
//               yield const ExactReadRequest(count: 100);
//               yield CompleteParseResult(
//                 String.fromCharCodes(b.getBytesView()),
//               );
//             },
//             source,
//           ),
//           throwsException,
//         );
//       },
//     );

//     test(
//       'Soft-limiting the number of requested bytes does not throw an exception',
//       () => expect(
//         () => handleSync(
//           (b) sync* {
//             yield const PartialReadRequest(maxCount: 100);
//             yield CompleteParseResult(String.fromCharCodes(b.getBytesView()));
//           },
//           source,
//         ),
//         returnsNormally,
//       ),
//     );

//     test(
//       'The buffer is grown only with the necessary bytes',
//       () => expect(
//         handleSync(
//           (b) sync* {
//             yield const PartialReadRequest(maxCount: 7);
//             yield CompleteParseResult(String.fromCharCodes(b.getBytesView()));
//           },
//           source,
//         ),
//         'I think',
//       ),
//     );

//     // Currently we are not supporting this, since the rewrite.
//     // test('Inserting and Overwriting the buffer works.', () {
//     //   expect(
//     //     handleSync(
//     //       (b) sync* {
//     //         // Read 'I think'
//     //         yield const PartialReadRequest(maxCount: 7);

//     //         // Insert 'am' at position 2 (after 'I', producing 'I am')
//     //         yield const ExactReadRequest(
//     //           count: 2,
//     //           sourcePosition: 21, // Start reading ' am' from source
//     //           bufferPosition: 2,
//     //         );

//     //         //read the rest of the file, starting from after 'I think
//     //         yield const PartialReadRequest(
//     //           maxCount: 100,
//     //           sourcePosition: 7,
//     //           bufferPosition: 4, // Start writing at position 4 (after 'I am')
//     //         );
//     //         yield CompleteParseResult(String.fromCharCodes(b.getBytesView()));
//     //       },
//     //       source,
//     //     ),
//     //     'I am, therefore I am\x00',
//     //   );
//     // });

//     test('Providing no `bufferPosition` appends', () {
//       expect(
//         handleSync(
//           (b) sync* {
//             // Read 'think, '
//             yield const PartialReadRequest(maxCount: 7, sourcePosition: 2);

//             // Append 'think '
//             yield const ExactReadRequest(
//               count: 5,
//               sourcePosition: 2,
//             );
//             yield CompleteParseResult(String.fromCharCodes(b.getBytesView()));
//           },
//           source,
//         ),
//         'think, think',
//       );
//     });
//   });
// }
