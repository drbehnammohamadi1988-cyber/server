import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';
import 'package:uuid/uuid.dart';

import '../../core/database/app_database.dart';
import '../../core/utils/persian_digits.dart';
import '../../core/utils/persian_pdf_shaper.dart';
import '../chat/domain/chat_models.dart';

final artifactServiceProvider = Provider<ArtifactService>((ref) {
  return ArtifactService(db: ref.watch(appDatabaseProvider));
});

/// Builds, extracts, persists, exports (PDF with embedded Vazirmatn + Persian
/// BiDi shaping, MD, TXT, HTML, CSV, JSON, code), and shares artifacts.
class ArtifactService {
  ArtifactService({required AppDatabase db}) : _db = db;

  final AppDatabase _db;
  static const _uuid = Uuid();

  /// Extracts downloadable/previewable artifacts from an assistant response.
  /// If [forceDocumentArtifact] is true and no code block was emitted, wraps the
  /// structured Markdown report itself as a `.md` / `.pdf`-ready artifact.
  List<ChatArtifactRef> extractArtifactsFromContent(
    String content, {
    bool forceDocumentArtifact = false,
  }) {
    final results = <ChatArtifactRef>[];
    final codeRegex = RegExp(r'```([a-zA-Z0-9_+-]*)\n([\s\S]*?)```');
    var index = 1;

    for (final match in codeRegex.allMatches(content)) {
      final lang = (match.group(1) ?? '').trim().toLowerCase();
      final body = (match.group(2) ?? '').trim();
      if (body.isEmpty) continue;

      final ext = _extensionForLang(lang);
      final isPreviewableOrFile = ext == 'html' ||
          ext == 'svg' ||
          ext == 'csv' ||
          ext == 'json' ||
          ext == 'md' ||
          (forceDocumentArtifact && body.length > 40) ||
          body.split('\n').length >= 10;

      if (!isPreviewableOrFile) continue;

      final title = _titleForExtension(ext, index);
      final safeName = 'orbi_${ext}_${DateTime.now().millisecondsSinceEpoch}_$index.$ext';
      results.add(
        ChatArtifactRef(
          id: _uuid.v4(),
          title: title,
          fileName: safeName,
          extension: ext,
          content: body,
          sizeBytes: utf8.encode(body).length,
          createdAt: DateTime.now(),
        ),
      );
      index++;
    }

    if (results.isEmpty && forceDocumentArtifact && content.trim().isNotEmpty) {
      final cleaned = content.trim();
      results.add(
        ChatArtifactRef(
          id: _uuid.v4(),
          title: 'سند و گزارش اختصاصی اوربی',
          fileName: 'orbi_report_${DateTime.now().millisecondsSinceEpoch}.md',
          extension: 'md',
          content: cleaned,
          sizeBytes: utf8.encode(cleaned).length,
          createdAt: DateTime.now(),
        ),
      );
    }

    return results;
  }

  /// Writes an artifact's raw file to disk and persists its metadata in SQLite.
  Future<ChatArtifactRef> persistArtifact({
    required String conversationId,
    required String messageId,
    required ChatArtifactRef artifact,
    bool saveToDb = true,
  }) async {
    final dir = await _artifactsDir();
    final targetPath = p.join(dir.path, artifact.fileName);
    final file = File(targetPath);
    final bytes = utf8.encode(artifact.content);
    await file.writeAsBytes(bytes, flush: true);

    final updated = artifact.copyWith(
      savedFilePath: targetPath,
      sizeBytes: bytes.length,
    );

    if (saveToDb) {
      await _db.saveArtifact(
        conversationId: conversationId,
        messageId: messageId,
        artifact: updated,
      );
    }
    return updated;
  }

  /// Exports arbitrary message or document text into `.pdf` (with embedded
  /// `Vazirmatn` font and Persian shaping + BiDi ordering), `.md`, or `.txt`.
  Future<File> exportTextAsFile({
    required String title,
    required String content,
    required String format, // 'pdf' | 'md' | 'txt'
  }) async {
    final dir = await _artifactsDir();
    final stamp = DateTime.now().millisecondsSinceEpoch;
    final cleanFormat = format.toLowerCase();

    if (cleanFormat == 'pdf') {
      final pdfBytes = await buildPersianPdfBytes(title: title, body: content);
      final path = p.join(dir.path, 'orbi_document_$stamp.pdf');
      final file = File(path);
      await file.writeAsBytes(pdfBytes, flush: true);
      return file;
    }

    final ext = cleanFormat == 'md' ? 'md' : 'txt';
    final path = p.join(dir.path, 'orbi_document_$stamp.$ext');
    final file = File(path);
    await file.writeAsString(content, flush: true);
    return file;
  }

