import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_highlight/flutter_highlight.dart';
import 'package:flutter_highlight/themes/atom-one-dark.dart';
import 'package:flutter_highlight/themes/atom-one-light.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../core/theme/app_theme_builder.dart';
import '../../core/theme/app_theme_tokens.dart';
import '../../core/theme/theme_controller.dart';
import '../../core/utils/persian_digits.dart';
import '../../core/widgets/ambient_cosmic_background.dart';
import '../../core/widgets/surface_container.dart';
import '../chat/domain/chat_models.dart';
import 'artifact_service.dart';

/// Interactive Artifact viewer supporting sandboxed WebView preview for HTML/SVG,
/// rich Markdown reading, syntax-highlighted code inspection, PDF export, and
/// native Android sharing.
class ArtifactPreviewScreen extends ConsumerStatefulWidget {
  const ArtifactPreviewScreen({
    super.key,
    required this.artifact,
  });

  final ChatArtifactRef artifact;

  @override
  ConsumerState<ArtifactPreviewScreen> createState() =>
      _ArtifactPreviewScreenState();
}

class _ArtifactPreviewScreenState
    extends ConsumerState<ArtifactPreviewScreen> {
  WebViewController? _webController;
  bool _showSourceCode = false;
  bool _isExporting = false;

  @override
  void initState() {
    super.initState();
    if (widget.artifact.supportsHtmlPreview) {
      _initWebView();
    }
  }

  void _initWebView() {
    final htmlContent = widget.artifact.extension == 'svg'
        ? _wrapSvgAsHtml(widget.artifact.content)
        : widget.artifact.content;

    final controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.white)
      ..setNavigationDelegate(
        NavigationDelegate(
          onNavigationRequest: (request) {
            if (request.url.startsWith('about:') ||
                request.url.startsWith('data:')) {
              return NavigationDecision.navigate;
            }
            return NavigationDecision.prevent;
          },
        ),
      )
      ..loadHtmlString(htmlContent);
    _webController = controller;
  }

  String _wrapSvgAsHtml(String svg) {
    return '''
<!DOCTYPE html>
<html dir="rtl" lang="fa">
<head>
<meta charset="utf-8" />
<meta name="viewport" content="width=device-width, initial-scale=1.0" />
<style>
  html, body {
    margin: 0; padding: 16px; min-height: 100vh;
    display: flex; align-items: center; justify-content: center;
    background: #0B0A16;
  }
  svg { max-width: 100%; height: auto; border-radius: 14px; }
</style>
</head>
<body>$svg</body>
</html>
''';
  }

  Future<void> _exportAndShare({required String mode}) async {
    if (_isExporting) return;
    setState(() => _isExporting = true);
    try {
      final service = ref.read(artifactServiceProvider);
      late final File outFile;
      if (mode == 'pdf') {
        outFile = await service.exportTextAsFile(
          title: widget.artifact.title,
          content: widget.artifact.content,
          format: 'pdf',
        );
      } else {
        if (widget.artifact.savedFilePath != null &&
            await File(widget.artifact.savedFilePath!).exists()) {
          outFile = File(widget.artifact.savedFilePath!);
        } else {
          final persisted = await service.persistArtifact(
            conversationId: 'library',
            messageId: 'preview',
            artifact: widget.artifact,
            saveToDb: false,
          );
          outFile = File(persisted.savedFilePath!);
        }
      }
      await service.shareFile(outFile, subject: widget.artifact.title);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطا در خروجی گرفتن فایل: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.orbiTokens;
    final themeSettings = ref.watch(themeSettingsProvider);

    return Scaffold(
      backgroundColor: tokens.backgroundTop,
      body: AmbientCosmicBackground(
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                child: OrbiSurface(
                  borderRadius: 22,
                  useBackdropBlur: true,
                  reducedBlur: themeSettings.reducedBlur,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 8,
                  ),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back_rounded),
                        onPressed: () => Navigator.of(context).pop(),
                        tooltip: 'بازگشت',
                      ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.artifact.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            Text(
                              '${widget.artifact.fileName} • ${PersianFormatter.formatFileSize(widget.artifact.sizeBytes)}',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                      if (widget.artifact.supportsHtmlPreview)
                        IconButton(
                          icon: Icon(
                            _showSourceCode
                                ? Icons.visibility_rounded
                                : Icons.code_rounded,
                          ),
                          tooltip: _showSourceCode ? 'پیشنمایش زنده' : 'مشاهده کد',
                          onPressed: () {
                            setState(() => _showSourceCode = !_showSourceCode);
                          },
                        ),
                      IconButton(
                        icon: const Icon(Icons.copy_rounded),
                        tooltip: 'کپی محتوا',
                        onPressed: () async {
                          await Clipboard.setData(
                            ClipboardData(text: widget.artifact.content),
                          );
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('محتوای فایل در حافظه کپی شد'),
                              ),
                            );
                          }
                        },
                      ),
                    ],
                  ),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
                  child: OrbiSurface(
                    borderRadius: 22,
                    reducedBlur: themeSettings.reducedBlur,
                    padding: EdgeInsets.zero,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(22),
                      child: _buildBody(tokens),
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 4, 14, 12),
                child: Row(
                  children: [
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: _isExporting
                            ? null
                            : () => _exportAndShare(mode: 'raw'),
                        icon: const Icon(Icons.ios_share_rounded, size: 18),
                        label: Text(
                          'ذخیره و اشتراک (${widget.artifact.extension.toUpperCase()})',
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _isExporting
                            ? null
                            : () => _exportAndShare(mode: 'pdf'),
                        icon: const Icon(Icons.picture_as_pdf_rounded, size: 18),
                        label: const Text('خروجی PDF فارسی'),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBody(OrbiThemeTokens tokens) {
    if (widget.artifact.supportsHtmlPreview &&
        !_showSourceCode &&
        _webController != null) {
      return WebViewWidget(controller: _webController!);
    }

    if (widget.artifact.extension == 'md') {
      return SingleChildScrollView(
        padding: const EdgeInsets.all(18),
        child: Directionality(
          textDirection: TextDirection.rtl,
          child: MarkdownBody(
            data: widget.artifact.content,
            selectable: true,
            styleSheet: MarkdownStyleSheet.fromTheme(Theme.of(context)).copyWith(
              p: Theme.of(context).textTheme.bodyLarge,
            ),
          ),
        ),
      );
    }

    if (widget.artifact.extension == 'csv') {
      return _CsvTablePreview(csvText: widget.artifact.content);
    }

    final displaySource = widget.artifact.extension == 'json'
        ? _prettyJson(widget.artifact.content)
        : widget.artifact.content;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(14),
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: HighlightView(
            displaySource,
            language: widget.artifact.extension,
            theme: tokens.preset.isDark ? atomOneDarkTheme : atomOneLightTheme,
            padding: const EdgeInsets.all(14),
            textStyle: const TextStyle(
              fontFamily: AppThemeBuilder.monoFontFamily,
              fontSize: 13,
              height: 1.55,
            ),
          ),
        ),
      ),
    );
  }

  String _prettyJson(String raw) {
    try {
      return const JsonEncoder.withIndent('  ').convert(jsonDecode(raw));
    } catch (_) {
      return raw;
    }
  }
}

class _CsvTablePreview extends StatelessWidget {
  const _CsvTablePreview({required this.csvText});

  final String csvText;

  @override
  Widget build(BuildContext context) {
    final tokens = context.orbiTokens;
    final rows = csvText
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .map((l) => l.split(','))
        .toList();

    if (rows.isEmpty) {
      return const Center(child: Text('جدول خالی است'));
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(14),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          headingRowColor: WidgetStatePropertyAll(
            withAlphaFraction(tokens.accentPrimary, 0.16),
          ),
          columns: [
            for (final h in rows.first)
              DataColumn(
                label: Text(
                  h.trim(),
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
          ],
          rows: [
            for (final row in rows.skip(1))
              DataRow(
                cells: [
                  for (var i = 0; i < rows.first.length; i++)
                    DataCell(Text(i < row.length ? row[i].trim() : '')),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
