/// Parsed view separating inline `<think>...</think>` reasoning blocks from
/// visible assistant content during live token streaming.
class ThinkingSplitResult {
  const ThinkingSplitResult({
    required this.visibleContent,
    required this.thinkingContent,
    required this.isThinkingOpen,
  });

  final String visibleContent;
  final String thinkingContent;
  final bool isThinkingOpen;
}

class ThinkingParser {
  const ThinkingParser._();

  static const _openTag = '<think>';
  static const _closeTag = '</think>';

  /// Splits [rawContent] (and optional explicit [explicitReasoning] from
  /// `delta.reasoning_content`) into separate reasoning and visible sections.
  static ThinkingSplitResult parse(
    String rawContent, {
    String explicitReasoning = '',
  }) {
    final thinkingBuffer = StringBuffer();
    if (explicitReasoning.isNotEmpty) {
      thinkingBuffer.write(explicitReasoning);
    }

    final visibleBuffer = StringBuffer();
    var cursor = 0;
    var isThinkingOpen = false;

    while (cursor < rawContent.length) {
      final openIdx = rawContent.indexOf(_openTag, cursor);
      if (openIdx == -1) {
        visibleBuffer.write(rawContent.substring(cursor));
        break;
      }

      if (openIdx > cursor) {
        visibleBuffer.write(rawContent.substring(cursor, openIdx));
      }

      final contentStart = openIdx + _openTag.length;
      final closeIdx = rawContent.indexOf(_closeTag, contentStart);
      if (closeIdx == -1) {
        // Still streaming inside `<think>`
        final part = rawContent.substring(contentStart).trimLeft();
        if (thinkingBuffer.isNotEmpty && part.isNotEmpty) {
          thinkingBuffer.write('\n');
        }
        thinkingBuffer.write(part);
        isThinkingOpen = true;
        break;
      }

      final block = rawContent.substring(contentStart, closeIdx).trim();
      if (block.isNotEmpty) {
        if (thinkingBuffer.isNotEmpty) thinkingBuffer.write('\n');
        thinkingBuffer.write(block);
      }
      cursor = closeIdx + _closeTag.length;
    }

    return ThinkingSplitResult(
      visibleContent: visibleBuffer.toString().trimLeft(),
      thinkingContent: thinkingBuffer.toString().trim(),
      isThinkingOpen: isThinkingOpen,
    );
  }
}
