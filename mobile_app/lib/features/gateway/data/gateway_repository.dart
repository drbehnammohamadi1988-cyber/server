import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';

import '../../../core/config/app_config.dart';
import '../../../core/network/gateway_client.dart';
import '../../../core/network/gateway_error.dart';
import '../../../core/network/sse_parser.dart';
import '../domain/gateway_models.dart';

/// Repository mapping 1:1 to `gateway` endpoints (`/v1/models`,
/// `/v1/chat/completions`, `/health/live`, and `/v1/images/generations` when enabled).
class GatewayRepository {
  GatewayRepository({required GatewayHttpClient client}) : _client = client;

  final GatewayHttpClient _client;

  Future<List<GatewayModel>> fetchModels(
    String baseUrl, {
    CancelToken? cancelToken,
  }) async {
    final response = await _client.getJson(
      baseUrl,
      '/v1/models',
      cancelToken: cancelToken,
    );
    final raw = response.data?.toString() ?? '{}';
    final decoded = jsonDecode(raw);
    if (decoded is! Map<String, dynamic>) {
      throw const GatewayException(
        code: GatewayErrorCode.upstreamError,
        messageFa: 'پاسخ لیست مدل‌ها از سرور ساختار نامعتبر دارد.',
      );
    }
    final list = decoded['data'];
    if (list is! List) {
      return const [];
    }
    return list
        .whereType<Map<String, dynamic>>()
        .map(GatewayModel.fromJson)
        .where((m) => m.id.isNotEmpty)
        .toList(growable: false);
  }

  /// Streams chat completions from `POST /v1/chat/completions` (`stream: true`).
  /// If multimodal content arrays are enabled and rejected with HTTP 400 by a
  /// text-only gateway, transparently falls back to string-encoded `content`.
  Stream<ChatStreamChunk> streamChat(
    String baseUrl,
    ChatCompletionRequest request, {
    CancelToken? cancelToken,
  }) async* {
    final extraHeaders = <String, String>{
      if (request.conversationId != null && request.conversationId!.isNotEmpty)
        'X-Conversation-ID': request.conversationId!,
      if (request.idempotencyKey != null && request.idempotencyKey!.isNotEmpty)
        'X-Idempotency-Key': request.idempotencyKey!,
    };

    Response<ResponseBody> response;
    try {
      response = await _client.postStream(
        baseUrl,
        '/v1/chat/completions',
        body: request.toJson(),
        extraHeaders: extraHeaders,
        cancelToken: cancelToken,
      );
    } on GatewayException catch (e) {
      if (request.useMultimodal &&
          e.code == GatewayErrorCode.invalidArgument &&
          e.statusCode == 400) {
        response = await _client.postStream(
          baseUrl,
          '/v1/chat/completions',
          body: request.toJson(overrideMultimodal: false),
          extraHeaders: extraHeaders,
          cancelToken: cancelToken,
        );
      } else {
        rethrow;
      }
    }

    final byteStream = response.data!.stream;
    await for (final sse in SseParser.parseUint8Stream(byteStream)) {
      if (sse.isDone) {
        yield const ChatStreamChunk(isDone: true);
        break;
      }
      final parsed = parseSsePayload(sse.data);
      if (parsed != null) {
        yield parsed;
      }
    }
  }

  /// Non-streaming chat completion (`stream: false`).
  Future<String> completeChat(
    String baseUrl,
    ChatCompletionRequest request, {
    CancelToken? cancelToken,
  }) async {
    final nonStream = ChatCompletionRequest(
      model: request.model,
      messages: request.messages,
      stream: false,
      temperature: request.temperature,
      topP: request.topP,
      maxTokens: request.maxTokens,
      stop: request.stop,
      conversationId: request.conversationId,
      idempotencyKey: request.idempotencyKey,
      useMultimodal: request.useMultimodal,
    );

    Response<dynamic> response;
    try {
      response = await _client.postJson(
        baseUrl,
        '/v1/chat/completions',
        body: nonStream.toJson(),
        cancelToken: cancelToken,
      );
    } on GatewayException catch (e) {
      if (request.useMultimodal &&
          e.code == GatewayErrorCode.invalidArgument &&
          e.statusCode == 400) {
        response = await _client.postJson(
          baseUrl,
          '/v1/chat/completions',
          body: nonStream.toJson(overrideMultimodal: false),
          cancelToken: cancelToken,
        );
      } else {
        rethrow;
      }
    }

    final decoded = jsonDecode(response.data?.toString() ?? '{}');
    if (decoded is Map<String, dynamic>) {
      final choices = decoded['choices'];
      if (choices is List && choices.isNotEmpty) {
        final first = choices.first;
        if (first is Map<String, dynamic>) {
          final msg = first['message'];
          if (msg is Map<String, dynamic>) {
            return (msg['content'] ?? '').toString();
          }
        }
      }
    }
    return '';
  }

