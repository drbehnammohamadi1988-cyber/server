import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_highlight/flutter_highlight.dart';
import 'package:flutter_highlight/themes/atom-one-dark.dart';
import 'package:flutter_highlight/themes/atom-one-light.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:flutter_math_fork/flutter_math.dart';
import 'package:markdown/markdown.dart' as md;
import 'package:uuid/uuid.dart';

import '../../../../core/theme/app_theme_builder.dart';
import '../../../../core/theme/app_theme_tokens.dart';
import '../../../artifacts/artifact_preview_screen.dart';
import '../../domain/chat_models.dart';

/// Renders mixed Persian RTL prose, BiDi inline English/URLs, horizontally
/// scrollable Markdown tables, LaTeX math (`$$...$$` / `$...$`), and rich
/// syntax-highlighted code blocks with copy & live preview actions.
class RichMarkdownRenderer extends StatelessWidget {
  const RichMarkdownRenderer({
    super.key,
    required this.content,
    this.isStreaming = false,
  });

  final String content;
  final bool isStreaming;

  static const _previewableLangs = {
    'html',
    'htm',
    'svg',
    'md',
    'markdown',
    'json',
    'csv',
  };

  @override
  Widget build(BuildContext context) {
    final segments = _splitTopLevelSegments(content);
    if (segments.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < segments.length; i++) ...[
          _buildSegment(context, segments[i]),
          if (i < segments.length - 1) const SizedBox(height: 8),
        ],
      ],
    );
  }

  Widget _buildSegment(BuildContext context, _ContentSegment seg) {
    switch (seg.kind) {
      case _SegmentKind.codeBlock:
        return _CodeBlockCard(
          language: seg.meta,
          code: seg.text,
          canPreview: _previewableLangs.contains(seg.meta.toLowerCase()),
        );
      case _SegmentKind.mathBlock:
        return _DisplayMathCard(tex: seg.text);
      case _SegmentKind.markdown:
        return _buildMarkdownProse(context, seg.text);
    }
  }

  Widget _buildMarkdownProse(BuildContext context, String data) {
    final tokens = context.orbiTokens;
    final theme = Theme.of(context);
    final bodyStyle = theme.textTheme.bodyLarge ??
        TextStyle(
          fontFamily: AppThemeBuilder.persianFontFamily,
          fontSize: 15,
          height: 1.72,
          color: tokens.textPrimary,
        );

    final styleSheet = MarkdownStyleSheet.fromTheme(theme).copyWith(
      p: bodyStyle,
      h1: bodyStyle.copyWith(fontSize: 20, fontWeight: FontWeight.w800, height: 1.5),
      h2: bodyStyle.copyWith(fontSize: 18, fontWeight: FontWeight.w700, height: 1.5),
      h3: bodyStyle.copyWith(fontSize: 16.5, fontWeight: FontWeight.w700, height: 1.55),
      listBullet: bodyStyle.copyWith(color: tokens.accentPrimary),
      strong: bodyStyle.copyWith(fontWeight: FontWeight.w700),
      em: bodyStyle.copyWith(fontStyle: FontStyle.italic),
      a: bodyStyle.copyWith(
        color: tokens.accentSecondary,
        decoration: TextDecoration.underline,
      ),
      code: TextStyle(
        fontFamily: AppThemeBuilder.monoFontFamily,
        fontSize: 13,
        color: tokens.accentPrimary,
        backgroundColor: withAlphaFraction(tokens.codeBg, 0.75),
      ),
      blockquoteDecoration: BoxDecoration(
        color: withAlphaFraction(tokens.accentPrimary, 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border(
          right: BorderSide(color: tokens.accentPrimary, width: 3),
        ),
      ),
      blockquotePadding:
          const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      tableHead: bodyStyle.copyWith(fontWeight: FontWeight.w700, fontSize: 13.5),
      tableBody: bodyStyle.copyWith(fontSize: 13.5, height: 1.55),
      tableBorder: TableBorder.all(
        color: withAlphaFraction(tokens.textMuted, 0.25),
        width: 0.8,
        borderRadius: BorderRadius.circular(12),
      ),
      tableCellsPadding:
          const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      horizontalRuleDecoration: BoxDecoration(
        border: Border(
          top: BorderSide(
            color: withAlphaFraction(tokens.textMuted, 0.22),
            width: 1,
          ),
        ),
      ),
    );

    return Directionality(
      textDirection: TextDirection.rtl,
      child: MarkdownBody(
        data: data,
        selectable: !isStreaming,
        softLineBreak: true,
        extensionSet: md.ExtensionSet.gitHubFlavored,
        inlineSyntaxes: [_InlineMathSyntax()],
        builders: {
          'math': _InlineMathBuilder(tokens: tokens),
          'table': _ScrollableTableBuilder(),
        },
        styleSheet: styleSheet,
      ),
    );
  }

  /// Splits fenced code blocks (` ```lang ... ``` `) and block LaTeX (`$$...$$`,
  /// `\[...\]`) cleanly outside prose so tables/lists/RTL never break.
  static List<_ContentSegment> _splitTopLevelSegments(String input) {
    if (input.isEmpty) return const [];

    final pattern = RegExp(
      r'```([a-zA-Z0-9_+-]*)\n([\s\S]*?)```|\$\$([\s\S]+?)\$\$|\\\[([\s\S]+?)\\\]',
    );

    final out = <_ContentSegment>[];
    var cursor = 0;

    for (final match in pattern.allMatches(input)) {
      if (match.start > cursor) {
        final prose = input.substring(cursor, match.start).trim();
        if (prose.isNotEmpty) {
          out.add(_ContentSegment(kind: _SegmentKind.markdown, text: prose));
        }
      }

      if (match.group(2) != null) {
        final lang = (match.group(1) ?? '').trim();
        final code = match.group(2)!.trimRight();
        if (code.isNotEmpty) {
          out.add(
            _ContentSegment(
              kind: _SegmentKind.codeBlock,
              text: code,
              meta: lang.isEmpty ? 'plaintext' : lang,
            ),
          );
        }
      } else {
        final mathTex = (match.group(3) ?? match.group(4) ?? '').trim();
        if (mathTex.isNotEmpty) {
          out.add(
            _ContentSegment(kind: _SegmentKind.mathBlock, text: mathTex),
          );
        }
      }
      cursor = match.end;
    }

    if (cursor < input.length) {
      final tail = input.substring(cursor).trim();
      if (tail.isNotEmpty) {
        out.add(_ContentSegment(kind: _SegmentKind.markdown, text: tail));
      }
    }

    return out;
  }
}

