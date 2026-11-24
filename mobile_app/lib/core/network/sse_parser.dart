import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

/// One parsed Server-Sent Event frame per WHATWG EventSource framing.
class SseEvent {
  const SseEvent({
    this.id,
    this.event,
    required this.data,
  });

  final String? id;
  final String? event;
  final String data;

  bool get isDone => data.trim() == '[DONE]';
}

/// Decodes a raw byte stream into [SseEvent] items safely across arbitrary TCP
/// chunk boundaries, preserving multi-byte UTF-8 Persian characters and emojis
/// even when split mid-codepoint between chunks.
class SseParser {
  const SseParser._();

  static Stream<SseEvent> parseBytes(Stream<List<int>> byteStream) async* {
    // Chain StreamTransformer.fromBind(utf8.decoder.bind) -> LineSplitter so
    // incomplete multi-byte UTF-8 sequences at chunk boundaries are buffered
    // statefully and runtime Stream<Uint8List> variance stays safe.
    final utf8Stream = StreamTransformer<List<int>, String>.fromBind(
      const Utf8Decoder(allowMalformed: true).bind,
    ).bind(byteStream);
    final lineStream = const LineSplitter().bind(utf8Stream);

    final dataLines = <String>[];
    String? currentId;
    String? currentEvent;

    await for (final line in lineStream) {
      if (line.isEmpty) {
        if (dataLines.isNotEmpty ||
            currentEvent != null ||
            currentId != null) {
          yield SseEvent(
            id: currentId,
            event: currentEvent,
            data: dataLines.join('\n'),
          );
          dataLines.clear();
          currentId = null;
          currentEvent = null;
        }
        continue;
      }

      if (line.startsWith(':')) {
        continue; // SSE comment / heartbeat
      }

      final colonIndex = line.indexOf(':');
      final String field;
      String value;
      if (colonIndex == -1) {
        field = line;
        value = '';
      } else {
        field = line.substring(0, colonIndex);
        value = line.substring(colonIndex + 1);
        if (value.startsWith(' ')) {
          value = value.substring(1);
        }
      }

      switch (field) {
        case 'data':
          dataLines.add(value);
        case 'event':
          currentEvent = value;
        case 'id':
          currentId = value;
      }
    }

    if (dataLines.isNotEmpty || currentEvent != null || currentId != null) {
      yield SseEvent(
        id: currentId,
        event: currentEvent,
        data: dataLines.join('\n'),
      );
    }
  }

  /// Convenience adapter for Dio `ResponseBody.stream` (`Stream<Uint8List>`).
  static Stream<SseEvent> parseUint8Stream(Stream<Uint8List> stream) =>
      parseBytes(stream);
}
