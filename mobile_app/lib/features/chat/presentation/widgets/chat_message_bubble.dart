import 'dart:io';

import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme_tokens.dart';
import '../../../../core/utils/persian_digits.dart';
import '../../../../core/widgets/dotted_matrix_glow.dart';
import '../../../../core/widgets/surface_container.dart';
import '../../../artifacts/artifact_preview_screen.dart';
import '../../domain/chat_models.dart';
import 'rich_markdown_renderer.dart';

/// Chat message item widget rendered inside the scrollable conversation list.
///
/// Strictly avoids `BackdropFilter` inside list items for zero-jank 60–120 FPS
/// scrolling, delegating glass look to gradient fills + 1px luminous borders.
class ChatMessageBubble extends StatelessWidget {
  const ChatMessageBubble({
    super.key,
    required this.message,
    required this.reducedBlur,
    required this.isSpeakingTts,
    this.isThinkingOpen = false,
    this.onRegenerate,
    this.onFeedback,
    this.onCopy,
    this.onToggleTts,
    this.onExport,
    this.onEditUserMessage,
    this.onRetryError,
  });

  final ChatMessageEntity message;
  final bool reducedBlur;
  final bool isSpeakingTts;
  final bool isThinkingOpen;
  final VoidCallback? onRegenerate;
  final ValueChanged<MessageFeedback>? onFeedback;
  final VoidCallback? onCopy;
  final VoidCallback? onToggleTts;
  final ValueChanged<String>? onExport;
  final VoidCallback? onEditUserMessage;
  final VoidCallback? onRetryError;

  @override
  Widget build(BuildContext context) {
    if (message.role == ChatRole.user) {
      return _UserMessageView(
        message: message,
        reducedBlur: reducedBlur,
        onEdit: onEditUserMessage,
      );
    }
    return _AssistantMessageView(
      message: message,
      reducedBlur: reducedBlur,
      isSpeakingTts: isSpeakingTts,
      isThinkingOpen: isThinkingOpen,
      onRegenerate: onRegenerate,
      onFeedback: onFeedback,
      onCopy: onCopy,
      onToggleTts: onToggleTts,
      onExport: onExport,
      onRetryError: onRetryError,
    );
  }
}

class _UserMessageView extends StatelessWidget {
  const _UserMessageView({
    required this.message,
    required this.reducedBlur,
    this.onEdit,
  });

  final ChatMessageEntity message;
  final bool reducedBlur;
  final VoidCallback? onEdit;

