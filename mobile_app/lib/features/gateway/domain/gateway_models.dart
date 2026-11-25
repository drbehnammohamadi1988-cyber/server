import 'package:flutter/foundation.dart';

/// Model descriptor returned dynamically by `GET /v1/models` on `gateway`.
@immutable
class GatewayModel {
  const GatewayModel({
    required this.id,
    this.displayLabel,
    this.objectType = 'model',
    this.ownedBy,
    this.supportsVision = false,
    this.supportsReasoning = false,
    this.isFast = false,
    this.isCoding = false,
  });

  final String id;
  final String? displayLabel;
  final String objectType;
  final String? ownedBy;
  final bool supportsVision;
  final bool supportsReasoning;
  final bool isFast;
  final bool isCoding;

  String get displayName {
    final label = displayLabel?.trim();
    if (label != null && label.isNotEmpty) {
      return label;
    }
    final slash = id.lastIndexOf('/');
    if (slash >= 0 && slash < id.length - 1) {
      return id.substring(slash + 1);
    }
    return id;
  }

  List<String> get capabilityLabelsFa {
    final labels = <String>[];
    if (supportsVision) labels.add('بینایی/تصویر');
    if (supportsReasoning) labels.add('استدلال عمیق');
    if (isFast) labels.add('سریع');
    if (isCoding) labels.add('کدنویسی');
    if (labels.isEmpty) labels.add('هوش مصنوعی جامع');
    return labels;
  }

  factory GatewayModel.fromJson(Map<String, dynamic> json) {
    final id = (json['id'] ?? '').toString().trim();
    final lower = id.toLowerCase();
    final caps = json['capabilities'];
    bool? explicitVision;
    bool? explicitReasoning;
    if (caps is Map<String, dynamic>) {
      explicitVision = caps['vision'] as bool?;
      explicitReasoning = caps['reasoning'] as bool?;
    }

    final supportsVision = explicitVision ??
        (lower.contains('vision') ||
            lower.contains('4o') ||
            lower.contains('gpt-5') ||
            lower.contains('gpt-6') ||
            lower.contains('gemini') ||
            lower.contains('claude-3') ||
            lower.contains('claude-haiku') ||
            lower.contains('claude-sonnet') ||
            lower.contains('pixtral'));

    final supportsReasoning = explicitReasoning ??
        (lower.startsWith('o1') ||
            lower.startsWith('o3') ||
            lower.startsWith('o4') ||
            lower.contains('gpt-5') ||
            lower.contains('gpt-6') ||
            lower.contains('gemma4') ||
            lower.contains('reasoner') ||
            lower.contains('r1') ||
            lower.contains('thinking'));

    final isFast = lower.contains('mini') ||
        lower.contains('luna') ||
        lower.contains('haiku') ||
        lower.contains('flash') ||
        lower.contains('small') ||
        lower.contains('8b') ||
        lower.contains('turbo');

    final isCoding = lower.contains('coder') ||
        lower.contains('code') ||
        lower.contains('claude') ||
        lower.contains('gpt-4') ||
        lower.contains('gpt-5') ||
        lower.contains('gpt-6') ||
        lower.contains('gemma4') ||
        lower.contains('llama-3.3');

    return GatewayModel(
      id: id,
      displayLabel: json['name']?.toString(),
      objectType: (json['object'] ?? 'model').toString(),
      ownedBy: json['owned_by']?.toString(),
      supportsVision: supportsVision,
      supportsReasoning: supportsReasoning,
      isFast: isFast,
      isCoding: isCoding,
    );
  }
}

@immutable
class GatewayChatImagePart {
  const GatewayChatImagePart({
    required this.base64Data,
    this.mimeType = 'image/jpeg',
  });

  final String base64Data;
  final String mimeType;

  String get dataUri => 'data:$mimeType;base64,$base64Data';
}

@immutable
class GatewayChatMessage {
  const GatewayChatMessage({
    required this.role,
    required this.content,
    this.images = const [],
  });

  final String role;
  final String content;
  final List<GatewayChatImagePart> images;

  Map<String, dynamic> toWireJson({required bool useMultimodal}) {
    if (useMultimodal && images.isNotEmpty) {
      return {
        'role': role,
        'content': [
          if (content.isNotEmpty) {'type': 'text', 'text': content},
          for (final img in images)
            {
              'type': 'image_url',
              'image_url': {'url': img.dataUri},
            },
        ],
      };
    }
    return {
      'role': role,
      'content': content,
    };
  }
}

@immutable
class ChatCompletionRequest {
  const ChatCompletionRequest({
    required this.model,
    required this.messages,
    this.stream = true,
    this.temperature,
    this.topP,
    this.maxTokens,
    this.stop,
    this.conversationId,
    this.idempotencyKey,
    this.useMultimodal = false,
  });

  final String model;
  final List<GatewayChatMessage> messages;
  final bool stream;
  final double? temperature;
  final double? topP;
  final int? maxTokens;
  final List<String>? stop;
  final String? conversationId;
  final String? idempotencyKey;
  final bool useMultimodal;

  Map<String, dynamic> toJson({bool? overrideMultimodal}) {
    final multimodal = overrideMultimodal ?? useMultimodal;
    return <String, dynamic>{
      'model': model,
      'messages': [
        for (final msg in messages) msg.toWireJson(useMultimodal: multimodal),
      ],
      'stream': stream,
      if (temperature != null) 'temperature': temperature,
      if (topP != null) 'top_p': topP,
      if (maxTokens != null && maxTokens! > 0) 'max_tokens': maxTokens,
      if (stop != null && stop!.isNotEmpty) 'stop': stop,
    };
  }
}

@immutable
class ChatStreamChunk {
  const ChatStreamChunk({
    this.contentDelta = '',
    this.reasoningDelta = '',
    this.finishReason,
    this.promptTokens,
    this.completionTokens,
    this.isDone = false,
  });

  final String contentDelta;
  final String reasoningDelta;
  final String? finishReason;
  final int? promptTokens;
  final int? completionTokens;
  final bool isDone;
}

@immutable
class HealthCheckResult {
  const HealthCheckResult({
    required this.isHealthy,
    required this.latencyMs,
    required this.modelCount,
    required this.summaryFa,
    this.opsLive,
  });

  final bool isHealthy;
  final int latencyMs;
  final int modelCount;
  final String summaryFa;
  final bool? opsLive;
}

@immutable
class StudioVisualResult {
  const StudioVisualResult({
    required this.usedNativeImagesEndpoint,
    this.rasterBytes,
    this.svgSource,
    this.revisedPrompt,
    this.noticeFa,
  });

  final bool usedNativeImagesEndpoint;
  final Uint8List? rasterBytes;
  final String? svgSource;
  final String? revisedPrompt;
  final String? noticeFa;
}
