import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:uuid/uuid.dart';

import '../../../core/database/app_database.dart';
import '../../../core/network/gateway_error.dart';
import '../../../core/utils/thinking_parser.dart';
import '../../artifacts/artifact_service.dart';
import '../../gateway/domain/gateway_models.dart';
import '../../gateway/presentation/gateway_providers.dart';
import '../../history/presentation/history_providers.dart';
import '../domain/chat_models.dart';

@immutable
class StreamingBubbleState {
  const StreamingBubbleState({
    this.message,
    this.isThinkingOpen = false,
  });

  final ChatMessageEntity? message;
  final bool isThinkingOpen;

  bool get isActive => message != null;
}

class StreamingBubbleNotifier extends Notifier<StreamingBubbleState> {
  @override
  StreamingBubbleState build() => const StreamingBubbleState();

  void setBubble(ChatMessageEntity? message, {bool isThinkingOpen = false}) {
    state = StreamingBubbleState(
      message: message,
      isThinkingOpen: isThinkingOpen,
    );
  }

  void clear() {
    state = const StreamingBubbleState();
  }
}

final streamingBubbleProvider =
    NotifierProvider<StreamingBubbleNotifier, StreamingBubbleState>(
  StreamingBubbleNotifier.new,
);

@immutable
class ChatSessionState {
  const ChatSessionState({
    this.conversationId,
    this.conversationTitle = 'گفتگوی جدید',
    this.messages = const [],
    this.isGhostMode = false,
    this.isStreaming = false,
    this.fileBuilderMode = false,
    this.activeSpeakingMessageId,
    this.customSystemPersona,
  });

  final String? conversationId;
  final String conversationTitle;
  final List<ChatMessageEntity> messages;
  final bool isGhostMode;
  final bool isStreaming;
  final bool fileBuilderMode;
  final String? activeSpeakingMessageId;
  final String? customSystemPersona;

  ChatSessionState copyWith({
    String? conversationId,
    bool clearConversationId = false,
    String? conversationTitle,
    List<ChatMessageEntity>? messages,
    bool? isGhostMode,
    bool? isStreaming,
    bool? fileBuilderMode,
    String? activeSpeakingMessageId,
    bool clearSpeakingId = false,
    String? customSystemPersona,
    bool clearPersona = false,
  }) {
    return ChatSessionState(
      conversationId:
          clearConversationId ? null : (conversationId ?? this.conversationId),
      conversationTitle: conversationTitle ?? this.conversationTitle,
      messages: messages ?? this.messages,
      isGhostMode: isGhostMode ?? this.isGhostMode,
      isStreaming: isStreaming ?? this.isStreaming,
      fileBuilderMode: fileBuilderMode ?? this.fileBuilderMode,
      activeSpeakingMessageId: clearSpeakingId
          ? null
          : (activeSpeakingMessageId ?? this.activeSpeakingMessageId),
      customSystemPersona: clearPersona
          ? null
          : (customSystemPersona ?? this.customSystemPersona),
    );
  }
}

class ChatController extends Notifier<ChatSessionState> {
  static const _uuid = Uuid();

  CancelToken? _activeCancelToken;
  Timer? _thinkingTimer;
  final FlutterTts _tts = FlutterTts();
  bool _ttsInitialized = false;

  @override
  ChatSessionState build() {
    ref.onDispose(() {
      _activeCancelToken?.cancel();
      _thinkingTimer?.cancel();
      _tts.stop();
    });
    return const ChatSessionState();
  }

  Future<void> startNewChat({bool ghostMode = false}) async {
    await stopStreaming();
    await stopTts();
    ref.read(streamingBubbleProvider.notifier).clear();
    state = ChatSessionState(
      isGhostMode: ghostMode,
      customSystemPersona: state.customSystemPersona,
    );
  }

  Future<void> toggleGhostMode() async {
    final nextGhost = !state.isGhostMode;
    await startNewChat(ghostMode: nextGhost);
  }

  void setFileBuilderMode(bool enabled) {
    state = state.copyWith(fileBuilderMode: enabled);
  }

  void setPersona(String? persona) {
    state = state.copyWith(
      customSystemPersona: persona,
      clearPersona: persona == null,
    );
  }

