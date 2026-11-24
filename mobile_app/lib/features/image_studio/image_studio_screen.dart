import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:gal/gal.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/network/gateway_error.dart';
import '../../core/theme/app_theme_tokens.dart';
import '../../core/theme/theme_controller.dart';
import '../../core/widgets/ambient_cosmic_background.dart';
import '../../core/widgets/gradient_text.dart';
import '../../core/widgets/surface_container.dart';
import '../gateway/domain/gateway_models.dart';
import '../gateway/presentation/gateway_providers.dart';

class _StylePreset {
  const _StylePreset({
    required this.title,
    required this.subtitle,
    required this.colors,
    required this.icon,
  });

  final String title;
  final String subtitle;
  final List<Color> colors;
  final IconData icon;
}

/// Creative Image Studio featuring 3D-tilted preset style cards, aspect ratio
/// controls, AI Prompt Enhancer via `gateway`, and Gallery export + Sharing.
class ImageStudioScreen extends ConsumerStatefulWidget {
  const ImageStudioScreen({super.key});

  @override
  ConsumerState<ImageStudioScreen> createState() => _ImageStudioScreenState();
}

class _ImageStudioScreenState extends ConsumerState<ImageStudioScreen> {
  static const _styles = <_StylePreset>[
    _StylePreset(
      title: 'سیاه و سفید',
      subtitle: 'کنتراست کلاسیک هنری',
      colors: [Color(0xFF1F2937), Color(0xFF9CA3AF)],
      icon: Icons.contrast_rounded,
    ),
    _StylePreset(
      title: 'تصویر محصول',
      subtitle: 'نورپردازی تبلیغاتی استودیویی',
      colors: [Color(0xFF2563EB), Color(0xFF60A5FA)],
      icon: Icons.inventory_2_outlined,
    ),
    _StylePreset(
      title: 'چهرهی بینقص',
      subtitle: 'پرتره سینمایی با عمق میدان',
      colors: [Color(0xFF7C3AED), Color(0xFFC084FC)],
      icon: Icons.face_retouching_natural_rounded,
    ),
    _StylePreset(
      title: 'سینمایی',
      subtitle: 'کادربندی فیلم و رنگ‌پردازی تئاتری',
      colors: [Color(0xFF0F172A), Color(0xFFF59E0B)],
      icon: Icons.movie_filter_outlined,
    ),
    _StylePreset(
      title: 'سهبعدی',
      subtitle: 'رندر سه‌بعدی مدرن و براق',
      colors: [Color(0xFF4F46E5), Color(0xFF22D3EE)],
      icon: Icons.view_in_ar_rounded,
    ),
    _StylePreset(
      title: 'انیمه',
      subtitle: 'تصویرسازی انیمه پرانرژی',
      colors: [Color(0xFFEC4899), Color(0xFF8B5CF6)],
      icon: Icons.auto_awesome_mosaic_outlined,
    ),
    _StylePreset(
      title: 'مینیمال',
      subtitle: 'ساده، تمیز و هندسی',
      colors: [Color(0xFF059669), Color(0xFF34D399)],
      icon: Icons.crop_square_rounded,
    ),
  ];

  static const _aspects = ['1:1', '16:9', '9:16', '4:5'];

  final TextEditingController _promptController = TextEditingController();
  final GlobalKey _renderKey = GlobalKey();

  int _selectedStyleIndex = 2;
  String _aspectRatio = '1:1';
  bool _isEnhancing = false;
  bool _isGenerating = false;
  StudioVisualResult? _result;
  String? _errorText;

  @override
  void dispose() {
    _promptController.dispose();
    super.dispose();
  }