  @override
  Widget build(BuildContext context) {
    final tokens = context.orbiTokens;
    final images = message.attachments
        .where((a) => a.kind == AttachmentKind.image)
        .toList();
    final files = message.attachments
        .where((a) => a.kind == AttachmentKind.document)
        .toList();

    return Padding(
      padding: const EdgeInsets.only(right: 8, left: 42, top: 6, bottom: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (images.isNotEmpty) ...[
            _ImageGridPreview(images: images),
            const SizedBox(height: 8),
          ],
          if (files.isNotEmpty) ...[
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                for (final f in files) _AttachmentFileChip(attachment: f),
              ],
            ),
            const SizedBox(height: 8),
          ],
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Flexible(
                child: OrbiSurface(
                  borderRadius: 20,
                  useBackdropBlur: false,
                  reducedBlur: reducedBlur,
                  tintOverride: tokens.isGlass ? tokens.glassTint : null,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 15,
                    vertical: 11,
                  ),
                  child: SelectableText(
                    message.content,
                    textDirection: TextDirection.rtl,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: tokens.textPrimary,
                          height: 1.68,
                        ),
                  ),
                ),
              ),
              if (onEdit != null) ...[
                const SizedBox(width: 4),
                IconButton(
                  icon: Icon(
                    Icons.edit_outlined,
                    size: 16,
                    color: tokens.textMuted,
                  ),
                  tooltip: 'ویرایش و ارسال مجدد',
                  visualDensity: VisualDensity.compact,
                  onPressed: onEdit,
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _AssistantMessageView extends StatelessWidget {
  const _AssistantMessageView({
    required this.message,
    required this.reducedBlur,
    required this.isSpeakingTts,
    required this.isThinkingOpen,
    this.onRegenerate,
    this.onFeedback,
    this.onCopy,
    this.onToggleTts,
    this.onExport,
    this.onRetryError,
  });

  final ChatMessageEntity message;
  final bool reducedBlur;
  final bool isSpeakingTts;
  final bool isThinkingOpen;
  final VoidCallback? onRegenerate;
  final ValueChanged<MessageFeedback>? onFeedback;
  final VoidCallback? onCopy;
  final VoidCallback? onToggleTts;
  final ValueChanged<String>? onExport;
  final VoidCallback? onRetryError;

  @override
  Widget build(BuildContext context) {
    final tokens = context.orbiTokens;
    final isStreaming = message.status == MessageStatus.streaming;

    return Padding(
      padding: const EdgeInsets.only(right: 6, left: 10, top: 8, bottom: 8),
      child: OrbiSurface(
        borderRadius: 20,
        useBackdropBlur: false,
        reducedBlur: reducedBlur,
        padding: const EdgeInsets.fromLTRB(15, 13, 15, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(colors: tokens.titleGradient),
                  ),
                  child: const Icon(
                    Icons.auto_awesome_rounded,
                    size: 13.5,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  'اوربی',
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: tokens.textPrimary,
                      ),
                ),
                if (message.modelId != null && message.modelId!.isNotEmpty) ...[
                  const SizedBox(width: 8),
                  Flexible(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(999),
                        color: withAlphaFraction(tokens.accentPrimary, 0.14),
                      ),
                      child: Text(
                        message.modelId!.split('/').last,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 10.5,
                          color: tokens.accentPrimary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
                const Spacer(),
                if (isStreaming)
                  SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation(tokens.accentPrimary),
                    ),
                  ),
              ],
            ),
            if (message.reasoningContent.isNotEmpty || isThinkingOpen) ...[
              const SizedBox(height: 10),
              _ThinkingAccordion(
                reasoning: message.reasoningContent,
                durationMs: message.reasoningDurationMs,
                isThinkingOpen: isThinkingOpen,
                reducedBlur: reducedBlur,
              ),
            ],
            if (message.isArtifactBuilding) ...[
              const SizedBox(height: 10),
              DottedMatrixGlowCard(reducedBlur: reducedBlur),
            ],
            if (message.content.isNotEmpty) ...[
              const SizedBox(height: 10),
              AnimatedOpacity(
                opacity: 1.0,
                duration: const Duration(milliseconds: 160),
                child: RichMarkdownRenderer(
                  content: message.content,
                  isStreaming: isStreaming,
                ),
              ),
            ] else if (isStreaming && !isThinkingOpen && !message.isArtifactBuilding) ...[
              const SizedBox(height: 12),
              _TypingPulseDots(color: tokens.accentPrimary),
            ],
            if (message.status == MessageStatus.stopped) ...[
              const SizedBox(height: 6),
              Text(
                'تولید پاسخ توسط شما متوقف شد.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: tokens.warningColor,
                    ),
              ),
            ],
            if (message.status == MessageStatus.error &&
                message.errorMessage != null) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  color: withAlphaFraction(tokens.dangerColor, 0.12),
                  border: Border.all(
                    color: withAlphaFraction(tokens.dangerColor, 0.35),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.error_outline_rounded,
                      size: 18,
                      color: tokens.dangerColor,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        message.errorMessage!,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: tokens.textPrimary,
                            ),
                      ),
                    ),
                    if (onRetryError != null)
                      TextButton(
                        onPressed: onRetryError,
                        child: const Text('تلاش مجدد'),
                      ),
                  ],
                ),
              ),
            ],
            if (message.artifacts.isNotEmpty) ...[
              const SizedBox(height: 12),
              for (final artifact in message.artifacts) ...[
                _ArtifactCard(artifact: artifact, reducedBlur: reducedBlur),
                const SizedBox(height: 8),
              ],
            ],
            if (!isStreaming && message.content.isNotEmpty) ...[
              const SizedBox(height: 8),
              Divider(
                height: 1,
                color: withAlphaFraction(tokens.textMuted, 0.14),
              ),
              const SizedBox(height: 4),
              _AssistantActionBar(
                feedback: message.feedback,
                isSpeakingTts: isSpeakingTts,
                onRegenerate: onRegenerate,
                onFeedback: onFeedback,
                onCopy: onCopy,
                onToggleTts: onToggleTts,
                onExport: onExport,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ThinkingAccordion extends StatefulWidget {
  const _ThinkingAccordion({
    required this.reasoning,
    required this.durationMs,
    required this.isThinkingOpen,
    required this.reducedBlur,
  });

  final String reasoning;
  final int durationMs;
  final bool isThinkingOpen;
  final bool reducedBlur;

  @override
  State<_ThinkingAccordion> createState() => _ThinkingAccordionState();
}

class _ThinkingAccordionState extends State<_ThinkingAccordion> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final tokens = context.orbiTokens;
    final durationLabel = PersianFormatter.formatDurationSeconds(
      Duration(milliseconds: widget.durationMs),
    );
    final headerText = widget.isThinkingOpen
        ? 'در حال تفکر... $durationLabel'
        : 'فرآیند تفکر • $durationLabel';

    return OrbiSurface(
      borderRadius: 14,
      useBackdropBlur: false,
      reducedBlur: widget.reducedBlur,
      tintOverride: tokens.accentSecondary,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      onTap: () => setState(() => _expanded = !_expanded),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(
                Icons.psychology_alt_rounded,
                size: 16,
                color: tokens.accentSecondary,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  headerText,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: tokens.textPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ),
              Icon(
                _expanded
                    ? Icons.keyboard_arrow_up_rounded
                    : Icons.keyboard_arrow_down_rounded,
                size: 18,
                color: tokens.textMuted,
              ),
            ],
          ),
          AnimatedCrossFade(
            duration: const Duration(milliseconds: 220),
            crossFadeState: _expanded
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            firstChild: const SizedBox.shrink(),
            secondChild: Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                widget.reasoning.isEmpty
                    ? 'در حال تحلیل گام‌به‌گام پرسش...'
                    : widget.reasoning,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      height: 1.65,
                      color: tokens.textSecondary,
                    ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ArtifactCard extends StatelessWidget {
  const _ArtifactCard({
    required this.artifact,
    required this.reducedBlur,
  });

  final ChatArtifactRef artifact;
  final bool reducedBlur;

  @override
  Widget build(BuildContext context) {
    final tokens = context.orbiTokens;
    return OrbiSurface(
      borderRadius: 16,
      useBackdropBlur: false,
      reducedBlur: reducedBlur,
      tintOverride: tokens.accentPrimary,
      padding: const EdgeInsets.all(12),
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => ArtifactPreviewScreen(artifact: artifact),
          ),
        );
      },
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(11),
              color: withAlphaFraction(tokens.accentPrimary, 0.22),
            ),
            alignment: Alignment.center,
            child: Text(
              artifact.extension.toUpperCase(),
              style: TextStyle(
                color: tokens.accentPrimary,
                fontWeight: FontWeight.w800,
                fontSize: 10.5,
              ),
            ),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  artifact.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontSize: 13.8),
                ),
                Text(
                  '${artifact.fileName} • ${PersianFormatter.formatFileSize(artifact.sizeBytes)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(999),
              color: withAlphaFraction(tokens.accentSecondary, 0.18),
            ),
            child: Text(
              artifact.supportsHtmlPreview ? 'پیشنمایش زنده' : 'مشاهده و دانلود',
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
                color: tokens.accentSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AssistantActionBar extends StatelessWidget {
  const _AssistantActionBar({
    required this.feedback,
    required this.isSpeakingTts,
    this.onRegenerate,
    this.onFeedback,
    this.onCopy,
    this.onToggleTts,
    this.onExport,
  });

  final MessageFeedback feedback;
  final bool isSpeakingTts;
  final VoidCallback? onRegenerate;
  final ValueChanged<MessageFeedback>? onFeedback;
  final VoidCallback? onCopy;
  final VoidCallback? onToggleTts;
  final ValueChanged<String>? onExport;

  @override
  Widget build(BuildContext context) {
    final tokens = context.orbiTokens;
    return Wrap(
      spacing: 2,
      runSpacing: 2,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        _ActionIconButton(
          icon: Icons.refresh_rounded,
          tooltip: 'بازتولید پاسخ',
          onTap: onRegenerate,
        ),
        _ActionIconButton(
          icon: feedback == MessageFeedback.like
              ? Icons.thumb_up_rounded
              : Icons.thumb_up_outlined,
          tooltip: 'پاسخ مفید بود',
          active: feedback == MessageFeedback.like,
          activeColor: tokens.successColor,
          onTap: () => onFeedback?.call(
            feedback == MessageFeedback.like
                ? MessageFeedback.none
                : MessageFeedback.like,
          ),
        ),
        _ActionIconButton(
          icon: feedback == MessageFeedback.dislike
              ? Icons.thumb_down_rounded
              : Icons.thumb_down_outlined,
          tooltip: 'نیاز به بهبود',
          active: feedback == MessageFeedback.dislike,
          activeColor: tokens.dangerColor,
          onTap: () => onFeedback?.call(
            feedback == MessageFeedback.dislike
                ? MessageFeedback.none
                : MessageFeedback.dislike,
          ),
        ),
        _ActionIconButton(
          icon: Icons.copy_rounded,
          tooltip: 'کپی متن کامل',
          onTap: onCopy,
        ),
        _ActionIconButton(
          icon: isSpeakingTts
              ? Icons.stop_circle_outlined
              : Icons.volume_up_outlined,
          tooltip: isSpeakingTts ? 'توقف خوانش' : 'خوانش صوتی',
          active: isSpeakingTts,
          activeColor: tokens.accentSecondary,
          onTap: onToggleTts,
        ),
        PopupMenuButton<String>(
          tooltip: 'خروجی فایل',
          icon: Icon(
            Icons.download_for_offline_outlined,
            size: 19,
            color: tokens.textMuted,
          ),
          onSelected: onExport,
          itemBuilder: (_) => const [
            PopupMenuItem(value: 'pdf', child: Text('خروجی PDF فارسی')),
            PopupMenuItem(value: 'md', child: Text('خروجی Markdown (.md)')),
            PopupMenuItem(value: 'txt', child: Text('خروجی متنی (.txt)')),
          ],
        ),
      ],
    );
  }
}