  Future<void> loadConversation(String conversationId) async {
    await stopStreaming();
    await stopTts();
    ref.read(streamingBubbleProvider.notifier).clear();

    final db = ref.read(appDatabaseProvider);
    final convs = await db.listConversations();
    final target = convs.where((c) => c.id == conversationId).firstOrNull;
    final msgs = await db.getMessages(conversationId);

    state = ChatSessionState(
      conversationId: conversationId,
      conversationTitle: target?.title ?? 'گفتگو',
      messages: msgs,
      isGhostMode: false,
      customSystemPersona: target?.systemPrompt,
    );
  }

  Future<void> sendUserMessage(
    String rawText, {
    List<ChatAttachment> attachments = const [],
    bool? overrideFileMode,
  }) async {
    final trimmed = rawText.trim();
    if (trimmed.isEmpty && attachments.isEmpty) return;
    if (state.isStreaming) return;

    final fileMode = overrideFileMode ?? state.fileBuilderMode;
    final gatewayConfig = ref.read(gatewayConfigProvider);
    final modelId = gatewayConfig.selectedModel?.id;
    if (modelId == null || modelId.isEmpty) {
      if (!gatewayConfig.isSyncingModels) {
        await ref.read(gatewayConfigProvider.notifier).syncModels();
      }
      final refreshedModel = ref.read(gatewayConfigProvider).selectedModel?.id;
      if (refreshedModel == null || refreshedModel.isEmpty) {
        final convId = state.conversationId ?? _uuid.v4();
        final now = DateTime.now();
        final errMsg = ChatMessageEntity(
          id: _uuid.v4(),
          conversationId: convId,
          role: ChatRole.assistant,
          content: '',
          createdAt: now,
          sequence: state.messages.length + 1,
          status: MessageStatus.error,
          errorMessage:
              'هنوز هیچ مدلی از سرور Gateway دریافت نشده است. از بخش تنظیمات اتصال به سرور را بررسی و مدل‌ها را همگام‌سازی کنید.',
        );
        state = state.copyWith(
          conversationId: convId,
          messages: [...state.messages, errMsg],
        );
        return;
      }
    }

    final activeModelId = ref.read(gatewayConfigProvider).selectedModel!.id;
    final isNewConv = state.conversationId == null;
    final convId = state.conversationId ?? _uuid.v4();
    final now = DateTime.now();
    final title = isNewConv
        ? _deriveTitle(trimmed.isNotEmpty ? trimmed : attachments.first.name)
        : state.conversationTitle;

    final userMessage = ChatMessageEntity(
      id: _uuid.v4(),
      conversationId: convId,
      role: ChatRole.user,
      content: trimmed.isNotEmpty
          ? trimmed
          : 'فایل پیوست‌شده را تحلیل کن.',
      createdAt: now,
      sequence: state.messages.length + 1,
      attachments: attachments,
      status: MessageStatus.completed,
    );

    final updatedMessages = [...state.messages, userMessage];
    state = state.copyWith(
      conversationId: convId,
      conversationTitle: title,
      messages: updatedMessages,
    );

    if (!state.isGhostMode) {
      final db = ref.read(appDatabaseProvider);
      await db.upsertConversation(
        ChatConversation(
          id: convId,
          title: title,
          modelId: activeModelId,
          systemPrompt: state.customSystemPersona,
          createdAt: now,
          updatedAt: now,
          lastPreview: userMessage.content,
        ),
      );
      await db.upsertMessage(userMessage);
      ref.invalidate(conversationsHistoryProvider);
    }

    await _streamAssistantReply(
      conversationId: convId,
      title: title,
      historyBeforeAssistant: updatedMessages,
      modelId: activeModelId,
      fileMode: fileMode,
    );
  }

  Future<void> regenerateFromAssistant(String assistantMessageId) async {
    if (state.isStreaming) return;
    final idx = state.messages.indexWhere((m) => m.id == assistantMessageId);
    if (idx <= 0) return;

    final target = state.messages[idx];
    final prevUser = state.messages[idx - 1];
    final kept = state.messages.sublist(0, idx);

    state = state.copyWith(messages: kept);
    if (!state.isGhostMode && state.conversationId != null) {
      await ref.read(appDatabaseProvider).deleteMessagesAfterSequence(
            state.conversationId!,
            prevUser.sequence,
          );
    }

    final modelId =
        ref.read(gatewayConfigProvider).selectedModel?.id ?? target.modelId;
    if (modelId == null || modelId.isEmpty) return;

    await _streamAssistantReply(
      conversationId: state.conversationId!,
      title: state.conversationTitle,
      historyBeforeAssistant: kept,
      modelId: modelId,
      fileMode: state.fileBuilderMode,
    );
  }