  Future<void> _enhancePrompt() async {
    final raw = _promptController.text.trim();
    if (raw.isEmpty || _isEnhancing) return;

    final modelId = ref.read(gatewayConfigProvider).selectedModel?.id;
    if (modelId == null) {
      _showSnack('لطفاً ابتدا مدل فعال را در تنظیمات Gateway همگام‌سازی کنید.');
      return;
    }

    setState(() {
      _isEnhancing = true;
      _errorText = null;
    });
    try {
      final enhanced =
          await ref.read(gatewayRepositoryProvider).enhanceImagePrompt(
                baseUrl: ref.read(gatewayConfigProvider).baseUrl,
                model: modelId,
                prompt: raw,
                styleName: _styles[_selectedStyleIndex].title,
                aspectRatio: _aspectRatio,
              );
      if (mounted) {
        _promptController.text = enhanced;
      }
    } on GatewayException catch (e) {
      if (mounted) setState(() => _errorText = e.messageFa);
    } finally {
      if (mounted) setState(() => _isEnhancing = false);
    }
  }

  Future<void> _generate() async {
    final prompt = _promptController.text.trim();
    if (prompt.isEmpty || _isGenerating) return;

    final gateway = ref.read(gatewayConfigProvider);
    final modelId = gateway.selectedModel?.id;
    if (modelId == null) {
      _showSnack('مدل فعالی از Gateway یافت نشد.');
      return;
    }

    setState(() {
      _isGenerating = true;
      _errorText = null;
    });

    try {
      final res = await ref.read(gatewayRepositoryProvider).generateVisual(
            baseUrl: gateway.baseUrl,
            model: modelId,
            prompt: prompt,
            styleName: _styles[_selectedStyleIndex].title,
            aspectRatio: _aspectRatio,
          );
      if (mounted) {
        setState(() => _result = res);
      }
    } on GatewayException catch (e) {
      if (mounted) setState(() => _errorText = e.messageFa);
    } catch (e) {
      if (mounted) setState(() => _errorText = 'خطا در تولید تصویر: $e');
    } finally {
      if (mounted) setState(() => _isGenerating = false);
    }
  }

  Future<Uint8List?> _capturePngBytes() async {
    if (_result?.rasterBytes != null) {
      return _result!.rasterBytes!;
    }
    final ctx = _renderKey.currentContext;
    if (ctx == null) return null;
    final boundary = ctx.findRenderObject() as RenderRepaintBoundary?;
    if (boundary == null) return null;
    final image = await boundary.toImage(pixelRatio: 3.0);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    return byteData?.buffer.asUint8List();
  }

  Future<void> _saveToGallery() async {
    final bytes = await _capturePngBytes();
    if (bytes == null) return;
    final granted = await Gal.requestPermission();
    if (!granted) {
      _showSnack('دسترسی ذخیره در گالری داده نشد.');
      return;
    }
    await Gal.putImageBytes(
      bytes,
      name: 'orbi_studio_${DateTime.now().millisecondsSinceEpoch}',
    );
    _showSnack('تصویر با کیفیت بالا در گالری ذخیره شد.');
  }

