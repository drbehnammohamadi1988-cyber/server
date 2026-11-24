import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:uuid/uuid.dart';

import '../../../core/theme/app_theme_tokens.dart';
import '../../../core/theme/theme_controller.dart';
import '../../../core/utils/file_extractor.dart';
import '../../../core/utils/persian_digits.dart';
import '../../../core/widgets/surface_container.dart';
import '../chat/domain/chat_models.dart';
import '../chat/presentation/chat_controller.dart';
import '../image_studio/image_studio_screen.dart';
import '../voice/live_voice_screen.dart';

/// Floating Glass / Neumorphic input composer (`borderRadius: 26`) with
/// attachment preview tray, `+` tools bottom sheet, Persian STT microphone,
/// Live Voice Mode trigger, and animated Send/Stop action button.
class FloatingGlassComposer extends ConsumerStatefulWidget {
  const FloatingGlassComposer({
    super.key,
    required this.controller,
    required this.focusNode,
  });

  final TextEditingController controller;
  final FocusNode focusNode;

  @override
  ConsumerState<FloatingGlassComposer> createState() =>
      _FloatingGlassComposerState();
}

class _FloatingGlassComposerState
    extends ConsumerState<FloatingGlassComposer> {
  static const _uuid = Uuid();
  final ImagePicker _imagePicker = ImagePicker();
  final SpeechToText _speech = SpeechToText();

  final List<ChatAttachment> _attachments = [];
  bool _isListening = false;
  bool _hasText = false;

  @override
  void initState() {
    super.initState();
    _hasText = widget.controller.text.trim().isNotEmpty;
    widget.controller.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onTextChanged);
    _speech.stop();
    super.dispose();
  }

  void _onTextChanged() {
    final nextHasText = widget.controller.text.trim().isNotEmpty;
    if (nextHasText != _hasText) {
      setState(() => _hasText = nextHasText);
    }
  }

  void _haptic() {
    if (ref.read(themeSettingsProvider).hapticsEnabled) {
      HapticFeedback.selectionClick();
    }
  }

  Future<void> _send() async {
    final text = widget.controller.text;
    if (text.trim().isEmpty && _attachments.isEmpty) return;

    _haptic();
    final sentAttachments = List<ChatAttachment>.from(_attachments);
    widget.controller.clear();
    setState(() {
      _attachments.clear();
      _hasText = false;
    });

    await ref.read(chatControllerProvider.notifier).sendUserMessage(
          text,
          attachments: sentAttachments,
        );
  }

  Future<void> _pickGalleryImages() async {
    final files = await _imagePicker.pickMultiImage(imageQuality: 90);
    if (files.isEmpty) return;
    await _ingestImages(files);
  }

  Future<void> _captureCameraImage() async {
    final status = await Permission.camera.request();
    if (!status.isGranted) {
      _showToast('برای گرفتن عکس، دسترسی دوربین مورد نیاز است.');
      return;
    }
    final photo = await _imagePicker.pickImage(
      source: ImageSource.camera,
      imageQuality: 90,
    );
    if (photo != null) {
      await _ingestImages([photo]);
    }
  }

  Future<void> _ingestImages(List<XFile> files) async {
    final docsDir = await getApplicationDocumentsDirectory();
    final mediaDir = Directory(p.join(docsDir.path, 'orbi_media'));
    if (!await mediaDir.exists()) {
      await mediaDir.create(recursive: true);
    }

    final added = <ChatAttachment>[];
    for (final xfile in files) {
      final rawBytes = await xfile.readAsBytes();
      final compressed = await FileProcessor.compressImageBytes(rawBytes);
      final id = _uuid.v4();
      final fileName = '${p.basenameWithoutExtension(xfile.name)}.jpg';
      final dest = File(p.join(mediaDir.path, '${id}_$fileName'));
      await dest.writeAsBytes(compressed, flush: true);

      added.add(
        ChatAttachment(
          id: id,
          kind: AttachmentKind.image,
          name: fileName,
          localPath: dest.path,
          sizeBytes: compressed.length,
          mimeType: 'image/jpeg',
        ),
      );
    }
    if (mounted) {
      setState(() => _attachments.addAll(added));
    }
  }

  Future<void> _pickDocuments() async {
    final picked = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: const [
        'pdf',
        'txt',
        'md',
        'csv',
        'json',
        'html',
        'xml',
        'yaml',
        'yml',
        'dart',
        'py',
        'js',
        'ts',
        'sql',
        'log',
      ],
    );
    if (picked.isEmpty) return;

    final added = <ChatAttachment>[];
    for (final pf in picked) {
      final path = pf.path;
      if (path == null) continue;
      final ext = p.extension(pf.name).replaceAll('.', '');
      final extracted = await FileProcessor.extractReadableText(path, ext);
      final fileSize = await pf.length() ?? await File(path).length();
      added.add(
        ChatAttachment(
          id: _uuid.v4(),
          kind: AttachmentKind.document,
          name: pf.name,
          localPath: path,
          sizeBytes: fileSize,
          mimeType: 'text/plain',
          extractedText: extracted,
        ),
      );
    }
    if (mounted) {
      setState(() => _attachments.addAll(added));
    }
  }

  Future<void> _toggleSpeechToText() async {
    if (_isListening) {
      await _speech.stop();
      setState(() => _isListening = false);
      return;
    }

    final micPerm = await Permission.microphone.request();
    if (!micPerm.isGranted) {
      _showToast('برای تبدیل گفتار به متن، مجوز میکروفون لازم است.');
      return;
    }

    final available = await _speech.initialize(
      onStatus: (status) {
        if ((status == 'done' || status == 'notListening') && mounted) {
          setState(() => _isListening = false);
        }
      },
      onError: (_) {
        if (mounted) setState(() => _isListening = false);
      },
    );

    if (!available) {
      _showToast('سرویس تشخیص گفتار روی این دستگاه در دسترس نیست.');
      return;
    }

    _haptic();
    setState(() => _isListening = true);
    final baseline = widget.controller.text.trim();

    await _speech.listen(
      listenOptions: SpeechListenOptions(
        localeId: 'fa_IR',
        partialResults: true,
        listenMode: ListenMode.dictation,
      ),
      onResult: (res) {
        final spoken = res.recognizedWords.trim();
        if (spoken.isEmpty) return;
        widget.controller.text =
            baseline.isEmpty ? spoken : '$baseline $spoken';
        widget.controller.selection = TextSelection.fromPosition(
          TextPosition(offset: widget.controller.text.length),
        );
      },
    );
  }

  void _openToolsSheet() {
    _haptic();
    final tokens = context.orbiTokens;
    final reducedBlur = ref.read(themeSettingsProvider).reducedBlur;
    final session = ref.read(chatControllerProvider);

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetCtx) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
          child: OrbiSurface(
            borderRadius: 26,
            useBackdropBlur: true,
            reducedBlur: reducedBlur,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
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
                const SizedBox(height: 14),
                Text(
                  'ابزارها و پیوست‌های هوشمند',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 14),
                _ToolSheetTile(
                  icon: Icons.photo_library_outlined,
                  title: 'انتخاب تصویر از گالری',
                  subtitle: 'پشتیبانی از انتخاب یک یا چند تصویر',
                  onTap: () {
                    Navigator.pop(sheetCtx);
                    _pickGalleryImages();
                  },
                ),
                _ToolSheetTile(
                  icon: Icons.photo_camera_outlined,
                  title: 'گرفتن عکس با دوربین',
                  subtitle: 'عکسبرداری و ارسال آنی برای تحلیل',
                  onTap: () {
                    Navigator.pop(sheetCtx);
                    _captureCameraImage();
                  },
                ),
                _ToolSheetTile(
                  icon: Icons.attach_file_rounded,
                  title: 'پیوست فایل و سند',
                  subtitle: 'PDF، TXT، Markdown، CSV، JSON و کدهای برنامه‌نویسی',
                  onTap: () {
                    Navigator.pop(sheetCtx);
                    _pickDocuments();
                  },
                ),
                _ToolSheetTile(
                  icon: Icons.brush_outlined,
                  title: 'استودیو تولید تصویر',
                  subtitle: 'ساخت تصویر و پوسترهای خلاقانه با استایل‌های آماده',
                  onTap: () {
                    Navigator.pop(sheetCtx);
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const ImageStudioScreen(),
                      ),
                    );
                  },
                ),
                _ToolSheetTile(
                  icon: Icons.description_outlined,
                  title: session.fileBuilderMode
                      ? 'خروج از حالت فایل‌ساز هوشمند'
                      : 'حالت فایل‌ساز و سندساز هوشمند',
                  subtitle: 'تولید خروجی ساختاریافته PDF، HTML، Markdown و CSV',
                  active: session.fileBuilderMode,
                  onTap: () {
                    ref
                        .read(chatControllerProvider.notifier)
                        .setFileBuilderMode(!session.fileBuilderMode);
                    Navigator.pop(sheetCtx);
                  },
                ),
                _ToolSheetTile(
                  icon: Icons.theater_comedy_outlined,
                  title: 'انتخاب شخصیت / پرامپت سیستم سریع',
                  subtitle: 'تنظیم لحن و تخصص دستیار برای همین گفتگو',
                  onTap: () {
                    Navigator.pop(sheetCtx);
                    _openPersonaSheet();
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _openPersonaSheet() {
    final reducedBlur = ref.read(themeSettingsProvider).reducedBlur;
    const personas = <(String, String, String?)>[
      (
        'حالت پیش‌فرض اوربی',
        'پاسخ‌های جامع، روان و دقیق فارسی',
        null,
      ),
      (
        'معمار نرم‌افزار و کدنویس ارشد',
        'تحلیل عمیق کد، معماری تمیز و دیباگ حرفه‌ای',
        'تو یک مهندس ارشد نرم‌افزار هستی. پاسخ‌های کدنویسی را دقیق، ماژولار، امن و بدون باگ با توضیح فارسی شفاف بنویس.',
      ),
      (
        'ویراستار و نویسنده خلاق فارسی',
        'نگارش ادبی، محتوای شبکه‌های اجتماعی و بازنویسی حرفه‌ای',
        'تو یک نویسنده و ویراستار حرفه‌ای زبان فارسی هستی. متون را خوش‌آهنگ، مدرن و با رعایت کامل نیم‌فاصله بنویس.',
      ),
      (
        'معلم و مربی حل مسئله',
        'توضیح گام‌به‌گام ریاضی، علوم و مفاهیم پیچیده با مثال',
        'تو یک معلم صبور و مسلط هستی. مسائل را قدم به قدم، قابل فهم و همراه با مثال ملموس و فرمول دقیق آموزش بده.',
      ),
    ];

    showModalBottomSheet<void>(
      context: context,
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
          child: OrbiSurface(
            borderRadius: 26,
            useBackdropBlur: true,
            reducedBlur: reducedBlur,
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'انتخاب شخصیت سریع دستیار',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 12),
                for (final item in personas)
                  _ToolSheetTile(
                    icon: Icons.auto_awesome_outlined,
                    title: item.$1,
                    subtitle: item.$2,
                    onTap: () {
                      ref
                          .read(chatControllerProvider.notifier)
                          .setPersona(item.$3);
                      Navigator.pop(ctx);
                      _showToast('شخصیت فعال: ${item.$1}');
                    },
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showToast(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.orbiTokens;
    final reducedBlur = ref.watch(themeSettingsProvider).reducedBlur;
    final chatState = ref.watch(chatControllerProvider);
    final isStreaming = chatState.isStreaming;
    final canSend = _hasText || _attachments.isNotEmpty;

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 6, 12, 10),
      child: OrbiSurface(
        borderRadius: 26,
        useBackdropBlur: true,
        reducedBlur: reducedBlur,
        concave: tokens.isNeumorphic,
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (chatState.fileBuilderMode) ...[
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Icon(
                      Icons.description_rounded,
                      size: 15,
                      color: tokens.accentPrimary,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'حالت فایل‌ساز و سندساز هوشمند فعال است',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: tokens.accentPrimary,
                      ),
                    ),
                    const Spacer(),
                    GestureDetector(
                      onTap: () => ref
                          .read(chatControllerProvider.notifier)
                          .setFileBuilderMode(false),
                      child: Icon(
                        Icons.close_rounded,
                        size: 16,
                        color: tokens.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ],
            if (_attachments.isNotEmpty) ...[
              SizedBox(
                height: 68,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: _attachments.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 8),
                  itemBuilder: (context, index) {
                    final att = _attachments[index];
                    return _AttachmentTrayItem(
                      attachment: att,
                      onRemove: () {
                        setState(() => _attachments.removeAt(index));
                      },
                    );
                  },
                ),
              ),
              const SizedBox(height: 8),
            ],
            Directionality(
              textDirection: TextDirection.rtl,
              child: TextField(
                controller: widget.controller,
                focusNode: widget.focusNode,
                minLines: 1,
                maxLines: 6,
                textInputAction: TextInputAction.newline,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      height: 1.55,
                    ),
                decoration: InputDecoration(
                  isCollapsed: true,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 6,
                  ),
                  border: InputBorder.none,
                  hintText: 'هرچی میخوای بپرس...',
                  hintStyle: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: tokens.textMuted,
                      ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                _ComposerIconCircle(
                  icon: Icons.add_rounded,
                  tooltip: 'ابزارها و پیوست',
                  onTap: _openToolsSheet,
                ),
                const Spacer(),
                _ComposerIconCircle(
                  icon: _isListening ? Icons.mic_rounded : Icons.mic_none_rounded,
                  tooltip: _isListening ? 'توقف ضبط صدا' : 'تبدیل گفتار به متن',
                  active: _isListening,
                  activeColor: tokens.dangerColor,
                  onTap: _toggleSpeechToText,
                ),
                const SizedBox(width: 6),
                _ComposerIconCircle(
                  icon: Icons.graphic_eq_rounded,
                  tooltip: 'مکالمه صوتی زنده',
                  onTap: () {
                    _haptic();
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const LiveVoiceScreen(),
                      ),
                    );
                  },
                ),
                const SizedBox(width: 8),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 220),
                  transitionBuilder: (child, anim) =>
                      ScaleTransition(scale: anim, child: child),
                  child: isStreaming
                      ? GestureDetector(
                          key: const ValueKey('stop_btn'),
                          onTap: () {
                            _haptic();
                            ref
                                .read(chatControllerProvider.notifier)
                                .stopStreaming();
                          },
                          child: Container(
                            width: 38,
                            height: 38,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: tokens.sendButtonBg,
                            ),
                            child: Icon(
                              Icons.stop_rounded,
                              color: tokens.sendButtonFg,
                              size: 20,
                            ),
                          ),
                        )
                      : GestureDetector(
                          key: const ValueKey('send_btn'),
                          onTap: canSend ? _send : null,
                          child: AnimatedOpacity(
                            opacity: canSend ? 1.0 : 0.42,
                            duration: const Duration(milliseconds: 180),
                            child: Container(
                              width: 38,
                              height: 38,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: tokens.sendButtonBg,
                              ),
                              child: Icon(
                                Icons.arrow_upward_rounded,
                                color: tokens.sendButtonFg,
                                size: 20,
                              ),
                            ),
                          ),
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

class _ComposerIconCircle extends StatelessWidget {
  const _ComposerIconCircle({
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.active = false,
    this.activeColor,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  final bool active;
  final Color? activeColor;

  @override
  Widget build(BuildContext context) {
    final tokens = context.orbiTokens;
    return Tooltip(
      message: tooltip,
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: active
                ? withAlphaFraction(activeColor ?? tokens.accentPrimary, 0.2)
                : withAlphaFraction(tokens.textMuted, 0.12),
          ),
          child: Icon(
            icon,
            size: 19,
            color: active
                ? (activeColor ?? tokens.accentPrimary)
                : tokens.textSecondary,
          ),
        ),
      ),
    );
  }
}

class _AttachmentTrayItem extends StatelessWidget {
  const _AttachmentTrayItem({
    required this.attachment,
    required this.onRemove,
  });

  final ChatAttachment attachment;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final tokens = context.orbiTokens;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        if (attachment.kind == AttachmentKind.image)
          ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: Image.file(
              File(attachment.localPath),
              width: 62,
              height: 62,
              fit: BoxFit.cover,
            ),
          )
        else
          Container(
            width: 155,
            height: 62,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              color: withAlphaFraction(tokens.surfaceElevated, 0.85),
              border: Border.all(
                color: withAlphaFraction(tokens.accentPrimary, 0.3),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.description_outlined,
                  size: 20,
                  color: tokens.accentPrimary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        attachment.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        PersianFormatter.formatFileSize(attachment.sizeBytes),
                        style: Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.copyWith(fontSize: 10.5),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        Positioned(
          top: -4,
          left: -4,
          child: GestureDetector(
            onTap: onRemove,
            child: Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: tokens.dangerColor,
              ),
              child: const Icon(
                Icons.close_rounded,
                size: 13,
                color: Colors.white,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _ToolSheetTile extends StatelessWidget {
  const _ToolSheetTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.active = false,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final tokens = context.orbiTokens;
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: withAlphaFraction(
            active ? tokens.successColor : tokens.accentPrimary,
            0.16,
          ),
        ),
        child: Icon(
          icon,
          color: active ? tokens.successColor : tokens.accentPrimary,
          size: 20,
        ),
      ),
      title: Text(
        title,
        style: Theme.of(context)
            .textTheme
            .titleMedium
            ?.copyWith(fontSize: 14.5),
      ),
      subtitle: Text(
        subtitle,
        style: Theme.of(context).textTheme.bodySmall,
      ),
      onTap: onTap,
    );
  }
}