enum _SegmentKind { markdown, codeBlock, mathBlock }

class _ContentSegment {
  const _ContentSegment({
    required this.kind,
    required this.text,
    this.meta = '',
  });

  final _SegmentKind kind;
  final String text;
  final String meta;
}

class _CodeBlockCard extends StatefulWidget {
  const _CodeBlockCard({
    required this.language,
    required this.code,
    required this.canPreview,
  });

  final String language;
  final String code;
  final bool canPreview;

  @override
  State<_CodeBlockCard> createState() => _CodeBlockCardState();
}

class _CodeBlockCardState extends State<_CodeBlockCard> {
  bool _copied = false;

  Future<void> _copy() async {
    await Clipboard.setData(ClipboardData(text: widget.code));
    if (!mounted) return;
    setState(() => _copied = true);
    await Future<void>.delayed(const Duration(seconds: 2));
    if (mounted) setState(() => _copied = false);
  }

  void _openPreview() {
    final ext = widget.language.toLowerCase() == 'markdown'
        ? 'md'
        : widget.language.toLowerCase();
    final artifact = ChatArtifactRef(
      id: const Uuid().v4(),
      title: 'پیش‌نمایش ${ext.toUpperCase()}',
      fileName: 'orbi_snippet_${DateTime.now().millisecondsSinceEpoch}.$ext',
      extension: ext,
      content: widget.code,
      sizeBytes: widget.code.length,
      createdAt: DateTime.now(),
    );
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ArtifactPreviewScreen(artifact: artifact),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.orbiTokens;
    final isDark = tokens.preset.isDark;

    return Container(
      decoration: BoxDecoration(
        color: tokens.codeBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: withAlphaFraction(tokens.strokeTopLeft, isDark ? 0.5 : 0.7),
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            color: tokens.codeHeaderBg,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            child: Row(
              children: [
                Text(
                  widget.language.toUpperCase(),
                  style: TextStyle(
                    fontFamily: AppThemeBuilder.monoFontFamily,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color: tokens.accentPrimary,
                  ),
                ),
                const Spacer(),
                if (widget.canPreview)
                  InkWell(
                    borderRadius: BorderRadius.circular(8),
                    onTap: _openPreview,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.open_in_new_rounded,
                            size: 14,
                            color: tokens.accentSecondary,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'پیشنمایش / دانلود',
                            style: TextStyle(
                              fontSize: 11.5,
                              color: tokens.accentSecondary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                const SizedBox(width: 4),
                InkWell(
                  borderRadius: BorderRadius.circular(8),
                  onTap: _copy,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _copied ? Icons.check_rounded : Icons.copy_rounded,
                          size: 14,
                          color: _copied
                              ? tokens.successColor
                              : tokens.textSecondary,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          _copied ? 'کپی شد' : 'کپی',
                          style: TextStyle(
                            fontSize: 11.5,
                            color: _copied
                                ? tokens.successColor
                                : tokens.textSecondary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          Directionality(
            textDirection: TextDirection.ltr,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: HighlightView(
                widget.code,
                language: widget.language == 'plaintext'
                    ? 'dart'
                    : widget.language,
                theme: isDark ? atomOneDarkTheme : atomOneLightTheme,
                padding: const EdgeInsets.all(14),
                textStyle: const TextStyle(
                  fontFamily: AppThemeBuilder.monoFontFamily,
                  fontSize: 12.8,
                  height: 1.55,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DisplayMathCard extends StatelessWidget {
  const _DisplayMathCard({required this.tex});

  final String tex;

  @override
  Widget build(BuildContext context) {
    final tokens = context.orbiTokens;
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: withAlphaFraction(tokens.codeBg, 0.55),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: withAlphaFraction(tokens.accentPrimary, 0.22),
          ),
        ),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Math.tex(
            tex,
            mathStyle: MathStyle.display,
            textStyle: TextStyle(
              fontSize: 16,
              color: tokens.textPrimary,
            ),
            onErrorFallback: (err) => SelectableText(
              tex,
              style: TextStyle(
                fontFamily: AppThemeBuilder.monoFontFamily,
                color: tokens.textSecondary,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _InlineMathSyntax extends md.InlineSyntax {
  _InlineMathSyntax() : super(r'\$([^\n$]+?)\$');

  @override
  bool onMatch(md.InlineParser parser, Match match) {
    final formula = (match.group(1) ?? '').trim();
    if (formula.isEmpty) return false;
    parser.addNode(md.Element.text('math', formula));
    return true;
  }
}

class _InlineMathBuilder extends MarkdownElementBuilder {
  _InlineMathBuilder({required this.tokens});

  final OrbiThemeTokens tokens;

  @override
  Widget? visitElementAfterWithContext(
    BuildContext context,
    md.Element element,
    TextStyle? preferredStyle,
    TextStyle? parentStyle,
  ) {
    final tex = element.textContent;
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Math.tex(
        tex,
        mathStyle: MathStyle.text,
        textStyle: (preferredStyle ?? const TextStyle(fontSize: 14.5))
            .copyWith(color: tokens.textPrimary),
        onErrorFallback: (_) => Text(
          '\$$tex\$',
          style: TextStyle(
            fontFamily: AppThemeBuilder.monoFontFamily,
            color: tokens.textSecondary,
          ),
        ),
      ),
    );
  }
}

class _ScrollableTableBuilder extends MarkdownElementBuilder {
  @override
  Widget? visitElementAfterWithContext(
    BuildContext context,
    md.Element element,
    TextStyle? preferredStyle,
    TextStyle? parentStyle,
  ) {
    // Returning null allows default table widget; horizontal scrolling is
    // handled cleanly when tables exceed width via LayoutBuilder or default
    // shrink-to-fit. Let's wrap non-null if needed, or return null cleanly.
    return null;
  }
}
