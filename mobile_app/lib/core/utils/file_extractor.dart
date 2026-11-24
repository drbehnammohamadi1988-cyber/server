import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:image/image.dart' as img;

/// Client-side image compression and text/PDF content extraction so files and
/// images stay fast, lightweight, and usable with `gateway`.
class FileProcessor {
  const FileProcessor._();

  static const Set<String> textExtensions = {
    'txt',
    'md',
    'markdown',
    'csv',
    'json',
    'yaml',
    'yml',
    'xml',
    'html',
    'htm',
    'css',
    'js',
    'ts',
    'dart',
    'py',
    'go',
    'java',
    'kt',
    'sql',
    'sh',
    'log',
    'ini',
    'env',
  };

  /// Resizes large images to max [maxDimension]px and re-encodes as JPEG
  /// before upload/storage.
  static Future<Uint8List> compressImageBytes(
    Uint8List inputBytes, {
    int maxDimension = 1600,
    int quality = 82,
  }) async {
    final decoded = img.decodeImage(inputBytes);
    if (decoded == null) return inputBytes;

    img.Image resized = decoded;
    if (decoded.width > maxDimension || decoded.height > maxDimension) {
      resized = decoded.width >= decoded.height
          ? img.copyResize(decoded, width: maxDimension)
          : img.copyResize(decoded, height: maxDimension);
    }
    return Uint8List.fromList(img.encodeJpg(resized, quality: quality));
  }

  /// Extracts readable text from text/code/CSV/JSON/Markdown or basic PDF files.
  static Future<String> extractReadableText(String path, String extension) async {
    final ext = extension.toLowerCase().replaceAll('.', '');
    final file = File(path);
    if (!await file.exists()) return '';

    if (textExtensions.contains(ext)) {
      final bytes = await file.readAsBytes();
      final decoded = utf8.decode(bytes, allowMalformed: true);
      return _truncateForPrompt(decoded);
    }

    if (ext == 'pdf') {
      final bytes = await file.readAsBytes();
      final extracted = extractTextFromPdfBytes(bytes);
      return _truncateForPrompt(extracted);
    }

    return '';
  }

  /// Lightweight pure-Dart PDF text extractor supporting uncompressed and
  /// FlateDecode content streams with `Tj` / `TJ` operators.
  static String extractTextFromPdfBytes(Uint8List bytes) {
    final latin = latin1.decode(bytes, allowInvalid: true);
    final chunks = <String>[];

    // 1. Inspect uncompressed stream blocks and decompress FlateDecode blocks
    final streamRegex = RegExp(r'stream\r?\n([\s\S]*?)\r?\nendstream');
    for (final match in streamRegex.allMatches(latin)) {
      final rawStream = match.group(1) ?? '';
      final rawBytes = latin1.encode(rawStream);
      var content = rawStream;
      try {
        final inflated = zlib.decode(rawBytes);
        content = utf8.decode(inflated, allowMalformed: true);
      } catch (_) {
        // Keep rawStream if not zlib-compressed
      }
      _collectPdfTextOperators(content, chunks);
    }

    if (chunks.isEmpty) {
      _collectPdfTextOperators(latin, chunks);
    }

    return chunks.join(' ').replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  static void _collectPdfTextOperators(String content, List<String> out) {
    final tjSingle = RegExp(r'\(([^()\\]*(?:\\.[^()\\]*)*)\)\s*Tj');
    for (final m in tjSingle.allMatches(content)) {
      final t = _unescapePdfString(m.group(1) ?? '');
      if (t.trim().isNotEmpty) out.add(t);
    }

    final tjArray = RegExp(r'\[(.*?)\]\s*TJ', dotAll: true);
    for (final m in tjArray.allMatches(content)) {
      final inside = m.group(1) ?? '';
      final partRegex = RegExp(r'\(([^()\\]*(?:\\.[^()\\]*)*)\)');
      final buf = StringBuffer();
      for (final p in partRegex.allMatches(inside)) {
        buf.write(_unescapePdfString(p.group(1) ?? ''));
      }
      final text = buf.toString().trim();
      if (text.isNotEmpty) out.add(text);
    }
  }

  static String _unescapePdfString(String raw) {
    return raw
        .replaceAll(r'\n', '\n')
        .replaceAll(r'\r', '')
        .replaceAll(r'\t', ' ')
        .replaceAll(r'\(', '(')
        .replaceAll(r'\)', ')')
        .replaceAll(r'\\', r'\');
  }

  static String _truncateForPrompt(String text, {int maxChars = 24000}) {
    final trimmed = text.trim();
    if (trimmed.length <= maxChars) return trimmed;
    return '${trimmed.substring(0, maxChars)}\n\n[... بخش‌های بعدی فایل به دلیل محدودیت طول خلاصه شدند ...]';
  }
}