  /// Checks Gateway reachability, latency (ms), model count, and optional
  /// operational liveness endpoint (`/health/live` on port 8081 or proxied).
  Future<HealthCheckResult> checkHealth(String baseUrl) async {
    final sw = Stopwatch()..start();
    try {
      final models = await fetchModels(baseUrl);
      sw.stop();

      bool? opsLive;
      try {
        final uri = Uri.parse(AppConfig.normalizeBaseUrl(baseUrl));
        final opsUrl = uri.port == 8080
            ? uri.replace(port: 8081).toString()
            : uri.toString();
        final opsResp = await _client.getJson(
          opsUrl,
          '/health/live',
          timeout: const Duration(seconds: 3),
        );
        opsLive = (opsResp.statusCode ?? 0) == 200;
      } catch (_) {
        opsLive = null;
      }

      return HealthCheckResult(
        isHealthy: true,
        latencyMs: sw.elapsedMilliseconds,
        modelCount: models.length,
        opsLive: opsLive,
        summaryFa:
            'اتصال برقرار است (${models.length} مدل آماده، پینگ ${sw.elapsedMilliseconds}ms)',
      );
    } on GatewayException catch (e) {
      sw.stop();
      return HealthCheckResult(
        isHealthy: false,
        latencyMs: sw.elapsedMilliseconds,
        modelCount: 0,
        summaryFa: e.messageFa,
      );
    } catch (e) {
      sw.stop();
      return HealthCheckResult(
        isHealthy: false,
        latencyMs: sw.elapsedMilliseconds,
        modelCount: 0,
        summaryFa: 'خطا در اتصال به سرور: $e',
      );
    }
  }

  /// Enhances a user's visual description into a rich prompt via `gateway`.
  Future<String> enhanceImagePrompt({
    required String baseUrl,
    required String model,
    required String prompt,
    required String styleName,
    required String aspectRatio,
  }) async {
    final req = ChatCompletionRequest(
      model: model,
      stream: false,
      temperature: 0.7,
      messages: [
        const GatewayChatMessage(
          role: 'system',
          content:
              'You are a world-class art director. Rewrite the user prompt into a concise, vivid, high-craft visual prompt in Persian or English matching the requested style and aspect ratio. Output ONLY the enhanced prompt text without preamble.',
        ),
        GatewayChatMessage(
          role: 'user',
          content:
              'Style: $styleName\nAspect Ratio: $aspectRatio\nIdea: $prompt',
        ),
      ],
    );
    final result = await completeChat(baseUrl, req);
    return result.trim().isEmpty ? prompt : result.trim();
  }

  /// Attempts `/v1/images/generations` first; if the connected text-only
  /// `gateway` returns 404, transparently delegates to `/v1/chat/completions`
  /// to compose crisp high-resolution SVG vector artwork that renders to PNG.
  Future<StudioVisualResult> generateVisual({
    required String baseUrl,
    required String model,
    required String prompt,
    required String styleName,
    required String aspectRatio,
  }) async {
    try {
      final response = await _client.postJson(
        baseUrl,
        '/v1/images/generations',
        body: {
          'model': model,
          'prompt': '$prompt, style: $styleName',
          'size': _sizeForAspect(aspectRatio),
          'response_format': 'b64_json',
        },
      );
      final decoded = jsonDecode(response.data?.toString() ?? '{}');
      if (decoded is Map<String, dynamic>) {
        final data = decoded['data'];
        if (data is List && data.isNotEmpty && data.first is Map) {
          final first = data.first as Map<String, dynamic>;
          final b64 = first['b64_json']?.toString();
          if (b64 != null && b64.isNotEmpty) {
            return StudioVisualResult(
              usedNativeImagesEndpoint: true,
              rasterBytes: base64Decode(b64),
              revisedPrompt: first['revised_prompt']?.toString(),
            );
          }
        }
      }
    } on GatewayException catch (e) {
      if (e.statusCode != 404) {
        rethrow;
      }
      // 404 means the connected `gateway` only exposes chat/models right now.
      // Fall through to real SVG poster synthesis via `/v1/chat/completions`.
    }

    final viewBox = _viewBoxForAspect(aspectRatio);
    final svgCompletion = await completeChat(
      baseUrl,
      ChatCompletionRequest(
        model: model,
        stream: false,
        temperature: 0.65,
        messages: [
          GatewayChatMessage(
            role: 'system',
            content:
                'You are an expert SVG graphic designer. Create a detailed, visually striking, self-contained SVG artwork using gradients, layered shapes, lighting, and clean geometry. '
                'Output ONLY valid <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 ${viewBox.$1} ${viewBox.$2}">...</svg> with no markdown fences or explanation.',
          ),
          GatewayChatMessage(
            role: 'user',
            content:
                'Create an artwork for: "$prompt". Aesthetic style: "$styleName". Canvas viewBox: 0 0 ${viewBox.$1} ${viewBox.$2}.',
          ),
        ],
      ),
    );

    final extractedSvg = extractSvgDocument(svgCompletion);
    if (extractedSvg == null) {
      throw const GatewayException(
        code: GatewayErrorCode.upstreamError,
        isRetryable: true,
        messageFa:
            'سرور Gateway مسیر /v1/images/generations را ندارد و خروجی برداری معتبر نیز تولید نشد. دوباره تلاش کنید.',
      );
    }

    return StudioVisualResult(
      usedNativeImagesEndpoint: false,
      svgSource: extractedSvg,
      noticeFa:
          'سرور فعلی Gateway فقط از چت متنی پشتیبانی می‌کند (/v1/images/generations یافت نشد)؛ بنابراین اثر گرافیکی برداری زنده توسط مدل هوش مصنوعی ساخته و به تصویر باکیفیت تبدیل شد.',
    );
  }

