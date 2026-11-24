import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/database/app_database.dart';
import '../../core/theme/app_theme_tokens.dart';
import '../../core/theme/theme_controller.dart';
import '../../core/utils/persian_digits.dart';
import '../../core/widgets/ambient_cosmic_background.dart';
import '../../core/widgets/surface_container.dart';
import '../chat/domain/chat_models.dart';
import 'artifact_preview_screen.dart';
import 'artifact_service.dart';

/// Library listing all generated and saved documents/code/HTML/PDF artifacts.
class ArtifactsLibraryScreen extends ConsumerStatefulWidget {
  const ArtifactsLibraryScreen({super.key});

  @override
  ConsumerState<ArtifactsLibraryScreen> createState() =>
      _ArtifactsLibraryScreenState();
}

class _ArtifactsLibraryScreenState
    extends ConsumerState<ArtifactsLibraryScreen> {
  late Future<List<ChatArtifactRef>> _future;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    _future = ref.read(appDatabaseProvider).listArtifacts();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.orbiTokens;
    final reducedBlur = ref.watch(themeSettingsProvider).reducedBlur;

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
                  reducedBlur: reducedBlur,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back_rounded),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                      const Expanded(
                        child: Text(
                          'کتابخانه فایل‌ها و اسناد',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Expanded(
                child: FutureBuilder<List<ChatArtifactRef>>(
                  future: _future,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    final items = snapshot.data ?? const [];
                    if (items.isEmpty) {
                      return Center(
                        child: Padding(
                          padding: const EdgeInsets.all(28),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.folder_special_outlined,
                                size: 54,
                                color: tokens.accentPrimary,
                              ),
                              const SizedBox(height: 14),
                              Text(
                                'هنوز فایلی ساخته نشده است',
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'در گفتگو از اوربی بخواهید فایل PDF، Markdown، HTML یا CSV بسازد تا اینجا نگهداری شود.',
                                textAlign: TextAlign.center,
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ],
                          ),
                        ),
                      );
                    }

                    return ListView.separated(
                      padding: const EdgeInsets.fromLTRB(14, 6, 14, 24),
                      itemCount: items.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        final item = items[index];
                        return OrbiSurface(
                          borderRadius: 18,
                          reducedBlur: reducedBlur,
                          padding: const EdgeInsets.all(14),
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                builder: (_) =>
                                    ArtifactPreviewScreen(artifact: item),
                              ),
                            );
                          },
                          child: Row(
                            children: [
                              Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(12),
                                  color: withAlphaFraction(
                                    tokens.accentPrimary,
                                    0.18,
                                  ),
                                ),
                                alignment: Alignment.center,
                                child: Text(
                                  item.extension.toUpperCase(),
                                  style: TextStyle(
                                    color: tokens.accentPrimary,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 11,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      item.title,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleMedium
                                          ?.copyWith(fontSize: 14.5),
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      '${PersianFormatter.formatFileSize(item.sizeBytes)} • ${PersianFormatter.formatJalaliShort(item.createdAt)}',
                                      style:
                                          Theme.of(context).textTheme.bodySmall,
                                    ),
                                  ],
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.share_rounded, size: 20),
                                onPressed: () async {
                                  final service =
                                      ref.read(artifactServiceProvider);
                                  final path = item.savedFilePath;
                                  final file = (path != null &&
                                          await File(path).exists())
                                      ? File(path)
                                      : File(
                                          (await service.persistArtifact(
                                            conversationId: 'library',
                                            messageId: 'share',
                                            artifact: item,
                                            saveToDb: false,
                                          ))
                                              .savedFilePath!,
                                        );
                                  await service.shareFile(
                                    file,
                                    subject: item.title,
                                  );
                                },
                              ),
                              IconButton(
                                icon: Icon(
                                  Icons.delete_outline_rounded,
                                  size: 20,
                                  color: tokens.dangerColor,
                                ),
                                onPressed: () async {
                                  await ref
                                      .read(appDatabaseProvider)
                                      .deleteArtifact(item.id);
                                  setState(_reload);
                                },
                              ),
                            ],
                          ),
                        );
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
  }
}
