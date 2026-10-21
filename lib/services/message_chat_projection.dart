import 'package:taiwan_brawl_messaging/taiwan_brawl_messaging.dart';

import '../models/chat_models.dart';

/// Converts durable event projections into the existing chat UI model.
class MessageChatProjection {
  const MessageChatProjection._();

  static List<ChatMessage> toMessages({
    required Iterable<MessageProjection> projections,
    required int selfId,
    required int friendId,
    Iterable<String> pendingMessageIds = const <String>[],
  }) {
    final pending = pendingMessageIds.toSet();
    final messages = <ChatMessage>[];
    for (final projection in projections) {
      final message = toMessage(
        projection: projection,
        selfId: selfId,
        friendId: friendId,
        pendingMessageIds: pending,
      );
      if (message != null) messages.add(message);
    }
    messages.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    return messages;
  }

  /// Converts one projection so an edit or recall can update the exact UI row
  /// instead of re-emitting only the newest message in the conversation.
  static ChatMessage? toMessage({
    required MessageProjection projection,
    required int selfId,
    required int friendId,
    Iterable<String> pendingMessageIds = const <String>[],
  }) {
    if (projection.conversationId != _conversationId(selfId, friendId)) {
      return null;
    }
    final senderId = int.tryParse(projection.authorId);
    if (senderId == null) return null;
    final isPending = pendingMessageIds.contains(projection.messageId);
    return ChatMessage(
      senderId: senderId,
      receiverId: senderId == selfId ? friendId : selfId,
      text: projection.visibleBody ?? '',
      createdAt: projection.createdAt.toIso8601String(),
      isPending: isPending,
      isRecalled: projection.recalled,
      pendingId: isPending ? projection.createdAt.millisecondsSinceEpoch : null,
    );
  }

  static String _conversationId(int userIdA, int userIdB) {
    final low = userIdA < userIdB ? userIdA : userIdB;
    final high = userIdA < userIdB ? userIdB : userIdA;
    return '$low:$high';
  }
}
