import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:orbi_ai/core/network/sse_parser.dart';

void main() {
  group('SseParser UTF-8 & framing safety', () {
    test('reassembles Persian 2-byte UTF-8 and 4-byte emoji split mid-codepoint', () async {
      const sample = 'سلام دنیای هوش مصنوعی فارسی! 🚀✨\nخط دوم فارسی';
      const payload =
          'data: {"choices":[{"delta":{"content":"سلام "}}]}\n\n'
          'data: {"choices":[{"delta":{"content":"دنیای هوش مصنوعی فارسی! 🚀✨"}}]}\n\n'
          'data: [DONE]\n\n';
      final allBytes = utf8.encode(payload);

      // Split strictly into 1-byte and 2-byte chunks so multi-byte Persian
      // characters and 4-byte emojis are guaranteed to be split mid-sequence.
      final chunks = <Uint8List>[];
      var i = 0;
      var step = 1;
      while (i < allBytes.length) {
        final end = (i + step).clamp(0, allBytes.length);
        chunks.add(Uint8List.fromList(allBytes.sublist(i, end)));
        i = end;
        step = step == 1 ? 2 : 1;
      }

      final events = await SseParser.parseUint8Stream(
        Stream<Uint8List>.fromIterable(chunks),
      ).toList();

      expect(sample.isNotEmpty, isTrue);
      expect(events.length, 3);
      expect(events[0].data, '{"choices":[{"delta":{"content":"سلام "}}]}');
      expect(
        events[1].data,
        '{"choices":[{"delta":{"content":"دنیای هوش مصنوعی فارسی! 🚀✨"}}]}',
      );
      expect(events[1].data.contains('\uFFFD'), isFalse);
      expect(events[2].isDone, isTrue);
    });

    test('ignores SSE comments, parses event/id, and flushes trailing frame', () async {
      const raw = ': keep-alive\n\n'
          'id: 42\n'
          'event: message\n'
          'data: line1\n'
          'data: line2\n\n'
          'data: trailing-no-blank';

      final events = await SseParser.parseBytes(
        Stream.value(utf8.encode(raw)),
      ).toList();

      expect(events.length, 2);
      expect(events[0].id, '42');
      expect(events[0].event, 'message');
      expect(events[0].data, 'line1\nline2');
      expect(events[1].data, 'trailing-no-blank');
    });
  });
}
