import 'dart:convert';

import 'package:flutter/foundation.dart';

enum ChatRole {
  system,
  user,
  assistant;

  static ChatRole fromString(String value) {
    for (final role in ChatRole.values) {
      if (role.name == value) return role;
    }
    return ChatRole.user;
  }
}

enum MessageStatus {
  streaming,
  completed,
  stopped,
  error;

  static MessageStatus fromString(String value) {
    for (final s in MessageStatus.values) {
      if (s.name == value) return s;
    }
    return MessageStatus.completed;
  }
}

enum MessageFeedback {
  none,
  like,
  dislike;

  static MessageFeedback fromString(String value) {
    for (final f in MessageFeedback.values) {
      if (f.name == value) return f;
    }
    return MessageFeedback.none;
  }
}

enum AttachmentKind {
  image,
  document;

  static AttachmentKind fromString(String value) =>
      value == 'image' ? AttachmentKind.image : AttachmentKind.document;
}

@immutable
class ChatAttachment {
  const ChatAttachment({
    required this.id,
    required this.kind,
    required this.name,
    required this.localPath,
    required this.sizeBytes,
    this.mimeType = 'application/octet-stream',
    this.extractedText = '',
  });

  final String id;
  final AttachmentKind kind;
  final String name;
  final String localPath;
  final int sizeBytes;
  final String mimeType;
  final String extractedText;

  String get extension {
    final dot = name.lastIndexOf('.');
    if (dot < 0 || dot == name.length - 1) return '';
    return name.substring(dot + 1).toLowerCase();
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'kind': kind.name,
        'name': name,
        'localPath': localPath,
        'sizeBytes': sizeBytes,
        'mimeType': mimeType,
        'extractedText': extractedText,
      };

  factory ChatAttachment.fromJson(Map<String, dynamic> json) {
    return ChatAttachment(
      id: (json['id'] ?? '').toString(),
      kind: AttachmentKind.fromString((json['kind'] ?? 'document').toString()),
      name: (json['name'] ?? 'file').toString(),
      localPath: (json['localPath'] ?? '').toString(),
      sizeBytes: (json['sizeBytes'] as num?)?.toInt() ?? 0,
      mimeType: (json['mimeType'] ?? 'application/octet-stream').toString(),
      extractedText: (json['extractedText'] ?? '').toString(),
    );
  }
}

@immutable
class ChatArtifactRef {
  const ChatArtifactRef({
    required this.id,
    required this.title,
    required this.fileName,
    required this.extension,
    required this.content,
    this.savedFilePath,
    this.sizeBytes = 0,
    required this.createdAt,
  });

  final String id;
  final String title;
  final String fileName;
  final String extension;
  final String content;
  final String? savedFilePath;
  final int sizeBytes;
  final DateTime createdAt;

  bool get supportsHtmlPreview =>
      extension == 'html' || extension == 'htm' || extension == 'svg';

  ChatArtifactRef copyWith({
    String? savedFilePath,
    int? sizeBytes,
  }) {
    return ChatArtifactRef(
      id: id,
      title: title,
      fileName: fileName,
      extension: extension,
      content: content,
      savedFilePath: savedFilePath ?? this.savedFilePath,
      sizeBytes: sizeBytes ?? this.sizeBytes,
      createdAt: createdAt,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'fileName': fileName,
        'extension': extension,
        'content': content,
        'savedFilePath': savedFilePath,
        'sizeBytes': sizeBytes,
        'createdAt': createdAt.toIso8601String(),
      };

  factory ChatArtifactRef.fromJson(Map<String, dynamic> json) {
    return ChatArtifactRef(
      id: (json['id'] ?? '').toString(),
      title: (json['title'] ?? 'فایل').toString(),
      fileName: (json['fileName'] ?? 'artifact.txt').toString(),
      extension: (json['extension'] ?? 'txt').toString(),
      content: (json['content'] ?? '').toString(),
      savedFilePath: json['savedFilePath']?.toString(),
      sizeBytes: (json['sizeBytes'] as num?)?.toInt() ?? 0,
      createdAt: DateTime.tryParse((json['createdAt'] ?? '').toString()) ??
          DateTime.now(),
    );
  }
}

@immutable
class ChatConversation {
  const ChatConversation({
    required this.id,
    required this.title,
    required this.createdAt,
    required this.updatedAt,
    this.modelId,
    this.systemPrompt,
    this.isPinned = false,
    this.lastPreview = '',
  });

  final String id;
  final String title;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? modelId;
  final String? systemPrompt;
  final bool isPinned;
  final String lastPreview;