  /// Generates a properly shaped, RTL Persian PDF with embedded Vazirmatn and
  /// JetBrains Mono fonts.
  Future<Uint8List> buildPersianPdfBytes({
    required String title,
    required String body,
  }) async {
    final regularData =
        await rootBundle.load('assets/fonts/Vazirmatn-Regular.ttf');
    final boldData = await rootBundle.load('assets/fonts/Vazirmatn-Bold.ttf');
    final monoData =
        await rootBundle.load('assets/fonts/JetBrainsMono-Regular.ttf');

    final regularFont = pw.Font.ttf(regularData);
    final boldFont = pw.Font.ttf(boldData);
    final monoFont = pw.Font.ttf(monoData);

    final doc = pw.Document(
      title: title,
      creator: 'Orbi AI',
    );
    final pdfRegular = regularFont.getFont(
      pw.Context(document: doc.document),
    );
    final pdfBold = boldFont.getFont(
      pw.Context(document: doc.document),
    );

    final dateText = PersianFormatter.formatJalaliShort(DateTime.now());
    final headerLine = PersianPdfShaper.shapeSingleLine(title);
    final metaLine = PersianPdfShaper.shapeSingleLine(
      'ساخته‌شده با اوربی هوش  •  $dateText',
    );

    final sections = _splitMarkdownIntoPdfBlocks(body);

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.symmetric(horizontal: 34, vertical: 36),
        header: (context) => pw.Container(
          margin: const pw.EdgeInsets.only(bottom: 14),
          padding: const pw.EdgeInsets.only(bottom: 8),
          decoration: const pw.BoxDecoration(
            border: pw.Border(
              bottom: pw.BorderSide(color: PdfColors.grey300, width: 0.75),
            ),
          ),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Directionality(
                textDirection: pw.TextDirection.ltr,
                child: pw.Text(
                  metaLine,
                  style: pw.TextStyle(
                    font: regularFont,
                    fontSize: 9,
                    color: PdfColors.grey600,
                  ),
                ),
              ),
              pw.Directionality(
                textDirection: pw.TextDirection.ltr,
                child: pw.Text(
                  headerLine,
                  style: pw.TextStyle(
                    font: boldFont,
                    fontSize: 12.5,
                    color: PdfColors.deepPurple800,
                  ),
                ),
              ),
            ],
          ),
        ),
        footer: (context) {
          final pageInfo = PersianPdfShaper.shapeSingleLine(
            'صفحه ${PersianFormatter.toPersianDigits(context.pageNumber.toString())} از ${PersianFormatter.toPersianDigits(context.pagesCount.toString())}',
          );
          return pw.Align(
            alignment: pw.Alignment.centerLeft,
            child: pw.Directionality(
              textDirection: pw.TextDirection.ltr,
              child: pw.Text(
                pageInfo,
                style: pw.TextStyle(
                  font: regularFont,
                  fontSize: 9,
                  color: PdfColors.grey600,
                ),
              ),
            ),
          );
        },
        build: (context) {
          final widgets = <pw.Widget>[];
          for (final block in sections) {
            if (block.isCode) {
              widgets.add(
                pw.Container(
                  width: double.infinity,
                  margin: const pw.EdgeInsets.symmetric(vertical: 6),
                  padding: const pw.EdgeInsets.all(10),
                  decoration: pw.BoxDecoration(
                    color: PdfColors.grey100,
                    borderRadius: pw.BorderRadius.circular(6),
                    border: pw.Border.all(color: PdfColors.grey300, width: 0.6),
                  ),
                  child: pw.Directionality(
                    textDirection: pw.TextDirection.ltr,
                    child: pw.Text(
                      block.text
                          .split('\n')
                          .map(
                            (l) => PersianPdfShaper.containsRtl(l)
                                ? PersianPdfShaper.shapeSingleLine(l)
                                : l,
                          )
                          .join('\n'),
                      style: pw.TextStyle(
                        font: monoFont,
                        fontFallback: [regularFont],
                        fontSize: 9.2,
                        color: PdfColors.grey900,
                        lineSpacing: 2,
                      ),
                    ),
                  ),
                ),
              );
            } else if (block.isHeading) {
              widgets.add(pw.SizedBox(height: 6));
              widgets.addAll(
                PersianPdfShaper.buildPdfParagraphWidgets(
                  block.text,
                  regularFont: boldFont,
                  pdfFont: pdfBold,
                  maxWidth: 500,
                  style: pw.TextStyle(
                    font: boldFont,
                    fontSize: 13.5,
                    color: PdfColors.indigo900,
                  ),
                ),
              );
              widgets.add(pw.SizedBox(height: 3));
            } else {
              widgets.addAll(
                PersianPdfShaper.buildPdfParagraphWidgets(
                  block.text,
                  regularFont: regularFont,
                  pdfFont: pdfRegular,
                  maxWidth: 500,
                  style: pw.TextStyle(
                    font: regularFont,
                    fontSize: 11,
                    color: PdfColors.grey900,
                    lineSpacing: 3,
                  ),
                ),
              );
              widgets.add(pw.SizedBox(height: 4));
            }
          }
          return widgets;
        },
      ),
    );

    return doc.save();
  }

  Future<void> shareFile(File file, {String? subject}) async {
    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(file.path)],
        subject: subject,
      ),
    );
  }

  Future<Directory> _artifactsDir() async {
    final base = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(base.path, 'orbi_artifacts'));
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  static String _extensionForLang(String lang) {
    switch (lang) {
      case 'html':
      case 'htm':
        return 'html';
      case 'svg':
        return 'svg';
      case 'csv':
        return 'csv';
      case 'json':
        return 'json';
      case 'md':
      case 'markdown':
        return 'md';
      case 'python':
      case 'py':
        return 'py';
      case 'javascript':
      case 'js':
        return 'js';
      case 'typescript':
      case 'ts':
        return 'ts';
      case 'dart':
        return 'dart';
      case 'css':
        return 'css';
      case 'sql':
        return 'sql';
      case 'yaml':
      case 'yml':
        return 'yaml';
      case 'xml':
        return 'xml';
      default:
        return lang.isEmpty ? 'txt' : lang;
    }
  }

  static String _titleForExtension(String ext, int index) {
    switch (ext) {
      case 'html':
        return 'صفحه وب تعاملی #$index';
      case 'svg':
        return 'طرح برداری SVG #$index';
      case 'csv':
        return 'جدول داده CSV #$index';
      case 'json':
        return 'ساختار داده JSON #$index';
      case 'md':
        return 'سند Markdown #$index';
      default:
        return 'فایل کد ${ext.toUpperCase()} #$index';
    }
  }

  static List<_PdfBlock> _splitMarkdownIntoPdfBlocks(String raw) {
    final blocks = <_PdfBlock>[];
    final codeFence = RegExp(r'```[a-zA-Z0-9_+-]*\n([\s\S]*?)```');
    var cursor = 0;

    void addProse(String prose) {
      for (final line in prose.split('\n')) {
        final trimmed = line.trim();
        if (trimmed.isEmpty) continue;
        if (trimmed.startsWith('#')) {
          final cleanHeading = trimmed.replaceFirst(RegExp(r'^#+\s*'), '');
          blocks.add(_PdfBlock(text: cleanHeading, isHeading: true));
        } else {
          final clean = trimmed
              .replaceAll(RegExp(r'\*\*(.*?)\*\*'), r'$1')
              .replaceAll(RegExp(r'`(.*?)`'), r'$1');
          blocks.add(_PdfBlock(text: clean));
        }
      }
    }

    for (final match in codeFence.allMatches(raw)) {
      if (match.start > cursor) {
        addProse(raw.substring(cursor, match.start));
      }
      final code = (match.group(1) ?? '').trim();
      if (code.isNotEmpty) {
        blocks.add(_PdfBlock(text: code, isCode: true));
      }
      cursor = match.end;
    }

    if (cursor < raw.length) {
      addProse(raw.substring(cursor));
    }

    if (blocks.isEmpty) {
      blocks.add(_PdfBlock(text: raw));
    }
    return blocks;
  }
}

class _PdfBlock {
  const _PdfBlock({
    required this.text,
    this.isHeading = false,
    this.isCode = false,
  });

  final String text;
  final bool isHeading;
  final bool isCode;
}
