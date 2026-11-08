import 'dart:convert';

import 'package:taiwan_brawl_messaging/taiwan_brawl_messaging.dart';

/// Encodes shared projections in the retained legacy snapshot format.
/// Legacy snapshot input is converted to events by `LegacyChatEventMapper`.
class MessageChatSyncAdapter {
  const MessageChatSyncAdapter._();

  /// Exports shared projections in the legacy snapshot format without first
  /// materializing the legacy UI model.
  static Map<String, Map<String, String>> exportProjections(
    Iterable<MessageProjection> projections,
    int selfId,
    int friendId, {
    Iterable<String> pendingMessageIds = const <String>[],
  }) {
    final low = selfId < friendId ? selfId : friendId;
    final high = selfId < friendId ? friendId : selfId;
    final conversationId = '$low:$high';
    final pending = pendingMessageIds.toSet();
    final ordered = projections.toList()
      ..sort((left, right) {
        final byCreatedAt = left.createdAt.compareTo(right.createdAt);
        return byCreatedAt != 0
            ? byCreatedAt
            : left.messageId.compareTo(right.messageId);
      });
    final messages = <String, String>{};
    for (final projection in ordered) {
      if (projection.conversationId != conversationId) continue;
      final senderId = int.tryParse(projection.authorId);
      if (senderId == null) continue;
      final isPending = pending.contains(projection.messageId);
      final createdAt = projection.createdAt.toIso8601String();
      messages['${createdAt}_$senderId'] = jsonEncode({
        'senderId': senderId,
        'receiverId': senderId == selfId ? friendId : selfId,
        'text': projection.visibleBody ?? '',
        'createdAt': createdAt,
        'isPending': isPending,
        'isRecalled': projection.recalled,
        'pendingId': isPending
            ? projection.createdAt.millisecondsSinceEpoch
            : null,
      });
    }
    return {'chat_${low}_$high': messages};
  }
}
