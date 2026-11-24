import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/database/app_database.dart';
import '../../core/theme/app_theme_mode.dart';
import '../../core/theme/app_theme_tokens.dart';
import '../../core/theme/theme_controller.dart';
import '../../core/utils/persian_digits.dart';
import '../../core/widgets/ambient_cosmic_background.dart';
import '../../core/widgets/gradient_text.dart';
import '../../core/widgets/surface_container.dart';
import '../gateway/domain/gateway_models.dart';
import '../gateway/presentation/gateway_providers.dart';
import '../history/presentation/history_providers.dart';

/// Settings screen covering live 5-theme switching, Reduced Blur ultra-light
/// mode, Gateway URL/API-key management, Latency Ping, Model Sync, AI tuning,
/// and JSON backup/restore.
class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  late final TextEditingController _urlController;
  late final TextEditingController _apiKeyController;
  late final TextEditingController _systemPromptController;

  bool _showApiKey = false;
  bool _isTestingHealth = false;
  HealthCheckResult? _healthResult;

  @override
  void initState() {
    super.initState();
    final gw = ref.read(gatewayConfigProvider);
    _urlController = TextEditingController(text: gw.baseUrl);
    _apiKeyController = TextEditingController();
    _systemPromptController = TextEditingController(text: gw.systemPrompt);
    _healthResult = gw.lastHealth;
    _loadMaskedKey();
  }

  Future<void> _loadMaskedKey() async {
    final key = await ref.read(secureStorageProvider).readGatewayApiKey();
    if (mounted && key != null) {
      _apiKeyController.text = key;
    }
  }

  @override
  void dispose() {
    _urlController.dispose();
    _apiKeyController.dispose();
    _systemPromptController.dispose();
    super.dispose();
  }

  Future<void> _saveGatewayAndTest() async {
    setState(() => _isTestingHealth = true);
    final notifier = ref.read(gatewayConfigProvider.notifier);
    await notifier.updateBaseUrl(_urlController.text);
    await notifier.updateApiKey(_apiKeyController.text);
    final res = await notifier.runHealthCheck();
    if (mounted) {
      setState(() {
        _healthResult = res;
        _isTestingHealth = false;
      });
    }
  }

  Future<void> _exportBackup() async {
    final jsonStr = await ref.read(appDatabaseProvider).exportBackupJson();
    final dir = await getTemporaryDirectory();
    final file = File(
      p.join(
        dir.path,
        'orbi_backup_${DateTime.now().millisecondsSinceEpoch}.json',
      ),
    );
    await file.writeAsString(jsonStr, flush: true);
    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(file.path)],
        subject: 'پشتیبان تاریخچه گفتگوهای اوربی',
      ),
    );
  }

  Future<void> _importBackup() async {
    final picked = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['json'],
    );
    if (picked.isEmpty || picked.first.path == null) return;
    try {
      final raw = await File(picked.first.path!).readAsString();
      // Validate JSON before transaction
      jsonDecode(raw);
      final count = await ref.read(appDatabaseProvider).importBackupJson(raw);
      ref.invalidate(conversationsHistoryProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'بازیابی موفق: ${PersianFormatter.toPersianDigits(count.toString())} گفتگو وارد شد.',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطا در بازیابی فایل پشتیبان: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.orbiTokens;
    final themeState = ref.watch(themeSettingsProvider);
    final gatewayState = ref.watch(gatewayConfigProvider);

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
                  reducedBlur: themeState.reducedBlur,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back_rounded),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                      const Expanded(
                        child: GradientText(
                          'تنظیمات و شخصی‌سازی',
                          textAlign: TextAlign.start,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(14, 6, 14, 28),
                  children: [
                    const _SectionTitle('انتخاب تم و هویت بصری زنده'),
                    const SizedBox(height: 10),
                    SizedBox(
                      height: 132,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: AppThemePreset.values.length,
                        separatorBuilder: (_, _) => const SizedBox(width: 10),
                        itemBuilder: (context, index) {
                          final preset = AppThemePreset.values[index];
                          final preview = OrbiThemeTokens.forPreset(preset);
                          final selected = themeState.preset == preset;
                          return _ThemePreviewCard(
                            preset: preset,
                            previewTokens: preview,
                            selected: selected,
                            onTap: () => ref
                                .read(themeSettingsProvider.notifier)
                                .setPreset(preset),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 14),
                    OrbiSurface(
                      borderRadius: 20,
                      reducedBlur: themeState.reducedBlur,
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        children: [
                          SwitchListTile(
                            contentPadding: EdgeInsets.zero,
                            title: const Text(
                              'حالت فوق‌سبک (بهینه‌سازی گرافیکی)',
                              style: TextStyle(fontWeight: FontWeight.w600),
                            ),
                            subtitle: const Text(
                              'غیرفعال‌سازی Blur زنده برای حداکثر سرعت و مصرف کمتر باتری',
                            ),
                            value: themeState.reducedBlur,
                            onChanged: (v) => ref
                                .read(themeSettingsProvider.notifier)
                                .setReducedBlur(v),
                          ),
                          SwitchListTile(
                            contentPadding: EdgeInsets.zero,
                            title: const Text(
                              'بازخورد لمسی (Haptics)',
                              style: TextStyle(fontWeight: FontWeight.w600),
                            ),
                            value: themeState.hapticsEnabled,
                            onChanged: (v) => ref
                                .read(themeSettingsProvider.notifier)
                                .setHapticsEnabled(v),
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              const Text('اندازه فونت متن:'),
                              const Spacer(),
                              Text(
                                PersianFormatter.toPersianDigits(
                                  '${(themeState.fontScale * 100).round()}٪',
                                ),
                                style: TextStyle(
                                  color: tokens.accentPrimary,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                          Slider(
                            min: 0.85,
                            max: 1.25,
                            divisions: 8,
                            value: themeState.fontScale,
                            onChanged: (v) => ref
                                .read(themeSettingsProvider.notifier)
                                .setFontScale(v),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    const _SectionTitle('اتصال به هسته سرور Gateway'),
                    const SizedBox(height: 10),
                    OrbiSurface(
                      borderRadius: 20,
                      reducedBlur: themeState.reducedBlur,
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          TextField(
                            controller: _urlController,
                            textDirection: TextDirection.ltr,
                            decoration: const InputDecoration(
                              labelText: 'آدرس Base URL سرور Gateway',
                              hintText: 'http://10.0.2.2:8080',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.all(
                                  Radius.circular(14),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            children: [
                              ActionChip(
                                label: const Text('امولاتور (10.0.2.2:8080)'),
                                onPressed: () {
                                  _urlController.text = 'http://10.0.2.2:8080';
                                },
                              ),
                              ActionChip(
                                label: const Text('لوکال / ADB (127.0.0.1:8080)'),
                                onPressed: () {
                                  _urlController.text = 'http://127.0.0.1:8080';
                                },
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: _apiKeyController,
                            obscureText: !_showApiKey,
                            textDirection: TextDirection.ltr,
                            decoration: InputDecoration(
                              labelText: 'کلید دسترسی / توکن (اختیاری در توسعه)',
                              hintText: 'Bearer API Key',
                              border: const OutlineInputBorder(
                                borderRadius: BorderRadius.all(
                                  Radius.circular(14),
                                ),
                              ),
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _showApiKey
                                      ? Icons.visibility_off_outlined
                                      : Icons.visibility_outlined,
                                ),
                                onPressed: () =>
                                    setState(() => _showApiKey = !_showApiKey),
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: FilledButton.icon(
                                  onPressed: _isTestingHealth
                                      ? null
                                      : _saveGatewayAndTest,
                                  icon: _isTestingHealth
                                      ? const SizedBox(
                                          width: 15,
                                          height: 15,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: Colors.white,
                                          ),
                                        )
                                      : const Icon(
                                          Icons.network_check_rounded,
                                          size: 18,
                                        ),
                                  label: const Text('تست اتصال و سنجش پینگ'),
                                ),
                              ),
                              const SizedBox(width: 8),
                              OutlinedButton.icon(
                                onPressed: gatewayState.isSyncingModels
                                    ? null
                                    : () => ref
                                        .read(gatewayConfigProvider.notifier)
                                        .syncModels(),
                                icon: const Icon(Icons.sync_rounded, size: 18),
                                label: const Text('همگام‌سازی'),
                              ),
                            ],
                          ),
                          if (_healthResult != null) ...[
                            const SizedBox(height: 10),
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(12),
                                color: withAlphaFraction(
                                  _healthResult!.isHealthy
                                      ? tokens.successColor
                                      : tokens.dangerColor,
                                  0.14,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    _healthResult!.isHealthy
                                        ? Icons.check_circle_rounded
                                        : Icons.warning_amber_rounded,
                                    color: _healthResult!.isHealthy
                                        ? tokens.successColor
                                        : tokens.dangerColor,
                                    size: 18,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      _healthResult!.summaryFa,
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall
                                          ?.copyWith(color: tokens.textPrimary),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                          const SizedBox(height: 6),
                          SwitchListTile(
                            contentPadding: EdgeInsets.zero,
                            title: const Text('ارسال تصاویر در قالب Vision'),
                            subtitle: const Text(
                              'در صورت پشتیبانی Gateway از فرمت چندرسانه‌ای OpenAI فعال شود (در سرور متنی fallback خودکار دارد)',
                            ),
                            value: gatewayState.multimodalVision,
                            onChanged: (v) => ref
                                .read(gatewayConfigProvider.notifier)
                                .setMultimodalVision(v),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    const _SectionTitle('تنظیمات پیشرفته هوش مصنوعی و پشتیبان'),
                    const SizedBox(height: 10),
                    OrbiSurface(
                      borderRadius: 20,
                      reducedBlur: themeState.reducedBlur,
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          TextField(
                            controller: _systemPromptController,
                            minLines: 2,
                            maxLines: 5,
                            decoration: const InputDecoration(
                              labelText: 'پرامپت سیستم سفارشی (System Prompt)',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.all(
                                  Radius.circular(14),
                                ),
                              ),
                            ),
                            onChanged: (value) => ref
                                .read(gatewayConfigProvider.notifier)
                                .updateSystemPrompt(value),
                          ),
                          const SizedBox(height: 14),
                          Row(
                            children: [
                              const Text('خلاقیت پاسخ (Temperature):'),
                              const Spacer(),
                              Text(
                                PersianFormatter.toPersianDigits(
                                  gatewayState.temperature.toStringAsFixed(2),
                                ),
                                style: TextStyle(
                                  color: tokens.accentPrimary,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                          Slider(
                            min: 0.0,
                            max: 2.0,
                            divisions: 20,
                            value: gatewayState.temperature,
                            onChanged: (v) => ref
                                .read(gatewayConfigProvider.notifier)
                                .updateTemperature(v),
                          ),
                          Row(
                            children: [
                              const Text('حداکثر توکن پاسخ:'),
                              const Spacer(),
                              Text(
                                PersianFormatter.toPersianDigits(
                                  gatewayState.maxTokens.toString(),
                                ),
                                style: TextStyle(
                                  color: tokens.accentPrimary,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                          Slider(
                            min: 256,
                            max: 8192,
                            divisions: 31,
                            value: gatewayState.maxTokens.toDouble().clamp(256, 8192),
                            onChanged: (v) => ref
                                .read(gatewayConfigProvider.notifier)
                                .updateMaxTokens(v.round()),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: _exportBackup,
                                  icon: const Icon(
                                    Icons.upload_file_rounded,
                                    size: 18,
                                  ),
                                  label: const Text('پشتیبان‌گیری JSON'),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: _importBackup,
                                  icon: const Icon(
                                    Icons.restore_rounded,
                                    size: 18,
                                  ),
                                  label: const Text('بازیابی تاریخچه'),
                                ),
                              ),
                            ],
                          ),
                        ],
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
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
          ),
    );
  }
}

class _ThemePreviewCard extends StatelessWidget {
  const _ThemePreviewCard({
    required this.preset,
    required this.previewTokens,
    required this.selected,
    required this.onTap,
  });

  final AppThemePreset preset;
  final OrbiThemeTokens previewTokens;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final activeTokens = context.orbiTokens;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        width: 146,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              previewTokens.backgroundTop,
              previewTokens.surfaceElevated,
            ],
          ),
          border: Border.all(
            color: selected
                ? activeTokens.accentPrimary
                : previewTokens.strokeTopLeft,
            width: selected ? 2.2 : 1.0,
          ),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: withAlphaFraction(activeTokens.accentPrimary, 0.35),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ]
              : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 18,
                  height: 18,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: previewTokens.titleGradient,
                    ),
                  ),
                ),
                const Spacer(),
                if (selected)
                  Icon(
                    Icons.check_circle_rounded,
                    size: 18,
                    color: activeTokens.accentPrimary,
                  ),
              ],
            ),
            const Spacer(),
            Text(
              preset.labelFa,
              style: TextStyle(
                color: previewTokens.textPrimary,
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              preset.subtitleFa,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: previewTokens.textMuted,
                fontSize: 9.8,
                height: 1.3,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
