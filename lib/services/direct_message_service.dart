import '../models/direct_message.dart';
import '../models/message_history_page.dart';

/// App-owned operations required by the direct-message UI.
///
/// This keeps the page independent from the shared package's legacy
/// `DmService` contract while the message model and storage adapters migrate.
abstract interface class DirectMessageService {
  Stream<DirectMessage> get directMessageStream;

  Future<List<DirectMessage>> loadConversation(
    int selfId,
    int friendId, {
    MessageHistoryCursor? before,
  });

  Future<MessageHistoryPage<DirectMessage>> loadConversationPage(
    int selfId,
    int friendId, {
    MessageHistoryCursor? before,
  });

  Future<List<DirectMessage>> refreshConversation(int selfId, int friendId);

  Future<void> sendText(int friendId, String text);

  Future<void> editProjectedMessage(String messageId, String text);

  Future<void> recallProjectedMessage(String messageId);

  Future<void> markProjectedMessageRead(String messageId);

  Future<void> connectToDm(int selfId, int friendId, {bool isCaller = true});

  void disconnect();
}