  Future<void> editAndBranchUserMessage(
    String userMessageId,
    String updatedText,
  ) async {
    if (state.isStreaming) return;
    final cleaned = updatedText.trim();
    if (cleaned.isEmpty) return;

    final idx = state.messages.indexWhere((m) => m.id == userMessageId);
    if (idx < 0) return;

    final original = state.messages[idx];
    final edited = original.copyWith(content: cleaned);
    final truncated = [...state.messages.sublist(0, idx), edited];

    state = state.copyWith(messages: truncated);
    if (!state.isGhostMode && state.conversationId != null) {
      final db = ref.read(appDatabaseProvider);
      await db.upsertMessage(edited);
      await db.deleteMessagesAfterSequence(
        state.conversationId!,
        edited.sequence,
      );
    }

    final modelId = ref.read(gatewayConfigProvider).selectedModel?.id;
    if (modelId == null || modelId.isEmpty) return;

    await _streamAssistantReply(
      conversationId: state.conversationId!,
      title: state.conversationTitle,
      historyBeforeAssistant: truncated,
      modelId: modelId,
      fileMode: state.fileBuilderMode,
    );
  }

  Future<void> _streamAssistantReply({
    required String conversationId,
    required String title,
    required List<ChatMessageEntity> historyBeforeAssistant,
    required String modelId,
    required bool fileMode,
  }) async {
    final config = ref.read(gatewayConfigProvider);
    final cancelToken = CancelToken();
    _activeCancelToken = cancelToken;

    final assistantId = _uuid.v4();
    final seq = historyBeforeAssistant.length + 1;
    final startedAt = DateTime.now();

    var streamingMsg = ChatMessageEntity(
      id: assistantId,
      conversationId: conversationId,
      role: ChatRole.assistant,
      content: '',
      createdAt: startedAt,
      sequence: seq,
      modelId: modelId,
      status: MessageStatus.streaming,
      isArtifactBuilding: fileMode,
    );

    state = state.copyWith(isStreaming: true);
    ref.read(streamingBubbleProvider.notifier).setBubble(streamingMsg);

    final rawContentBuf = StringBuffer();
    final explicitReasoningBuf = StringBuffer();
    final thinkingWatch = Stopwatch();
    var wasThinkingOpen = false;

    _thinkingTimer?.cancel();
    _thinkingTimer = Timer.periodic(const Duration(milliseconds: 150), (_) {
      if (!thinkingWatch.isRunning) return;
      streamingMsg = streamingMsg.copyWith(
        reasoningDurationMs: thinkingWatch.elapsedMilliseconds,
      );
      ref
          .read(streamingBubbleProvider.notifier)
          .setBubble(streamingMsg, isThinkingOpen: wasThinkingOpen);
    });

    final wireMessages = await _buildWireMessages(
      historyBeforeAssistant: historyBeforeAssistant,
      systemPrompt: state.customSystemPersona ?? config.systemPrompt,
      fileMode: fileMode,
      useMultimodal: config.multimodalVision,
    );

    final request = ChatCompletionRequest(
      model: modelId,
      messages: wireMessages,
      stream: true,
      temperature: config.temperature,
      maxTokens: config.maxTokens,
      conversationId: state.isGhostMode ? null : conversationId,
      idempotencyKey: _uuid.v4(),
      useMultimodal: config.multimodalVision,
    );

    MessageStatus finalStatus = MessageStatus.completed;
    String? errorMessage;

    try {
      final stream = ref.read(gatewayRepositoryProvider).streamChat(
            config.baseUrl,
            request,
            cancelToken: cancelToken,
          );

      await for (final chunk in stream) {
        if (cancelToken.isCancelled) {
          finalStatus = MessageStatus.stopped;
          break;
        }
        if (chunk.reasoningDelta.isNotEmpty) {
          if (!thinkingWatch.isRunning) thinkingWatch.start();
          explicitReasoningBuf.write(chunk.reasoningDelta);
        }
        if (chunk.contentDelta.isNotEmpty) {
          rawContentBuf.write(chunk.contentDelta);
        }

        final split = ThinkingParser.parse(
          rawContentBuf.toString(),
          explicitReasoning: explicitReasoningBuf.toString(),
        );

        if (split.isThinkingOpen || chunk.reasoningDelta.isNotEmpty) {
          if (!thinkingWatch.isRunning) thinkingWatch.start();
          wasThinkingOpen =
              split.isThinkingOpen || split.visibleContent.isEmpty;
        } else {
          if (thinkingWatch.isRunning && split.visibleContent.isNotEmpty) {
            thinkingWatch.stop();
          }
          wasThinkingOpen = false;
        }

        final hasOpenFence = _hasUnclosedArtifactFence(split.visibleContent);

        streamingMsg = streamingMsg.copyWith(
          content: split.visibleContent,
          reasoningContent: split.thinkingContent,
          reasoningDurationMs: thinkingWatch.elapsedMilliseconds,
          isArtifactBuilding: fileMode || hasOpenFence,
        );
        ref
            .read(streamingBubbleProvider.notifier)
            .setBubble(streamingMsg, isThinkingOpen: wasThinkingOpen);
      }
    } on GatewayException catch (e) {
      if (e.isCancelled) {
        finalStatus = MessageStatus.stopped;
      } else {
        finalStatus = MessageStatus.error;
        errorMessage = e.messageFa;
      }
    } catch (e) {
      if (cancelToken.isCancelled) {
        finalStatus = MessageStatus.stopped;
      } else {
        finalStatus = MessageStatus.error;
        errorMessage = 'خطای غیرمنتظره هنگام دریافت پاسخ: $e';
      }
    } finally {
      _thinkingTimer?.cancel();
      if (thinkingWatch.isRunning) thinkingWatch.stop();
      _activeCancelToken = null;
    }

    final finalSplit = ThinkingParser.parse(
      rawContentBuf.toString(),
      explicitReasoning: explicitReasoningBuf.toString(),
    );

    final artifactService = ref.read(artifactServiceProvider);
    var builtArtifacts = const <ChatArtifactRef>[];
    if (finalSplit.visibleContent.isNotEmpty &&
        finalStatus != MessageStatus.error) {
      final extracted = artifactService.extractArtifactsFromContent(
        finalSplit.visibleContent,
        forceDocumentArtifact: fileMode,
      );
      if (extracted.isNotEmpty) {
        final persisted = <ChatArtifactRef>[];
        for (final art in extracted) {
          persisted.add(
            await artifactService.persistArtifact(
              conversationId: conversationId,
              messageId: assistantId,
              artifact: art,
              saveToDb: !state.isGhostMode,
            ),
          );
        }
        builtArtifacts = persisted;
      }
    }

    final finalMessage = streamingMsg.copyWith(
      content: finalSplit.visibleContent,
      reasoningContent: finalSplit.thinkingContent,
      reasoningDurationMs: thinkingWatch.elapsedMilliseconds,
      status: finalStatus,
      errorMessage: errorMessage,
      artifacts: builtArtifacts,
      isArtifactBuilding: false,
    );

    ref.read(streamingBubbleProvider.notifier).clear();
    state = state.copyWith(
      messages: [...historyBeforeAssistant, finalMessage],
      isStreaming: false,
      fileBuilderMode: false,
    );

    if (!state.isGhostMode) {
      final db = ref.read(appDatabaseProvider);
      await db.upsertMessage(finalMessage);
      final preview = finalMessage.content.isNotEmpty
          ? finalMessage.content
          : (finalMessage.errorMessage ?? '');
      await db.upsertConversation(
        ChatConversation(
          id: conversationId,
          title: title,
          modelId: modelId,
          systemPrompt: state.customSystemPersona,
          createdAt: historyBeforeAssistant.first.createdAt,
          updatedAt: DateTime.now(),
          lastPreview: preview.length > 140 ? preview.substring(0, 140) : preview,
        ),
      );
      ref.invalidate(conversationsHistoryProvider);
    }
  }