  static String? extractSvgDocument(String raw) {
    var cleaned = raw.trim();
    cleaned = cleaned.replaceAll(RegExp(r'^```(?:svg|xml|html)?\s*', multiLine: true), '');
    cleaned = cleaned.replaceAll(RegExp(r'```\s*$', multiLine: true), '');
    final start = cleaned.indexOf('<svg');
    final end = cleaned.lastIndexOf('</svg>');
    if (start == -1 || end == -1 || end <= start) return null;
    return cleaned.substring(start, end + '</svg>'.length);
  }

  static ChatStreamChunk? parseSsePayload(String rawJson) {
    final trimmed = rawJson.trim();
    if (trimmed.isEmpty) return null;
    if (trimmed == '[DONE]') {
      return const ChatStreamChunk(isDone: true);
    }

    final dynamic decoded;
    try {
      decoded = jsonDecode(trimmed);
    } catch (_) {
      return null;
    }
    if (decoded is! Map<String, dynamic>) return null;

    if (decoded['error'] is Map<String, dynamic>) {
      final err = decoded['error'] as Map<String, dynamic>;
      final msg = (err['message'] ?? 'خطای استریم از سرور').toString();
      throw GatewayException(
        code: GatewayErrorCode.upstreamError,
        rawDetail: msg,
        isRetryable: true,
        messageFa: msg,
      );
    }

    int? promptTokens;
    int? completionTokens;
    final usage = decoded['usage'];
    if (usage is Map<String, dynamic>) {
      promptTokens = (usage['prompt_tokens'] as num?)?.toInt();
      completionTokens = (usage['completion_tokens'] as num?)?.toInt();
    }

    final choices = decoded['choices'];
    var contentDelta = '';
    var reasoningDelta = '';
    String? finishReason;

    if (choices is List && choices.isNotEmpty && choices.first is Map) {
      final choice = choices.first as Map<String, dynamic>;
      finishReason = choice['finish_reason']?.toString();
      final delta = choice['delta'];
      if (delta is Map<String, dynamic>) {
        contentDelta = (delta['content'] ?? '').toString();
        reasoningDelta = (delta['reasoning_content'] ??
                delta['reasoning'] ??
                '')
            .toString();
      } else if (choice['message'] is Map<String, dynamic>) {
        final msg = choice['message'] as Map<String, dynamic>;
        contentDelta = (msg['content'] ?? '').toString();
        reasoningDelta =
            (msg['reasoning_content'] ?? msg['reasoning'] ?? '').toString();
      }
    }

    if (contentDelta.isEmpty &&
        reasoningDelta.isEmpty &&
        finishReason == null &&
        promptTokens == null &&
        completionTokens == null) {
      return null;
    }

    return ChatStreamChunk(
      contentDelta: contentDelta,
      reasoningDelta: reasoningDelta,
      finishReason: finishReason,
      promptTokens: promptTokens,
      completionTokens: completionTokens,
    );
  }

  static String _sizeForAspect(String aspect) {
    switch (aspect) {
      case '16:9':
        return '1792x1024';
      case '9:16':
        return '1024x1792';
      default:
        return '1024x1024';
    }
  }

  static (int, int) _viewBoxForAspect(String aspect) {
    switch (aspect) {
      case '16:9':
        return (1280, 720);
      case '9:16':
        return (720, 1280);
      case '4:5':
        return (800, 1000);
      default:
        return (1000, 1000);
    }
  }
}