class _ActionIconButton extends StatelessWidget {
  const _ActionIconButton({
    required this.icon,
    required this.tooltip,
    this.onTap,
    this.active = false,
    this.activeColor,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onTap;
  final bool active;
  final Color? activeColor;

  @override
  Widget build(BuildContext context) {
    final tokens = context.orbiTokens;
    return IconButton(
      icon: AnimatedScale(
        scale: active ? 1.15 : 1.0,
        duration: const Duration(milliseconds: 180),
        child: Icon(
          icon,
          size: 18.5,
          color: active ? (activeColor ?? tokens.accentPrimary) : tokens.textMuted,
        ),
      ),
      tooltip: tooltip,
      visualDensity: VisualDensity.compact,
      onPressed: onTap,
    );
  }
}

class _ImageGridPreview extends StatelessWidget {
  const _ImageGridPreview({required this.images});

  final List<ChatAttachment> images;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final img in images)
          GestureDetector(
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => _FullscreenImageViewer(attachment: img),
                ),
              );
            },
            child: Hero(
              tag: 'img_${img.id}',
              child: ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: File(img.localPath).existsSync()
                    ? Image.file(
                        File(img.localPath),
                        width: images.length == 1 ? 210 : 108,
                        height: images.length == 1 ? 160 : 108,
                        fit: BoxFit.cover,
                      )
                    : Container(
                        width: 108,
                        height: 108,
                        color: Colors.black26,
                        child: const Icon(Icons.broken_image_outlined),
                      ),
              ),
            ),
          ),
      ],
    );
  }
}

