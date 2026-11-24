import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import '../../features/chat/domain/chat_models.dart';

final appDatabaseProvider = Provider<AppDatabase>((ref) {
  return AppDatabase();
});

/// Local SQLite persistence for conversations, messages, artifacts, full-text
/// search, message branching, and JSON backup/restore.
class AppDatabase {
  Database? _db;

  Future<Database> get database async {
    if (_db != null) return _db!;
    final dbDir = await getDatabasesPath();
    final dbPath = p.join(dbDir, 'orbi_ai.db');
    _db = await openDatabase(
      dbPath,
      version: 1,
      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys = ON');
      },
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE conversations (
            id TEXT PRIMARY KEY,
            title TEXT NOT NULL,
            model_id TEXT,
            system_prompt TEXT,
            is_pinned INTEGER NOT NULL DEFAULT 0,
            last_preview TEXT NOT NULL DEFAULT '',
            created_at INTEGER NOT NULL,
            updated_at INTEGER NOT NULL
          )
        ''');

        await db.execute('''
          CREATE TABLE messages (
            id TEXT PRIMARY KEY,
            conversation_id TEXT NOT NULL,
            role TEXT NOT NULL,
            content TEXT NOT NULL,
            reasoning_content TEXT NOT NULL DEFAULT '',
            reasoning_duration_ms INTEGER NOT NULL DEFAULT 0,
            model_id TEXT,
            status TEXT NOT NULL,
            feedback TEXT NOT NULL DEFAULT 'none',
            attachments_json TEXT NOT NULL DEFAULT '[]',
            artifacts_json TEXT NOT NULL DEFAULT '[]',
            error_message TEXT,
            created_at INTEGER NOT NULL,
            sequence INTEGER NOT NULL,
            FOREIGN KEY (conversation_id) REFERENCES conversations(id) ON DELETE CASCADE
          )
        ''');

        await db.execute('''
          CREATE TABLE artifacts (
            id TEXT PRIMARY KEY,
            conversation_id TEXT NOT NULL,
            message_id TEXT NOT NULL,
            title TEXT NOT NULL,
            file_name TEXT NOT NULL,
            extension TEXT NOT NULL,
            content TEXT NOT NULL,
            saved_file_path TEXT,
            size_bytes INTEGER NOT NULL DEFAULT 0,
            created_at INTEGER NOT NULL
          )
        ''');

        await db.execute(
          'CREATE INDEX idx_messages_conv_seq ON messages(conversation_id, sequence)',
        );
        await db.execute(
          'CREATE INDEX idx_conv_pinned_updated ON conversations(is_pinned DESC, updated_at DESC)',
        );
      },
    );
    return _db!;
  }

  Future<List<ChatConversation>> listConversations({String query = ''}) async {
    final db = await database;
    final trimmed = query.trim();
    if (trimmed.isEmpty) {
      final rows = await db.query(
        'conversations',
        orderBy: 'is_pinned DESC, updated_at DESC',
      );
      return rows.map(ChatConversation.fromMap).toList(growable: false);
    }

    final like = '%$trimmed%';
    final rows = await db.rawQuery(
      '''
      SELECT DISTINCT c.*
      FROM conversations c
      LEFT JOIN messages m ON m.conversation_id = c.id
      WHERE c.title LIKE ? OR c.last_preview LIKE ? OR m.content LIKE ?
      ORDER BY c.is_pinned DESC, c.updated_at DESC
      ''',
      [like, like, like],
    );
    return rows.map(ChatConversation.fromMap).toList(growable: false);
  }

  Future<void> upsertConversation(ChatConversation conversation) async {
    final db = await database;
    await db.insert(
      'conversations',
      conversation.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> deleteConversation(String conversationId) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.delete(
        'artifacts',
        where: 'conversation_id = ?',
        whereArgs: [conversationId],
      );
      await txn.delete(
        'conversations',
        where: 'id = ?',
        whereArgs: [conversationId],
      );
    });
  }

  Future<List<ChatMessageEntity>> getMessages(String conversationId) async {
    final db = await database;
    final rows = await db.query(
      'messages',
      where: 'conversation_id = ?',
      whereArgs: [conversationId],
      orderBy: 'sequence ASC, created_at ASC',
    );
    return rows.map(ChatMessageEntity.fromMap).toList(growable: false);
  }

  Future<void> upsertMessage(ChatMessageEntity message) async {
    final db = await database;
    await db.insert(
      'messages',
      message.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Removes all messages strictly after [sequence] in [conversationId] for
  /// clean message editing & branching without corrupting order.
  Future<void> deleteMessagesAfterSequence(
    String conversationId,
    int sequence,
  ) async {
    final db = await database;
    await db.delete(
      'messages',
      where: 'conversation_id = ? AND sequence > ?',
      whereArgs: [conversationId, sequence],
    );
  }

  Future<void> saveArtifact({
    required String conversationId,
    required String messageId,
    required ChatArtifactRef artifact,
  }) async {
    final db = await database;
    await db.insert(
      'artifacts',
      {
        'id': artifact.id,
        'conversation_id': conversationId,
        'message_id': messageId,
        'title': artifact.title,
        'file_name': artifact.fileName,
        'extension': artifact.extension,
        'content': artifact.content,
        'saved_file_path': artifact.savedFilePath,
        'size_bytes': artifact.sizeBytes,
        'created_at': artifact.createdAt.millisecondsSinceEpoch,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<ChatArtifactRef>> listArtifacts() async {
    final db = await database;
    final rows = await db.query(
      'artifacts',
      orderBy: 'created_at DESC',
    );
    return rows
        .map(
          (row) => ChatArtifactRef(
            id: (row['id'] ?? '').toString(),
            title: (row['title'] ?? 'فایل').toString(),
            fileName: (row['file_name'] ?? 'file.txt').toString(),
            extension: (row['extension'] ?? 'txt').toString(),
            content: (row['content'] ?? '').toString(),
            savedFilePath: row['saved_file_path']?.toString(),
            sizeBytes: (row['size_bytes'] as num?)?.toInt() ?? 0,
            createdAt: DateTime.fromMillisecondsSinceEpoch(
              (row['created_at'] as num?)?.toInt() ?? 0,
            ),
          ),
        )
        .toList(growable: false);
  }

  Future<void> deleteArtifact(String id) async {
    final db = await database;
    await db.delete('artifacts', where: 'id = ?', whereArgs: [id]);
  }

  Future<String> exportBackupJson() async {
    final db = await database;
    final conversations = await db.query('conversations');
    final messages = await db.query('messages');
    final artifacts = await db.query('artifacts');
    return const JsonEncoder.withIndent('  ').convert({
      'schema_version': 1,
      'exported_at': DateTime.now().toIso8601String(),
      'conversations': conversations,
      'messages': messages,
      'artifacts': artifacts,
    });
  }

  Future<int> importBackupJson(String rawJson) async {
    final decoded = jsonDecode(rawJson);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('فایل پشتیبان معتبر نیست.');
    }
    final conversations =
        (decoded['conversations'] as List?)?.whereType<Map<String, dynamic>>() ??
            const [];
    final messages =
        (decoded['messages'] as List?)?.whereType<Map<String, dynamic>>() ??
            const [];
    final artifacts =
        (decoded['artifacts'] as List?)?.whereType<Map<String, dynamic>>() ??
            const [];

    final db = await database;
    var count = 0;
    await db.transaction((txn) async {
      for (final c in conversations) {
        await txn.insert(
          'conversations',
          c,
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
        count++;
      }
      for (final m in messages) {
        await txn.insert(
          'messages',
          m,
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
      for (final a in artifacts) {
        await txn.insert(
          'artifacts',
          a,
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
    });
    return count;
  }
}