  Future<void> stopStreaming() async {
    if (_activeCancelToken != null && !_activeCancelToken!.isCancelled) {
      _activeCancelToken!.cancel('User stopped streaming');
    }
  }

  Future<void> setFeedback(String messageId, MessageFeedback feedback) async {
    final updated = [
      for (final m in state.messages)
        if (m.id == messageId) m.copyWith(feedback: feedback) else m,
    ];
    state = state.copyWith(messages: updated);
    if (!state.isGhostMode) {
      final target = updated.where((m) => m.id == messageId).firstOrNull;
      if (target != null) {
        await ref.read(appDatabaseProvider).upsertMessage(target);
      }
    }
  }

  Future<void> toggleTts(ChatMessageEntity message) async {
    if (state.activeSpeakingMessageId == message.id) {
      await stopTts();
      return;
    }

    await stopTts();
    if (!_ttsInitialized) {
      _tts.setCompletionHandler(() {
        state = state.copyWith(clearSpeakingId: true);
      });
      _tts.setCancelHandler(() {
        state = state.copyWith(clearSpeakingId: true);
      });
      _tts.setErrorHandler((_) {
        state = state.copyWith(clearSpeakingId: true);
      });
      _ttsInitialized = true;
    }

    final cleanSpeech = message.content
        .replaceAll(RegExp(r'```[\s\S]*?```'), ' قطعه کد ')
        .replaceAll(RegExp(r'[#*`_>\[\]()]'), ' ')
        .trim();
    if (cleanSpeech.isEmpty) return;

    final hasPersian = RegExp(r'[\u0600-\u06FF]').hasMatch(cleanSpeech);
    await _tts.setLanguage(hasPersian ? 'fa-IR' : 'en-US');
    await _tts.setSpeechRate(0.5);
    state = state.copyWith(activeSpeakingMessageId: message.id);
    await _tts.speak(cleanSpeech);
  }

