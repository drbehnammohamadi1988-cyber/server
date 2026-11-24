import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme_tokens.dart';
import '../../../core/theme/theme_controller.dart';
import '../../../core/utils/persian_digits.dart';
import '../../../core/widgets/ambient_cosmic_background.dart';
import '../../../core/widgets/capsule_chip.dart';
import '../../../core/widgets/gradient_text.dart';
import '../../../core/widgets/surface_container.dart';
import '../../artifacts/artifact_service.dart';
import '../../composer/floating_glass_composer.dart';
import '../../gateway/domain/gateway_models.dart';
import '../../gateway/presentation/gateway_providers.dart';
import '../../history/presentation/glass_navigation_drawer.dart';
import '../../settings/settings_screen.dart';
import '../domain/chat_models.dart';
import 'chat_controller.dart';
import 'widgets/chat_message_bubble.dart';

/// Primary conversational experience with RTL Top App Bar, Dynamic Model Picker
/// Pill, Ghost Mode stealth toggle, breathing Cosmic Welcome Canvas,
/// zero-jank streaming list, and Floating Glass Composer.
class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({super.key});

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _composerController = TextEditingController();
  final FocusNode _composerFocusNode = FocusNode();

  bool _isUserScrolledUp = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _composerController.dispose();
    _composerFocusNode.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final pos = _scrollController.position;
    final distanceFromBottom = pos.maxScrollExtent - pos.pixels;
    final scrolledUp = distanceFromBottom > 120;
    if (scrolledUp != _isUserScrolledUp) {
      setState(() => _isUserScrolledUp = scrolledUp);
    }
  }

  void _scrollToBottom({bool animate = true}) {
    if (!_scrollController.hasClients) return;
    final target = _scrollController.position.maxScrollExtent;
    if (animate) {
      _scrollController.animateTo(
        target,
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOutCubic,
      );
    } else {
      _scrollController.jumpTo(target);
    }
  }

  void _openModelPickerSheet() {
    final tokens = context.orbiTokens;
    final reducedBlur = ref.read(themeSettingsProvider).reducedBlur;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        return Consumer(
          builder: (context, ref, _) {
            final gw = ref.watch(gatewayConfigProvider);
            return Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
              child: OrbiSurface(
                borderRadius: 26,
                useBackdropBlur: true,
                reducedBlur: reducedBlur,
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.of(context).size.height * 0.65,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 38,
                        height: 4,
                        decoration: BoxDecoration(
                          color: withAlphaFraction(tokens.textMuted, 0.4),
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Text(
                            'انتخاب مدل از سرور Gateway',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const Spacer(),
                          IconButton(
                            icon: gw.isSyncingModels
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(Icons.refresh_rounded, size: 20),
                            tooltip: 'به‌روزرسانی لیست مدل‌ها',
                            onPressed: gw.isSyncingModels
                                ? null
                                : () => ref
                                    .read(gatewayConfigProvider.notifier)
                                    .syncModels(),
                          ),
                        ],
                      ),
                      if (gw.modelErrorFa != null) ...[
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(14),
                            color: withAlphaFraction(tokens.dangerColor, 0.14),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.cloud_off_rounded,
                                size: 18,
                                color: tokens.dangerColor,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  gw.modelErrorFa!,
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                              ),
                              TextButton(
                                onPressed: () {
                                  Navigator.pop(ctx);
                                  Navigator.of(context).push(
                                    MaterialPageRoute<void>(
                                      builder: (_) => const SettingsScreen(),
                                    ),
                                  );
                                },
                                child: const Text('تنظیمات'),
                              ),
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: 8),
                      if (gw.models.isEmpty)
                        Padding(
                          padding: const EdgeInsets.all(24),
                          child: Text(
                            gw.isSyncingModels
                                ? 'در حال دریافت لیست مدل‌ها از Gateway...'
                                : 'مدلی یافت نشد. اتصال Gateway را در تنظیمات بررسی کنید.',
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        )
                      else
                        Flexible(
                          child: ListView.separated(
                            shrinkWrap: true,
                            itemCount: gw.models.length,
                            separatorBuilder: (_, _) =>
                                const SizedBox(height: 8),
                            itemBuilder: (context, index) {
                              final model = gw.models[index];
                              final isSelected =
                                  gw.selectedModel?.id == model.id;
                              return _ModelChoiceTile(
                                model: model,
                                selected: isSelected,
                                reducedBlur: reducedBlur,
                                onTap: () {
                                  ref
                                      .read(gatewayConfigProvider.notifier)
                                      .selectModel(model.id);
                                  Navigator.pop(ctx);
                                },
                              );
                            },
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _openEditMessageDialog(ChatMessageEntity message) async {
    final editCtrl = TextEditingController(text: message.content);
    final updated = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('ویرایش پیام و ارسال مجدد'),
        content: TextField(
          controller: editCtrl,
          minLines: 2,
          maxLines: 6,
          autofocus: true,
          decoration: const InputDecoration(
            border: OutlineInputBorder(
              borderRadius: BorderRadius.all(Radius.circular(14)),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('انصراف'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, editCtrl.text.trim()),
            child: const Text('ارسال از این نقطه'),
          ),
        ],
      ),
    );
    editCtrl.dispose();
    if (updated != null && updated.isNotEmpty) {
      await ref
          .read(chatControllerProvider.notifier)
          .editAndBranchUserMessage(message.id, updated);
    }
  }

  Future<void> _exportSingleMessage(
    ChatMessageEntity message,
    String format,
  ) async {
    try {
      final service = ref.read(artifactServiceProvider);
      final file = await service.exportTextAsFile(
        title: 'پاسخ اوربی هوش',
        content: message.content,
        format: format,
      );
      await service.shareFile(file, subject: 'پاسخ اوربی هوش');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطا در ساخت خروجی: $e')),
        );
      }
    }
  }

  void _applyStarterPrompt(String text, {bool fileMode = false}) {
    if (fileMode) {
      ref.read(chatControllerProvider.notifier).setFileBuilderMode(true);
    }
    _composerController.text = text;
    _composerController.selection = TextSelection.fromPosition(
      TextPosition(offset: text.length),
    );
    _composerFocusNode.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.orbiTokens;
    final themeState = ref.watch(themeSettingsProvider);
    final chatState = ref.watch(chatControllerProvider);
    final gatewayState = ref.watch(gatewayConfigProvider);

    ref.listen<StreamingBubbleState>(streamingBubbleProvider, (prev, next) {
      if (next.isActive && !_isUserScrolledUp) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _scrollToBottom(animate: false);
        });
      }
    });

    ref.listen<ChatSessionState>(chatControllerProvider, (prev, next) {
      if ((prev?.messages.length ?? 0) < next.messages.length &&
          !_isUserScrolledUp) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _scrollToBottom(animate: true);
        });
      }
    });

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: tokens.backgroundTop,
      drawer: const GlassNavigationDrawer(),
      body: AmbientCosmicBackground(
        isGhostMode: chatState.isGhostMode,
        child: SafeArea(
          child: Column(
            children: [
              _TopAppBar(
                reducedBlur: themeState.reducedBlur,
                isGhostMode: chatState.isGhostMode,
                selectedModel: gatewayState.selectedModel,
                isSyncingModels: gatewayState.isSyncingModels,
                onOpenDrawer: () => _scaffoldKey.currentState?.openDrawer(),
                onOpenModels: _openModelPickerSheet,
                onNewChat: () => ref
                    .read(chatControllerProvider.notifier)
                    .startNewChat(ghostMode: false),
                onToggleGhost: () =>
                    ref.read(chatControllerProvider.notifier).toggleGhostMode(),
              ),
              if (chatState.isGhostMode) _GhostModeBanner(tokens: tokens),
              Expanded(
                child: Stack(
                  children: [
                    if (chatState.messages.isEmpty && !chatState.isStreaming)
                      _WelcomeCanvas(
                        reducedBlur: themeState.reducedBlur,
                        onPickStarter: _applyStarterPrompt,
                      )
                    else
                      _ChatStreamList(
                        scrollController: _scrollController,
                        messages: chatState.messages,
                        activeSpeakingId: chatState.activeSpeakingMessageId,
                        reducedBlur: themeState.reducedBlur,
                        onRegenerate: (id) => ref
                            .read(chatControllerProvider.notifier)
                            .regenerateFromAssistant(id),
                        onFeedback: (id, fb) => ref
                            .read(chatControllerProvider.notifier)
                            .setFeedback(id, fb),
                        onCopy: (msg) async {
                          await Clipboard.setData(
                            ClipboardData(text: msg.content),
                          );
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('پاسخ در حافظه کپی شد'),
                              ),
                            );
                          }
                        },
                        onToggleTts: (msg) => ref
                            .read(chatControllerProvider.notifier)
                            .toggleTts(msg),
                        onExport: _exportSingleMessage,
                        onEditUser: _openEditMessageDialog,
                      ),
                    if (_isUserScrolledUp)
                      Positioned(
                        bottom: 10,
                        left: 0,
                        right: 0,
                        child: Center(
                          child: CapsuleChip(
                            label: 'اسکرول به پایین',
                            icon: Icons.keyboard_arrow_down_rounded,
                            reducedBlur: themeState.reducedBlur,
                            onTap: () {
                              setState(() => _isUserScrolledUp = false);
                              _scrollToBottom(animate: true);
                            },
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              FloatingGlassComposer(
                controller: _composerController,
                focusNode: _composerFocusNode,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TopAppBar extends StatelessWidget {
  const _TopAppBar({
    required this.reducedBlur,
    required this.isGhostMode,
    required this.selectedModel,
    required this.isSyncingModels,
    required this.onOpenDrawer,
    required this.onOpenModels,
    required this.onNewChat,
    required this.onToggleGhost,
  });

  final bool reducedBlur;
  final bool isGhostMode;
  final GatewayModel? selectedModel;
  final bool isSyncingModels;
  final VoidCallback onOpenDrawer;
  final VoidCallback onOpenModels;
  final VoidCallback onNewChat;
  final VoidCallback onToggleGhost;

  @override
  Widget build(BuildContext context) {
    final tokens = context.orbiTokens;
    final modelLabel = selectedModel?.displayName ??
        (isSyncingModels ? 'همگام‌سازی...' : 'انتخاب مدل');

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      child: OrbiSurface(
        borderRadius: 22,
        useBackdropBlur: true,
        reducedBlur: reducedBlur,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: Row(
          children: [
            IconButton(
              icon: const Icon(Icons.menu_rounded),
              tooltip: 'منو و تاریخچه',
              onPressed: onOpenDrawer,
            ),
            const Spacer(),
            InkWell(
              borderRadius: BorderRadius.circular(999),
              onTap: onOpenModels,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(999),
                  color: withAlphaFraction(tokens.accentPrimary, 0.14),
                  border: Border.all(
                    color: withAlphaFraction(tokens.accentPrimary, 0.28),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 20,
                      height: 20,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(colors: tokens.titleGradient),
                      ),
                      child: const Icon(
                        Icons.auto_awesome_rounded,
                        size: 12,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(width: 7),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 145),
                      child: Text(
                        modelLabel,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Icon(Icons.keyboard_arrow_down_rounded, size: 17),
                  ],
                ),
              ),
            ),
            const Spacer(),
            IconButton(
              icon: const Icon(Icons.edit_square, size: 20),
              tooltip: 'چت جدید',
              onPressed: onNewChat,
            ),
            IconButton(
              icon: Icon(
                isGhostMode
                    ? Icons.visibility_off_rounded
                    : Icons.visibility_off_outlined,
                size: 20,
                color: isGhostMode ? tokens.ghostGlowColor : tokens.textPrimary,
              ),
              tooltip: isGhostMode ? 'خروج از چت موقت' : 'چت موقت (ناشناس)',
              onPressed: onToggleGhost,
            ),
          ],
        ),
      ),
    );
  }
}

class _GhostModeBanner extends StatelessWidget {
  const _GhostModeBanner({required this.tokens});

  final OrbiThemeTokens tokens;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 4, 16, 4),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: withAlphaFraction(tokens.ghostGlowColor, 0.14),
        border: Border.all(
          color: withAlphaFraction(tokens.ghostGlowColor, 0.38),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.shield_moon_outlined,
            size: 16,
            color: tokens.ghostGlowColor,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'حالت چت موقت فعال است؛ این گفتگو ذخیره نمی‌شود و پس از بستن کاملاً پاک می‌شود.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: tokens.textPrimary,
                    fontSize: 11.5,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

class _WelcomeCanvas extends StatefulWidget {
  const _WelcomeCanvas({
    required this.reducedBlur,
    required this.onPickStarter,
  });

  final bool reducedBlur;
  final void Function(String prompt, {bool fileMode}) onPickStarter;

  @override
  State<_WelcomeCanvas> createState() => _WelcomeCanvasState();
}

class _WelcomeCanvasState extends State<_WelcomeCanvas>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2800),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.orbiTokens;
    final greeting = PersianFormatter.greetingForHour(DateTime.now().hour);

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            RepaintBoundary(
              child: AnimatedBuilder(
                animation: _pulseController,
                builder: (context, child) {
                  final scale = 0.96 + _pulseController.value * 0.08;
                  return Transform.scale(
                    scale: scale,
                    child: Container(
                      width: 78,
                      height: 78,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: tokens.titleGradient,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: withAlphaFraction(
                              tokens.accentPrimary,
                              0.26 + _pulseController.value * 0.2,
                            ),
                            blurRadius: 28 + _pulseController.value * 12,
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.auto_awesome_rounded,
                        size: 36,
                        color: Colors.white,
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 22),
            GradientText(
              greeting,
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontSize: 23,
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              'با قدرت کامل Gateway، آمادهٔ گفتگو، کدنویسی، ساخت فایل PDF/HTML و تحلیل اسناد',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 26),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              alignment: WrapAlignment.center,
              children: [
                CapsuleChip(
                  label: 'حل مسئله',
                  icon: Icons.psychology_outlined,
                  reducedBlur: widget.reducedBlur,
                  onTap: () => widget.onPickStarter(
                    'این مسئله را گام‌به‌گام و منطقی تحلیل و حل کن: ',
                  ),
                ),
                CapsuleChip(
                  label: 'تولید محتوا',
                  icon: Icons.edit_note_rounded,
                  reducedBlur: widget.reducedBlur,
                  onTap: () => widget.onPickStarter(
                    'یک متن حرفه‌ای، خلاقانه و خوش‌آهنگ فارسی دربارهٔ موضوع زیر بنویس: ',
                  ),
                ),
                CapsuleChip(
                  label: 'یادگیری',
                  icon: Icons.school_outlined,
                  reducedBlur: widget.reducedBlur,
                  onTap: () => widget.onPickStarter(
                    'مفهوم زیر را خیلی ساده، عمیق و با مثال کاربردی آموزش بده: ',
                  ),
                ),
                CapsuleChip(
                  label: 'برنامه‌نویسی',
                  icon: Icons.terminal_rounded,
                  reducedBlur: widget.reducedBlur,
                  onTap: () => widget.onPickStarter(
                    'یک کد تمیز، بهینه و بدون باگ برای نیاز زیر پیاده‌سازی کن: ',
                  ),
                ),
                CapsuleChip(
                  label: 'تحلیل تصویر',
                  icon: Icons.image_search_outlined,
                  reducedBlur: widget.reducedBlur,
                  onTap: () => widget.onPickStarter(
                    'نکات کلیدی تصویر یا متن پیوست‌شده را دقیق بررسی و خلاصه کن.',
                  ),
                ),
                CapsuleChip(
                  label: 'ساخت فایل و سند',
                  icon: Icons.description_outlined,
                  reducedBlur: widget.reducedBlur,
                  onTap: () => widget.onPickStarter(
                    'یک گزارش حرفه‌ای و ساختاریافته قابل دانلود برای موضوع زیر بساز: ',
                    fileMode: true,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ChatStreamList extends ConsumerWidget {
  const _ChatStreamList({
    required this.scrollController,
    required this.messages,
    required this.activeSpeakingId,
    required this.reducedBlur,
    required this.onRegenerate,
    required this.onFeedback,
    required this.onCopy,
    required this.onToggleTts,
    required this.onExport,
    required this.onEditUser,
  });

  final ScrollController scrollController;
  final List<ChatMessageEntity> messages;
  final String? activeSpeakingId;
  final bool reducedBlur;
  final ValueChanged<String> onRegenerate;
  final void Function(String messageId, MessageFeedback feedback) onFeedback;
  final ValueChanged<ChatMessageEntity> onCopy;
  final ValueChanged<ChatMessageEntity> onToggleTts;
  final void Function(ChatMessageEntity message, String format) onExport;
  final ValueChanged<ChatMessageEntity> onEditUser;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hasStreaming = ref.watch(
      streamingBubbleProvider.select((s) => s.isActive),
    );
    final totalCount = messages.length + (hasStreaming ? 1 : 0);

    return ListView.builder(
      controller: scrollController,
      padding: const EdgeInsets.fromLTRB(10, 6, 10, 18),
      itemCount: totalCount,
      itemBuilder: (context, index) {
        if (hasStreaming && index == totalCount - 1) {
          // Only this single bottom item rebuilds on every token delta!
          return Consumer(
            builder: (context, ref, _) {
              final streamState = ref.watch(streamingBubbleProvider);
              final msg = streamState.message;
              if (msg == null) return const SizedBox.shrink();
              return ChatMessageBubble(
                key: ValueKey('stream_${msg.id}'),
                message: msg,
                reducedBlur: reducedBlur,
                isSpeakingTts: false,
                isThinkingOpen: streamState.isThinkingOpen,
              );
            },
          );
        }

        final msg = messages[index];
        return ChatMessageBubble(
          key: ValueKey('msg_${msg.id}'),
          message: msg,
          reducedBlur: reducedBlur,
          isSpeakingTts: activeSpeakingId == msg.id,
          onRegenerate:
              msg.role == ChatRole.assistant ? () => onRegenerate(msg.id) : null,
          onFeedback: msg.role == ChatRole.assistant
              ? (fb) => onFeedback(msg.id, fb)
              : null,
          onCopy: () => onCopy(msg),
          onToggleTts: () => onToggleTts(msg),
          onExport: (fmt) => onExport(msg, fmt),
          onEditUserMessage:
              msg.role == ChatRole.user ? () => onEditUser(msg) : null,
          onRetryError: msg.status == MessageStatus.error
              ? () => onRegenerate(msg.id)
              : null,
        );
      },
    );
  }
}

class _ModelChoiceTile extends StatelessWidget {
  const _ModelChoiceTile({
    required this.model,
    required this.selected,
    required this.reducedBlur,
    required this.onTap,
  });

  final GatewayModel model;
  final bool selected;
  final bool reducedBlur;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = context.orbiTokens;
    return OrbiSurface(
      borderRadius: 16,
      useBackdropBlur: false,
      reducedBlur: reducedBlur,
      tintOverride: selected ? tokens.accentPrimary : null,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      onTap: onTap,
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  model.displayName,
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontSize: 14.5),
                ),
                const SizedBox(height: 5),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    for (final tag in model.capabilityLabelsFa)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(999),
                          color: withAlphaFraction(tokens.accentSecondary, 0.14),
                        ),
                        child: Text(
                          tag,
                          style: TextStyle(
                            fontSize: 10.5,
                            color: tokens.accentSecondary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
          if (selected)
            Icon(
              Icons.check_circle_rounded,
              color: tokens.accentPrimary,
              size: 22,
            ),
        ],
      ),
    );
  }
}
