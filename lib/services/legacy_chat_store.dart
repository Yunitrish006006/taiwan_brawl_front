import '../models/chat_models.dart';

/// Compatibility storage port for conversations that have not migrated to
/// shared event projections yet. Application services depend on this port;
/// Hive is only one legacy adapter.
abstract interface class LegacyChatStore {
  Future<void> saveMessage(int selfId, ChatMessage message);

  Future<void> markDelivered(
    int selfId,
    int friendId,
    String createdAt,
    int senderId,
  );

  Future<void> markRecalled(int selfId, int friendId, String messageKey);

  Future<void> updateMessageText(
    int selfId,
    int friendId,
    String messageKey,
    String text,
  );

  Future<List<ChatMessage>> getMessages(int selfId, int friendId);

  Future<ChatMessage?> getMessage(int selfId, int friendId, String messageKey);

  Future<void> deleteMessage(
    int selfId,
    int friendId,
    String createdAt,
    int senderId,
  );

  Future<void> clearMessages(int selfId, int friendId);

  Future<Map<String, Map<String, String>>> exportAll(
    int selfId,
    List<int> friendIds,
  );

  Future<void> importAll(Map<String, dynamic> data);

  Future<void> closeAll();
}