  Future<void> _shareImage() async {
    final bytes = await _capturePngBytes();
    if (bytes == null) return;
    final dir = await getTemporaryDirectory();
    final file = File(
      p.join(dir.path, 'orbi_art_${DateTime.now().millisecondsSinceEpoch}.png'),
    );
    await file.writeAsBytes(bytes, flush: true);
    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(file.path)],
        subject: 'اثر هنری اوربی هوش',
      ),
    );
  }

  void _showSnack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
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
                          'استودیو تصویر اوربی',
                          textAlign: TextAlign.start,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(14, 6, 14, 24),
                  children: [
                    Text(
                      'انتخاب استایل هنری',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      height: 132,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: _styles.length,
                        separatorBuilder: (_, _) => const SizedBox(width: 10),
                        itemBuilder: (context, index) {
                          final item = _styles[index];
                          final selected = index == _selectedStyleIndex;
                          final tilt = selected ? 0.0 : (index.isEven ? -0.04 : 0.04);

                          return GestureDetector(
                            onTap: () =>
                                setState(() => _selectedStyleIndex = index),
                            child: Transform.rotate(
                              angle: tilt,
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 220),
                                width: 122,
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(22),
                                  gradient: LinearGradient(
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                    colors: item.colors,
                                  ),
                                  border: Border.all(
                                    color: selected
                                        ? Colors.white
                                        : Colors.white24,
                                    width: selected ? 2.2 : 1,
                                  ),
                                  boxShadow: selected
                                      ? [
                                          BoxShadow(
                                            color: withAlphaFraction(
                                              item.colors.first,
                                              0.45,
                                            ),
                                            blurRadius: 16,
                                            offset: const Offset(0, 6),
                                          ),
                                        ]
                                      : null,
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Icon(
                                      item.icon,
                                      color: Colors.white,
                                      size: 24,
                                    ),
                                    const Spacer(),
                                    Text(
                                      item.title,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w700,
                                        fontSize: 13,
                                      ),
                                    ),
                                    Text(
                                      item.subtitle,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        color: Colors.white70,
                                        fontSize: 10,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'نسبت تصویر',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children: [
                        for (final ar in _aspects)
                          ChoiceChip(
                            label: Text(ar),
                            selected: _aspectRatio == ar,
                            onSelected: (_) =>
                                setState(() => _aspectRatio = ar),
                          ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    OrbiSurface(
                      borderRadius: 22,
                      useBackdropBlur: true,
                      reducedBlur: reducedBlur,
                      concave: tokens.isNeumorphic,
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          TextField(
                            controller: _promptController,
                            minLines: 3,
                            maxLines: 5,
                            decoration: InputDecoration(
                              border: InputBorder.none,
                              hintText:
                                  'توصیف تصویر رو بنویس (مثلاً: کوهستان برفی زیر آسمان کهکشانی بنفش)...',
                              hintStyle: Theme.of(context)
                                  .textTheme
                                  .bodyMedium
                                  ?.copyWith(color: tokens.textMuted),
                            ),
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              OutlinedButton.icon(
                                onPressed:
                                    _isEnhancing ? null : _enhancePrompt,
                                icon: _isEnhancing
                                    ? const SizedBox(
                                        width: 14,
                                        height: 14,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : const Icon(
                                        Icons.auto_fix_high_rounded,
                                        size: 16,
                                      ),
                                label: const Text('بهبود پرامپت'),
                              ),
                              const Spacer(),
                              FilledButton.icon(
                                onPressed: _isGenerating ? null : _generate,
                                icon: _isGenerating
                                    ? const SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.white,
                                        ),
                                      )
                                    : const Icon(Icons.bolt_rounded, size: 18),
                                label: Text(
                                  _isGenerating ? 'در حال ساخت...' : 'بساز',
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    if (_errorText != null) ...[
                      const SizedBox(height: 12),
                      Text(
                        _errorText!,
                        style: TextStyle(color: tokens.dangerColor),
                      ),
                    ],
                    if (_result != null) ...[
                      const SizedBox(height: 18),
                      AnimatedOpacity(
                        opacity: 1.0,
                        duration: const Duration(milliseconds: 400),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            if (_result!.noticeFa != null) ...[
                              Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: Text(
                                  _result!.noticeFa!,
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                              ),
                            ],
                            OrbiSurface(
                              borderRadius: 22,
                              reducedBlur: reducedBlur,
                              padding: const EdgeInsets.all(8),
                              child: RepaintBoundary(
                                key: _renderKey,
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(18),
                                  child: _result!.rasterBytes != null
                                      ? Image.memory(
                                          _result!.rasterBytes!,
                                          fit: BoxFit.contain,
                                        )
                                      : AspectRatio(
                                          aspectRatio:
                                              _aspectNumeric(_aspectRatio),
                                          child: Container(
                                            color: const Color(0xFF0B0A16),
                                            child: SvgPicture.string(
                                              _result!.svgSource!,
                                              fit: BoxFit.contain,
                                            ),
                                          ),
                                        ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: FilledButton.icon(
                                    onPressed: _saveToGallery,
                                    icon: const Icon(
                                      Icons.download_rounded,
                                      size: 18,
                                    ),
                                    label: const Text('ذخیره در گالری'),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: OutlinedButton.icon(
                                    onPressed: _shareImage,
                                    icon: const Icon(
                                      Icons.share_rounded,
                                      size: 18,
                                    ),
                                    label: const Text('اشتراکگذاری'),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static double _aspectNumeric(String ar) {
    switch (ar) {
      case '16:9':
        return 16 / 9;
      case '9:16':
        return 9 / 16;
      case '4:5':
        return 4 / 5;
      default:
        return 1.0;
    }
  }
}