  Future<void> stopTts() async {
    await _tts.stop();
    if (state.activeSpeakingMessageId != null) {
      state = state.copyWith(clearSpeakingId: true);
    }
  }

  Future<List<GatewayChatMessage>> _buildWireMessages({
    required List<ChatMessageEntity> historyBeforeAssistant,
    required String systemPrompt,
    required bool fileMode,
    required bool useMultimodal,
  }) async {
    final effectiveSystem = fileMode
        ? '$systemPrompt\n\nکاربر حالت «فایل‌ساز و سندساز هوشمند» را فعال کرده است. '
            'خروجی را بسیار ساختاریافته و آماده دانلود تولید کن؛ در صورت درخواست صفحه وب، SVG، جدول CSV، JSON یا کد، آن را در یک بلوک کد مشخص (```html / ```svg / ```csv / ```json / ```md) ارائه بده.'
        : systemPrompt;

    final out = <GatewayChatMessage>[
      GatewayChatMessage(role: 'system', content: effectiveSystem),
    ];

    for (final msg in historyBeforeAssistant) {
      if (msg.role == ChatRole.assistant && msg.content.trim().isEmpty) {
        continue;
      }
      final imageParts = <GatewayChatImagePart>[];
      final buffer = StringBuffer(msg.content);

      for (final att in msg.attachments) {
        if (att.kind == AttachmentKind.document) {
          if (att.extractedText.isNotEmpty) {
            buffer.write(
              '\n\n--- محتوای فایل پیوست‌شده (${att.name}) ---\n${att.extractedText}',
            );
          } else {
            buffer.write('\n\n[فایل پیوست‌شده: ${att.name}]');
          }
        } else if (att.kind == AttachmentKind.image) {
          if (useMultimodal) {
            final file = File(att.localPath);
            if (await file.exists()) {
              final bytes = await file.readAsBytes();
              imageParts.add(
                GatewayChatImagePart(
                  base64Data: base64Encode(bytes),
                  mimeType: att.mimeType,
                ),
              );
            }
          } else {
            buffer.write(
              '\n\n[تصویر پیوست‌شده توسط کاربر: ${att.name} — توجه: سرور فعلی فقط ورودی متنی را می‌پذیرد مگر حالت Multimodal Vision در تنظیمات فعال و در سرور پشتیبانی شود.]',
            );
          }
        }
      }

      out.add(
        GatewayChatMessage(
          role: msg.role.name,
          content: buffer.toString(),
          images: imageParts,
        ),
      );
    }

    return out;
  }

  static bool _hasUnclosedArtifactFence(String text) {
    final matches = RegExp(r'```(html|svg|csv|json|md)').allMatches(text).length;
    final allFences = RegExp(r'```').allMatches(text).length;
    return matches > 0 && allFences.isOdd;
  }

  static String _deriveTitle(String seed) {
    final singleLine = seed.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (singleLine.length <= 42) return singleLine;
    return '${singleLine.substring(0, 42)}…';
  }
}

final chatControllerProvider =
    NotifierProvider<ChatController, ChatSessionState>(ChatController.new);
