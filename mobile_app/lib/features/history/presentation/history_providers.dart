import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../chat/domain/chat_models.dart';

final historySearchQueryProvider = StateProvider<String>((ref) => '');

final conversationsHistoryProvider =
    FutureProvider<List<ChatConversation>>((ref) async {
  final query = ref.watch(historySearchQueryProvider);
  final db = ref.watch(appDatabaseProvider);
  return db.listConversations(query: query);
});