  ChatConversation copyWith({
    String? title,
    DateTime? updatedAt,
    String? modelId,
    String? systemPrompt,
    bool? isPinned,
    String? lastPreview,
  }) {
    return ChatConversation(
      id: id,
      title: title ?? this.title,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      modelId: modelId ?? this.modelId,
      systemPrompt: systemPrompt ?? this.systemPrompt,
      isPinned: isPinned ?? this.isPinned,
      lastPreview: lastPreview ?? this.lastPreview,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'title': title,
        'model_id': modelId,
        'system_prompt': systemPrompt,
        'is_pinned': isPinned ? 1 : 0,
        'last_preview': lastPreview,
        'created_at': createdAt.millisecondsSinceEpoch,
        'updated_at': updatedAt.millisecondsSinceEpoch,
      };

  factory ChatConversation.fromMap(Map<String, dynamic> map) {
    return ChatConversation(
      id: (map['id'] ?? '').toString(),
      title: (map['title'] ?? 'گفتگوی جدید').toString(),
      modelId: map['model_id']?.toString(),
      systemPrompt: map['system_prompt']?.toString(),
      isPinned: (map['is_pinned'] as int? ?? 0) == 1,
      lastPreview: (map['last_preview'] ?? '').toString(),
      createdAt: DateTime.fromMillisecondsSinceEpoch(
        (map['created_at'] as num?)?.toInt() ?? 0,
      ),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(
        (map['updated_at'] as num?)?.toInt() ?? 0,
      ),
    );
  }
}

@immutable
class ChatMessageEntity {
  const ChatMessageEntity({
    required this.id,
    required this.conversationId,
    required this.role,
    required this.content,
    required this.createdAt,
    required this.sequence,
    this.reasoningContent = '',
    this.reasoningDurationMs = 0,
    this.modelId,
    this.status = MessageStatus.completed,
    this.feedback = MessageFeedback.none,
    this.attachments = const [],
    this.artifacts = const [],
    this.errorMessage,
    this.isArtifactBuilding = false,
  });

  final String id;
  final String conversationId;
  final ChatRole role;
  final String content;
  final DateTime createdAt;
  final int sequence;
  final String reasoningContent;
  final int reasoningDurationMs;
  final String? modelId;
  final MessageStatus status;
  final MessageFeedback feedback;
  final List<ChatAttachment> attachments;
  final List<ChatArtifactRef> artifacts;
  final String? errorMessage;
  final bool isArtifactBuilding;

  ChatMessageEntity copyWith({
    String? content,
    String? reasoningContent,
    int? reasoningDurationMs,
    String? modelId,
    MessageStatus? status,
    MessageFeedback? feedback,
    List<ChatAttachment>? attachments,
    List<ChatArtifactRef>? artifacts,
    String? errorMessage,
    bool clearError = false,
    bool? isArtifactBuilding,
  }) {
    return ChatMessageEntity(
      id: id,
      conversationId: conversationId,
      role: role,
      content: content ?? this.content,
      createdAt: createdAt,
      sequence: sequence,
      reasoningContent: reasoningContent ?? this.reasoningContent,
      reasoningDurationMs: reasoningDurationMs ?? this.reasoningDurationMs,
      modelId: modelId ?? this.modelId,
      status: status ?? this.status,
      feedback: feedback ?? this.feedback,
      attachments: attachments ?? this.attachments,
      artifacts: artifacts ?? this.artifacts,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      isArtifactBuilding: isArtifactBuilding ?? this.isArtifactBuilding,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'conversation_id': conversationId,
        'role': role.name,
        'content': content,
        'reasoning_content': reasoningContent,
        'reasoning_duration_ms': reasoningDurationMs,
        'model_id': modelId,
        'status': status.name,
        'feedback': feedback.name,
        'attachments_json':
            jsonEncode([for (final a in attachments) a.toJson()]),
        'artifacts_json': jsonEncode([for (final a in artifacts) a.toJson()]),
        'error_message': errorMessage,
        'created_at': createdAt.millisecondsSinceEpoch,
        'sequence': sequence,
      };

  factory ChatMessageEntity.fromMap(Map<String, dynamic> map) {
    final attachmentsRaw = (map['attachments_json'] ?? '[]').toString();
    final artifactsRaw = (map['artifacts_json'] ?? '[]').toString();

    final parsedAttachments = <ChatAttachment>[];
    try {
      final list = jsonDecode(attachmentsRaw);
      if (list is List) {
        for (final item in list.whereType<Map<String, dynamic>>()) {
          parsedAttachments.add(ChatAttachment.fromJson(item));
        }
      }
    } catch (_) {
      // Ignore malformed legacy attachment metadata
    }

    final parsedArtifacts = <ChatArtifactRef>[];
    try {
      final list = jsonDecode(artifactsRaw);
      if (list is List) {
        for (final item in list.whereType<Map<String, dynamic>>()) {
          parsedArtifacts.add(ChatArtifactRef.fromJson(item));
        }
      }
    } catch (_) {
      // Ignore malformed legacy artifact metadata
    }

    return ChatMessageEntity(
      id: (map['id'] ?? '').toString(),
      conversationId: (map['conversation_id'] ?? '').toString(),
      role: ChatRole.fromString((map['role'] ?? 'user').toString()),
      content: (map['content'] ?? '').toString(),
      reasoningContent: (map['reasoning_content'] ?? '').toString(),
      reasoningDurationMs: (map['reasoning_duration_ms'] as num?)?.toInt() ?? 0,
      modelId: map['model_id']?.toString(),
      status: MessageStatus.fromString((map['status'] ?? 'completed').toString()),
      feedback: MessageFeedback.fromString((map['feedback'] ?? 'none').toString()),
      attachments: parsedAttachments,
      artifacts: parsedArtifacts,
      errorMessage: map['error_message']?.toString(),
      createdAt: DateTime.fromMillisecondsSinceEpoch(
        (map['created_at'] as num?)?.toInt() ?? 0,
      ),
      sequence: (map['sequence'] as num?)?.toInt() ?? 0,
    );
  }
}
