import 'dart:math' as math;

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:speech_to_text/speech_to_text.dart';

import '../../core/network/gateway_error.dart';
import '../../core/theme/app_theme_tokens.dart';
import '../../core/theme/theme_controller.dart';
import '../../core/utils/thinking_parser.dart';
import '../../core/widgets/ambient_cosmic_background.dart';
import '../../core/widgets/gradient_text.dart';
import '../../core/widgets/surface_container.dart';
import '../gateway/domain/gateway_models.dart';
import '../gateway/presentation/gateway_providers.dart';

enum _VoiceStage { idle, listening, thinking, speaking }

/// Interactive Live Voice Mode with a reactive cosmic orb driven by real-time
/// Android microphone sound levels, live Persian STT, `gateway` streaming, and
/// Android TTS playback.
class LiveVoiceScreen extends ConsumerStatefulWidget {
  const LiveVoiceScreen({super.key});

  @override
  ConsumerState<LiveVoiceScreen> createState() => _LiveVoiceScreenState();
}

class _LiveVoiceScreenState extends ConsumerState<LiveVoiceScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _orbController;
  final SpeechToText _speech = SpeechToText();
  final FlutterTts _tts = FlutterTts();
  final List<GatewayChatMessage> _voiceHistory = [];

  _VoiceStage _stage = _VoiceStage.idle;
  double _soundLevel = 0.0;
  String _transcript = 'برای شروع گفتگو روی میکروفون ضربه بزنید';
  String _aiResponse = '';
  CancelToken? _cancelToken;

  @override
  void initState() {
    super.initState();
    _orbController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();
    _initTts();
  }

  Future<void> _initTts() async {
    _tts.setCompletionHandler(() {
      if (mounted) {
        setState(() => _stage = _VoiceStage.idle);
      }
    });
    _tts.setCancelHandler(() {
      if (mounted) {
        setState(() => _stage = _VoiceStage.idle);
      }
    });
  }

  @override
  void dispose() {
    _cancelToken?.cancel();
    _speech.stop();
    _tts.stop();
    _orbController.dispose();
    super.dispose();
  }

  Future<void> _startListening() async {
    await _tts.stop();
    _cancelToken?.cancel();

    final perm = await Permission.microphone.request();
    if (!perm.isGranted) {
      setState(() {
        _transcript = 'دسترسی میکروفون داده نشد.';
        _stage = _VoiceStage.idle;
      });
      return;
    }

    final ok = await _speech.initialize(
      onStatus: (status) {
        if (status == 'done' && _stage == _VoiceStage.listening && mounted) {
          _submitVoiceTurn();
        }
      },
      onError: (_) {
        if (mounted) setState(() => _stage = _VoiceStage.idle);
      },
    );

    if (!ok) {
      setState(() {
        _transcript = 'تشخیص گفتار روی این دستگاه فعال نیست.';
        _stage = _VoiceStage.idle;
      });
      return;
    }

    setState(() {
      _stage = _VoiceStage.listening;
      _transcript = 'در حال شنیدن...';
      _aiResponse = '';
    });

    await _speech.listen(
      listenOptions: SpeechListenOptions(localeId: 'fa_IR'),
      onSoundLevelChange: (level) {
        if (!mounted) return;
        setState(() {
          _soundLevel = ((level + 2) / 12).clamp(0.0, 1.0);
        });
      },
      onResult: (res) {
        if (!mounted) return;
        setState(() => _transcript = res.recognizedWords);
        if (res.finalResult) {
          _submitVoiceTurn();
        }
      },
    );
  }

  Future<void> _stopListeningAndSend() async {
    await _speech.stop();
    await _submitVoiceTurn();
  }

  Future<void> _submitVoiceTurn() async {
    if (_stage == _VoiceStage.thinking) return;
    final spoken = _transcript.trim();
    if (spoken.isEmpty || spoken == 'در حال شنیدن...') {
      setState(() => _stage = _VoiceStage.idle);
      return;
    }

    final gateway = ref.read(gatewayConfigProvider);
    final modelId = gateway.selectedModel?.id;
    if (modelId == null) {
      setState(() {
        _stage = _VoiceStage.idle;
        _aiResponse = 'هیچ مدلی از Gateway در دسترس نیست.';
      });
      return;
    }

    setState(() {
      _stage = _VoiceStage.thinking;
      _soundLevel = 0.25;
      _aiResponse = '';
    });

    _voiceHistory.add(GatewayChatMessage(role: 'user', content: spoken));

    final cancelToken = CancelToken();
    _cancelToken = cancelToken;
    final rawBuf = StringBuffer();

    try {
      final stream = ref.read(gatewayRepositoryProvider).streamChat(
            gateway.baseUrl,
            ChatCompletionRequest(
              model: modelId,
              messages: [
                GatewayChatMessage(
                  role: 'system',
                  content:
                      '${gateway.systemPrompt}\nپاسخ صوتی کوتاه، صمیمی و شفاف (حداکثر ۳ تا ۴ جمله) بدون کد طولانی بده.',
                ),
                ..._voiceHistory,
              ],
              stream: true,
              temperature: gateway.temperature,
            ),
            cancelToken: cancelToken,
          );

      await for (final chunk in stream) {
        if (chunk.contentDelta.isNotEmpty) {
          rawBuf.write(chunk.contentDelta);
          final split = ThinkingParser.parse(rawBuf.toString());
          if (mounted) {
            setState(() => _aiResponse = split.visibleContent);
          }
        }
      }

      final finalText = ThinkingParser.parse(rawBuf.toString()).visibleContent;
      if (finalText.isNotEmpty) {
        _voiceHistory.add(
          GatewayChatMessage(role: 'assistant', content: finalText),
        );
        if (mounted) {
          setState(() {
            _stage = _VoiceStage.speaking;
            _aiResponse = finalText;
          });
        }
        final hasFa = RegExp(r'[\u0600-\u06FF]').hasMatch(finalText);
        await _tts.setLanguage(hasFa ? 'fa-IR' : 'en-US');
        await _tts.setSpeechRate(0.5);
        await _tts.speak(finalText);
      } else if (mounted) {
        setState(() => _stage = _VoiceStage.idle);
      }
    } on GatewayException catch (e) {
      if (mounted) {
        setState(() {
          _stage = _VoiceStage.idle;
          _aiResponse = e.messageFa;
        });
      }
    }
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
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                    const Spacer(),
                    const GradientText('مکالمه صوتی زنده'),
                    const Spacer(),
                    const SizedBox(width: 48),
                  ],
                ),
              ),
              const Spacer(),
              RepaintBoundary(
                child: AnimatedBuilder(
                  animation: _orbController,
                  builder: (context, _) {
                    final energy = _stage == _VoiceStage.listening
                        ? (0.35 + _soundLevel * 0.65)
                        : _stage == _VoiceStage.speaking
                            ? 0.72
                            : _stage == _VoiceStage.thinking
                                ? 0.52
                                : 0.18;
                    return CustomPaint(
                      size: const Size(230, 230),
                      painter: _CosmicOrbPainter(
                        phase: _orbController.value * math.pi * 2,
                        energy: energy,
                        colors: tokens.titleGradient,
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 22),
              Text(
                _stageLabel(),
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: tokens.accentPrimary,
                    ),
              ),
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 22),
                child: OrbiSurface(
                  borderRadius: 20,
                  useBackdropBlur: true,
                  reducedBlur: reducedBlur,
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Text(
                        _transcript,
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      if (_aiResponse.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        Divider(
                          height: 1,
                          color: withAlphaFraction(tokens.textMuted, 0.2),
                        ),
                        const SizedBox(height: 10),
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxHeight: 160),
                          child: SingleChildScrollView(
                            child: Text(
                              _aiResponse,
                              textAlign: TextAlign.center,
                              style: Theme.of(context).textTheme.bodyLarge,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const Spacer(),
              Padding(
                padding: const EdgeInsets.only(bottom: 28),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    GestureDetector(
                      onTap: () {
                        if (_stage == _VoiceStage.listening) {
                          _stopListeningAndSend();
                        } else {
                          _startListening();
                        }
                      },
                      child: Container(
                        width: 72,
                        height: 72,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(colors: tokens.titleGradient),
                          boxShadow: [
                            BoxShadow(
                              color: withAlphaFraction(tokens.accentPrimary, 0.4),
                              blurRadius: 24,
                            ),
                          ],
                        ),
                        child: Icon(
                          _stage == _VoiceStage.listening
                              ? Icons.stop_rounded
                              : Icons.mic_rounded,
                          size: 32,
                          color: Colors.white,
                        ),
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

  String _stageLabel() {
    switch (_stage) {
      case _VoiceStage.idle:
        return 'آمادهٔ شنیدن صدای شما';
      case _VoiceStage.listening:
        return 'در حال گوش دادن...';
      case _VoiceStage.thinking:
        return 'در حال دریافت پاسخ از Gateway...';
      case _VoiceStage.speaking:
        return 'در حال پاسخگویی صوتی';
    }
  }
}

class _CosmicOrbPainter extends CustomPainter {
  const _CosmicOrbPainter({
    required this.phase,
    required this.energy,
    required this.colors,
  });

  final double phase;
  final double energy;
  final List<Color> colors;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final baseRadius = size.width * 0.31;

    for (var ring = 0; ring < 3; ring++) {
      final r = baseRadius * (1.0 + ring * 0.2 + math.sin(phase + ring) * 0.06 * energy);
      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0 + (2 - ring) * 0.8
        ..color = withAlphaFraction(
          colors[ring % colors.length],
          0.22 + energy * 0.35,
        );
      canvas.drawCircle(center, r, paint);
    }

    final coreRadius = baseRadius * (0.9 + math.sin(phase * 2) * 0.08 * energy);
    final coreRect = Rect.fromCircle(center: center, radius: coreRadius);
    canvas.drawCircle(
      center,
      coreRadius,
      Paint()
        ..shader = RadialGradient(
          colors: [
            Colors.white.withValues(alpha: 0.85),
            colors.first,
            colors.last.withValues(alpha: 0.75),
          ],
        ).createShader(coreRect),
    );
  }

  @override
  bool shouldRepaint(_CosmicOrbPainter oldDelegate) =>
      oldDelegate.phase != phase || oldDelegate.energy != energy;
}
