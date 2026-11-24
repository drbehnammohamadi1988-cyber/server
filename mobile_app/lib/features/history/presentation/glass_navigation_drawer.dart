import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../core/theme/app_theme_tokens.dart';
import '../../../core/theme/theme_controller.dart';
import '../../../core/utils/persian_digits.dart';
import '../../../core/widgets/gradient_text.dart';
import '../../../core/widgets/surface_container.dart';
import '../../artifacts/artifact_service.dart';
import '../../artifacts/artifacts_library_screen.dart';
import '../../chat/domain/chat_models.dart';
import '../../chat/presentation/chat_controller.dart';
import '../../image_studio/image_studio_screen.dart';
import '../../settings/settings_screen.dart';
import 'history_providers.dart';

/// Right-to-left Glass Navigation Drawer with instant full-text search, pinned
/// conversations, Jalali date grouping, and quick studio/library/settings links.
class GlassNavigationDrawer extends ConsumerStatefulWidget {
  const GlassNavigationDrawer({super.key});

  @override
  ConsumerState<GlassNavigationDrawer> createState() =>
      _GlassNavigationDrawerState();
}

class _GlassNavigationDrawerState
    extends ConsumerState<GlassNavigationDrawer> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.orbiTokens;
    final reducedBlur = ref.watch(themeSettingsProvider).reducedBlur;
    final activeConvId = ref.watch(chatControllerProvider).conversationId;
    final historyAsync = ref.watch(conversationsHistoryProvider);

    return Drawer(
      width: MediaQuery.of(context).size.width * 0.84,
      backgroundColor: Colors.transparent,
      elevation: 0,
      child: OrbiSurface(
        borderRadius: 0,
        useBackdropBlur: true,
        reducedBlur: reducedBlur,
        padding: EdgeInsets.zero,
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
                child: Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(colors: tokens.titleGradient),
                      ),
                      child: const Icon(
                        Icons.auto_awesome_rounded,
                        color: Colors.white,
                        size: 18,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: GradientText(
                        'اوربی هوش',
                        textAlign: TextAlign.start,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, size: 20),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: OrbiSurface(
                  borderRadius: 16,
                  useBackdropBlur: false,
                  reducedBlur: reducedBlur,
                  concave: tokens.isNeumorphic,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 4,
                  ),
                  child: TextField(
                    controller: _searchController,
                    onChanged: (value) {
                      ref.read(historySearchQueryProvider.notifier).state =
                          value;
                    },
                    decoration: InputDecoration(
                      border: InputBorder.none,
                      isDense: true,
                      hintText: 'جستجو در عنوان و متن گفتگوها...',
                      hintStyle: Theme.of(context).textTheme.bodySmall,
                      icon: Icon(
                        Icons.search_rounded,
                        size: 19,
                        color: tokens.textMuted,
                      ),
                      suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear_rounded, size: 17),
                              onPressed: () {
                                _searchController.clear();
                                ref
                                    .read(historySearchQueryProvider.notifier)
                                    .state = '';
                                setState(() {});
                              },
                            )
                          : null,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _QuickDrawerTile(
                      icon: Icons.edit_square,
                      label: 'چت جدید',
                      onTap: () {
                        Navigator.of(context).pop();
                        ref
                            .read(chatControllerProvider.notifier)
                            .startNewChat();
                      },
                    ),
                    _QuickDrawerTile(
                      icon: Icons.brush_outlined,
                      label: 'استودیو تصویر',
                      onTap: () {
                        Navigator.of(context).pop();
                        Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => const ImageStudioScreen(),
                          ),
                        );
                      },
                    ),
                    _QuickDrawerTile(
                      icon: Icons.folder_copy_outlined,
                      label: 'کتابخانه فایل‌ها',
                      onTap: () {
                        Navigator.of(context).pop();
                        Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => const ArtifactsLibraryScreen(),
                          ),
                        );
                      },
                    ),
                    _QuickDrawerTile(
                      icon: Icons.tune_rounded,
                      label: 'تنظیمات',
                      onTap: () {
                        Navigator.of(context).pop();
                        Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => const SettingsScreen(),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Divider(
                height: 1,
                color: withAlphaFraction(tokens.textMuted, 0.16),
              ),
              Expanded(
                child: historyAsync.when(
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (err, _) => Center(
                    child: Text(
                      'خطا در بارگذاری تاریخچه',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                  data: (conversations) {
                    if (conversations.isEmpty) {
                      return Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Text(
                            'هنوز گفتگویی ذخیره نشده است.',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ),
                      );
                    }
                    return _GroupedHistoryList(
                      conversations: conversations,
                      activeConvId: activeConvId,
                      reducedBlur: reducedBlur,
                      onSelect: (conv) {
                        Navigator.of(context).pop();
                        ref
                            .read(chatControllerProvider.notifier)
                            .loadConversation(conv.id);
                      },
                      onDelete: (conv) => _deleteConversation(conv),
                      onActionMenu: (conv) => _showConvMenu(conv),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _deleteConversation(ChatConversation conv) async {
    await ref.read(appDatabaseProvider).deleteConversation(conv.id);
    if (ref.read(chatControllerProvider).conversationId == conv.id) {
      await ref.read(chatControllerProvider.notifier).startNewChat();
    }
    ref.invalidate(conversationsHistoryProvider);
  }

  Future<void> _showConvMenu(ChatConversation conv) async {
    final tokens = context.orbiTokens;
    final reducedBlur = ref.read(themeSettingsProvider).reducedBlur;

    await showModalBottomSheet<void>(
      context: context,
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
          child: OrbiSurface(
            borderRadius: 24,
            useBackdropBlur: true,
            reducedBlur: reducedBlur,
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: Icon(
                    conv.isPinned
                        ? Icons.push_pin_outlined
                        : Icons.push_pin_rounded,
                    color: tokens.accentPrimary,
                  ),
                  title: Text(conv.isPinned ? 'برداشتن پین' : 'پین کردن گفتگو'),
                  onTap: () async {
                    Navigator.pop(ctx);
                    await ref.read(appDatabaseProvider).upsertConversation(
                          conv.copyWith(isPinned: !conv.isPinned),
                        );
                    ref.invalidate(conversationsHistoryProvider);
                  },
                ),
                ListTile(
                  leading: Icon(Icons.edit_outlined, color: tokens.accentSecondary),
                  title: const Text('تغییر نام گفتگو'),
                  onTap: () {
                    Navigator.pop(ctx);
                    _renameConversation(conv);
                  },
                ),
                ListTile(
                  leading: Icon(Icons.ios_share_rounded, color: tokens.textPrimary),
                  title: const Text('خروجی گرفتن از گفتگو (PDF / MD)'),
                  onTap: () {
                    Navigator.pop(ctx);
                    _exportConversation(conv);
                  },
                ),
                ListTile(
                  leading: Icon(
                    Icons.delete_outline_rounded,
                    color: tokens.dangerColor,
                  ),
                  title: Text(
                    'حذف گفتگو',
                    style: TextStyle(color: tokens.dangerColor),
                  ),
                  onTap: () {
                    Navigator.pop(ctx);
                    _deleteConversation(conv);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _renameConversation(ChatConversation conv) async {
    final controller = TextEditingController(text: conv.title);
    final updated = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('تغییر نام گفتگو'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'عنوان جدید گفتگو'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('انصراف'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: const Text('ذخیره'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (updated == null || updated.isEmpty) return;

    await ref.read(appDatabaseProvider).upsertConversation(
          conv.copyWith(title: updated),
        );
    ref.invalidate(conversationsHistoryProvider);
  }

  Future<void> _exportConversation(ChatConversation conv) async {
    final msgs = await ref.read(appDatabaseProvider).getMessages(conv.id);
    final mdBuffer = StringBuffer('# ${conv.title}\n\n');
    for (final m in msgs) {
      final speaker = m.role == ChatRole.user ? 'کاربر' : 'اوربی';
      mdBuffer.writeln('## $speaker\n\n${m.content}\n');
    }

    if (!mounted) return;
    final choice = await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(14),
        child: OrbiSurface(
          borderRadius: 22,
          useBackdropBlur: true,
          padding: const EdgeInsets.all(10),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.picture_as_pdf_rounded),
                title: const Text('خروجی PDF فارسی'),
                onTap: () => Navigator.pop(ctx, 'pdf'),
              ),
              ListTile(
                leading: const Icon(Icons.description_outlined),
                title: const Text('خروجی Markdown (.md)'),
                onTap: () => Navigator.pop(ctx, 'md'),
              ),
              ListTile(
                leading: const Icon(Icons.data_object_rounded),
                title: const Text('خروجی JSON'),
                onTap: () => Navigator.pop(ctx, 'json'),
              ),
            ],
          ),
        ),
      ),
    );
    if (choice == null) return;

    final service = ref.read(artifactServiceProvider);
    final content = choice == 'json'
        ? const JsonEncoder.withIndent('  ').convert({
            'conversation': conv.toMap(),
            'messages': [for (final m in msgs) m.toMap()],
          })
        : mdBuffer.toString();

    final file = await service.exportTextAsFile(
      title: conv.title,
      content: content,
      format: choice == 'json' ? 'txt' : choice,
    );
    await service.shareFile(file, subject: conv.title);
  }
}

class _QuickDrawerTile extends StatelessWidget {
  const _QuickDrawerTile({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = context.orbiTokens;
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          color: withAlphaFraction(tokens.accentPrimary, 0.12),
          border: Border.all(
            color: withAlphaFraction(tokens.accentPrimary, 0.22),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: tokens.accentPrimary),
            const SizedBox(width: 6),
            Text(
              label,
              style: const TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GroupedHistoryList extends StatelessWidget {
  const _GroupedHistoryList({
    required this.conversations,
    required this.activeConvId,
    required this.reducedBlur,
    required this.onSelect,
    required this.onDelete,
    required this.onActionMenu,
  });

  final List<ChatConversation> conversations;
  final String? activeConvId;
  final bool reducedBlur;
  final ValueChanged<ChatConversation> onSelect;
  final ValueChanged<ChatConversation> onDelete;
  final ValueChanged<ChatConversation> onActionMenu;

  @override
  Widget build(BuildContext context) {
    final pinned = conversations.where((c) => c.isPinned).toList();
    final regular = conversations.where((c) => !c.isPinned).toList();

    final buckets = <String, List<ChatConversation>>{};
    for (final c in regular) {
      final label = PersianFormatter.historyBucketLabel(c.updatedAt);
      buckets.putIfAbsent(label, () => []).add(c);
    }

    final entries = <Widget>[];
    if (pinned.isNotEmpty) {
      entries.add(const _BucketHeader(title: 'گفتگوهای پین‌شده'));
      for (final c in pinned) {
        entries.add(_buildRow(context, c));
      }
    }
    for (final entry in buckets.entries) {
      entries.add(_BucketHeader(title: entry.key));
      for (final c in entry.value) {
        entries.add(_buildRow(context, c));
      }
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
      children: entries,
    );
  }

  Widget _buildRow(BuildContext context, ChatConversation conv) {
    final tokens = context.orbiTokens;
    final selected = conv.id == activeConvId;

    return Dismissible(
      key: ValueKey('hist_${conv.id}'),
      direction: DismissDirection.endToStart,
      background: Container(
        margin: const EdgeInsets.symmetric(vertical: 3),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          color: withAlphaFraction(tokens.dangerColor, 0.25),
        ),
        alignment: Alignment.centerLeft,
        child: Icon(Icons.delete_outline_rounded, color: tokens.dangerColor),
      ),
      onDismissed: (_) => onDelete(conv),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: OrbiSurface(
          borderRadius: 14,
          useBackdropBlur: false,
          reducedBlur: reducedBlur,
          tintOverride: selected ? tokens.accentPrimary : null,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          onTap: () => onSelect(conv),
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onLongPress: () => onActionMenu(conv),
            child: Row(
              children: [
                if (conv.isPinned) ...[
                  Icon(
                    Icons.push_pin_rounded,
                    size: 14,
                    color: tokens.accentPrimary,
                  ),
                  const SizedBox(width: 6),
                ],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        conv.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight:
                              selected ? FontWeight.w700 : FontWeight.w500,
                          color: tokens.textPrimary,
                        ),
                      ),
                      if (conv.lastPreview.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          conv.lastPreview,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(fontSize: 11.5),
                        ),
                      ],
                    ],
                  ),
                ),
                IconButton(
                  icon: Icon(
                    Icons.more_horiz_rounded,
                    size: 18,
                    color: tokens.textMuted,
                  ),
                  visualDensity: VisualDensity.compact,
                  onPressed: () => onActionMenu(conv),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _BucketHeader extends StatelessWidget {
  const _BucketHeader({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    final tokens = context.orbiTokens;
    return Padding(
      padding: const EdgeInsets.fromLTRB(6, 12, 6, 4),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.w700,
          color: tokens.accentPrimary,
        ),
      ),
    );
  }
}
