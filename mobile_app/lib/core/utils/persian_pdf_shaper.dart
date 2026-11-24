import 'package:bidi/bidi.dart' as bidi;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

/// Shapes Persian/Arabic text using contextual presentation forms and UAX #9
/// BiDi visual ordering so generated PDFs render connected, right-to-left
/// Persian alongside intact LTR English/numbers without broken line wrapping.
class PersianPdfShaper {
  const PersianPdfShaper._();

  static final RegExp _rtlDetect = RegExp(r'[\u0600-\u06FF\u0750-\u077F\uFB50-\uFDFF\uFE70-\uFEFF]');

  /// Returns `true` if [text] contains Persian/Arabic characters.
  static bool containsRtl(String text) => _rtlDetect.hasMatch(text);

  /// Wraps a logical paragraph to fit [maxCharsPerLine] (or [maxWidth] with
  /// [font] and [fontSize]), then shapes and visually reorders each line
  /// individually so line 1 stays at the top and line N at the bottom.
  static List<String> shapeParagraphToVisualLines(
    String logicalParagraph, {
    PdfFont? font,
    double fontSize = 11,
    double? maxWidth,
    int fallbackCharsPerLine = 68,
  }) {
    final normalized = _normalizePersianChars(logicalParagraph);
    final rawLines = normalized.split('\n');
    final visualLines = <String>[];

    for (final rawLine in rawLines) {
      if (rawLine.trim().isEmpty) {
        visualLines.add('');
        continue;
      }
      final wrappedLogical = _wrapLogicalLine(
        rawLine,
        font: font,
        fontSize: fontSize,
        maxWidth: maxWidth,
        fallbackCharsPerLine: fallbackCharsPerLine,
      );
      for (final logicalLine in wrappedLogical) {
        visualLines.add(shapeSingleLine(logicalLine));
      }
    }

    return visualLines;
  }

  /// Shapes a single already-wrapped logical line into its visual RTL glyph
  /// string suitable for rendering in `package:pdf` with `TextDirection.ltr`
  /// and `TextAlign.right`.
  static String shapeSingleLine(String logicalLine) {
    if (logicalLine.isEmpty) return '';
    final normalized = _normalizePersianChars(logicalLine);
    if (!containsRtl(normalized)) {
      return normalized.replaceAll('\u200C', '').replaceAll('\u200D', '');
    }

    // Ensure paragraph embedding starts RTL when Persian text is present even
    // if the line starts with a number or bullet, by keeping pure BiDi logic
    // or prefixing RLM only if needed.
    final startsWithNeutralOrLatin =
        !_rtlDetect.hasMatch(normalized.characters.firstOrNull ?? '');
    final inputForBidi =
        startsWithNeutralOrLatin ? '\u200F$normalized' : normalized;

    final visualCodes = bidi.logicalToVisual(inputForBidi);
    final cleaned = <int>[];
    for (final code in visualCodes) {
      if (code == 0x200C || code == 0x200D || code == 0x200F || code == 0x200E) {
        continue;
      }
      cleaned.add(code);
    }
    return String.fromCharCodes(cleaned);
  }

  /// Normalizes legacy Arabic Kaf/Yeh variants to Persian Kaf/Yeh so shaping
  /// and font metrics match Vazirmatn consistently.
  static String _normalizePersianChars(String input) {
    return input
        .replaceAll('\u0643', '\u06A9') // ك -> ک
        .replaceAll('\u064A', '\u06CC'); // ي -> ی
  }

  static List<String> _wrapLogicalLine(
    String line, {
    PdfFont? font,
    required double fontSize,
    double? maxWidth,
    required int fallbackCharsPerLine,
  }) {
    final words = line.split(' ');
    final wrapped = <String>[];
    var current = StringBuffer();

    bool fits(String candidate) {
      if (font != null && maxWidth != null) {
        final shaped = shapeSingleLine(candidate);
        final metrics = font.stringMetrics(shaped) * fontSize;
        return metrics.width <= maxWidth;
      }
      return candidate.length <= fallbackCharsPerLine;
    }

    for (final word in words) {
      final candidate =
          current.isEmpty ? word : '${current.toString()} $word';
      if (current.isEmpty || fits(candidate)) {
        current = StringBuffer(candidate);
      } else {
        wrapped.add(current.toString());
        current = StringBuffer(word);
      }
    }
    if (current.isNotEmpty) {
      wrapped.add(current.toString());
    }
    return wrapped;
  }

  /// Convenience helper to emit properly aligned PDF widgets for a Persian or
  /// mixed BiDi paragraph without triggering `pdf`'s broken pre-wrap RTL.
  static List<pw.Widget> buildPdfParagraphWidgets(
    String logicalText, {
    required pw.Font regularFont,
    required pw.TextStyle style,
    PdfFont? pdfFont,
    double maxWidth = 480,
    pw.TextAlign? align,
  }) {
    final lines = shapeParagraphToVisualLines(
      logicalText,
      font: pdfFont,
      fontSize: style.fontSize ?? 11,
      maxWidth: maxWidth,
    );
    final effectiveAlign =
        align ?? (containsRtl(logicalText) ? pw.TextAlign.right : pw.TextAlign.left);

    return [
      for (final line in lines)
        line.isEmpty
            ? pw.SizedBox(height: (style.fontSize ?? 11) * 0.7)
            : pw.Container(
                width: double.infinity,
                margin: const pw.EdgeInsets.only(bottom: 3),
                child: pw.Directionality(
                  textDirection: pw.TextDirection.ltr,
                  child: pw.Text(
                    line,
                    style: style.copyWith(font: regularFont),
                    textAlign: effectiveAlign,
                    softWrap: false,
                  ),
                ),
              ),
    ];
  }
}

extension on String {
  Iterable<String> get characters sync* {
    for (final rune in runes) {
      yield String.fromCharCode(rune);
    }
  }
}