class _FullscreenImageViewer extends StatelessWidget {
  const _FullscreenImageViewer({required this.attachment});

  final ChatAttachment attachment;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black54,
        foregroundColor: Colors.white,
        title: Text(attachment.name, style: const TextStyle(fontSize: 14)),
      ),
      body: Center(
        child: InteractiveViewer(
          minScale: 0.5,
          maxScale: 4.5,
          child: Hero(
            tag: 'img_${attachment.id}',
            child: Image.file(File(attachment.localPath)),
          ),
        ),
      ),
    );
  }
}

class _AttachmentFileChip extends StatelessWidget {
  const _AttachmentFileChip({required this.attachment});

  final ChatAttachment attachment;

  @override
  Widget build(BuildContext context) {
    final tokens = context.orbiTokens;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: withAlphaFraction(tokens.surfaceElevated, 0.85),
        border: Border.all(color: withAlphaFraction(tokens.accentPrimary, 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.description_outlined, size: 15, color: tokens.accentPrimary),
          const SizedBox(width: 6),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 180),
            child: Text(
              '${attachment.name} (${PersianFormatter.formatFileSize(attachment.sizeBytes)})',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ],
      ),
    );
  }
}

class _TypingPulseDots extends StatefulWidget {
  const _TypingPulseDots({required this.color});

  final Color color;

  @override
  State<_TypingPulseDots> createState() => _TypingPulseDotsState();
}

class _TypingPulseDotsState extends State<_TypingPulseDots>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (i) {
            final phase = ((_controller.value * 3 - i) % 3).clamp(0.0, 1.0);
            final alpha = 0.25 + (1.0 - (phase - 0.5).abs() * 2) * 0.75;
            return Container(
              width: 7,
              height: 7,
              margin: const EdgeInsets.symmetric(horizontal: 3),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: withAlphaFraction(widget.color, alpha),
              ),
            );
          }),
        );
      },
    );
  }
}
