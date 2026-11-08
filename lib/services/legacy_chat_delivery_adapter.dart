import '../models/legacy_chat_record.dart';
import 'package:taiwan_brawl_messaging/taiwan_brawl_messaging.dart'
    show MessageProjection;
import 'legacy_chat_remote_source.dart';
import 'legacy_chat_store.dart';

/// Performs the remaining legacy HTTP delivery operations and cache writes.
class LegacyChatDeliveryAdapter {
  const LegacyChatDeliveryAdapter({
    required LegacyChatDeliveryStore localRepository,
    required LegacyChatDeliveryRemoteSource remoteSource,
  }) : _localRepository = localRepository,
       _remoteSource = remoteSource;

  final LegacyChatDeliveryStore _localRepository;
  final LegacyChatDeliveryRemoteSource _remoteSource;

  Future<void> sendText(
    int receiverId,
    String text, {
    int? selfId,
    String? fallbackCreatedAt,
    bool persistLegacyCopy = false,
  }) async {
    final response = await _remoteSource.sendMessage(receiverId, text);
    if (!persistLegacyCopy || selfId == null) return;
    await _localRepository.saveMessage(
      selfId,
      LegacyChatRecord(
        senderId: selfId,
        receiverId: receiverId,
        text: text,
        createdAt:
            response['createdAt'] as String? ??
            fallbackCreatedAt ??
            DateTime.now().toIso8601String(),
        isPending: false,
      ),
    );
  }

  Future<void> recallMessage(int friendId, String messageKey) =>
      _remoteSource.recallMessage(friendId, messageKey);

  Future<void> recallProjection(
    int friendId,
    MessageProjection projection, {
    required int selfId,
  }) => recallMessage(
    friendId,
    legacyMessageKeyForProjection(projection, selfId, friendId),
  );

  static String legacyMessageKeyForProjection(
    MessageProjection projection,
    int selfId,
    int friendId,
  ) {
    final low = selfId < friendId ? selfId : friendId;
    final high = selfId < friendId ? friendId : selfId;
    if (projection.conversationId != '$low:$high') {
      return projection.messageId;
    }
    final senderId = int.tryParse(projection.authorId);
    if (senderId == null) return projection.messageId;
    return '${projection.createdAt.toIso8601String()}_$senderId';
  }
}
