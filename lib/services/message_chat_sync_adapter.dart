import 'dart:convert';

import 'package:taiwan_brawl_messaging/taiwan_brawl_messaging.dart';

import '../models/chat_models.dart';

/// Bridges the legacy Hive/KV chat snapshot format to the event repository.
/// This is a migration adapter; new durable state remains event-based.
class MessageChatSyncAdapter {
  const MessageChatSyncAdapter._();

  static Map<String, Map<String, String>> exportMessages(
    Iterable<ChatMessage> messages,
    int selfId,
    int friendId,
  ) {
    final low = selfId < friendId ? selfId : friendId;
    final high = selfId < friendId ? friendId : selfId;
    return {
      'chat_${low}_$high': {
        for (final message in messages)
          message.messageKey: jsonEncode({
            'senderId': message.senderId,
            'receiverId': message.receiverId,
            'text': message.text,
            'createdAt': message.createdAt,
            'isPending': message.isPending,
            'isRecalled': message.isRecalled,
            'pendingId': message.pendingId,
          }),
      },
    };
  }

  static List<MessageEvent> importEvents(
    Map<String, dynamic> data,
    int selfId,
    int friendId,
  ) {
    final low = selfId < friendId ? selfId : friendId;
    final high = selfId < friendId ? friendId : selfId;
    final box = data['chat_${low}_$high'];
    if (box is! Map) return const [];
    final conversationId = '$low:$high';
    final events = <MessageEvent>[];
    for (final entry in box.entries) {
      if (entry.value is! String) continue;
      final raw = jsonDecode(entry.value as String);
      if (raw is! Map) continue;
      final senderId = raw['senderId'];
      final messageKey = entry.key.toString();
      final createdAt = DateTime.tryParse(raw['createdAt']?.toString() ?? '');
      final body = raw['text']?.toString();
      if (senderId == null || createdAt == null || body == null) continue;
      events.add(
        MessageEvent(
          eventId: 'sync-created:$messageKey',
          messageId: messageKey,
          conversationId: conversationId,
          actorId: senderId.toString(),
          type: MessageEventType.created,
          revision: 0,
          createdAt: createdAt.toUtc(),
          body: body,
        ),
      );
      if (raw['isRecalled'] == true) {
        events.add(
          MessageEvent(
            eventId: 'sync-recalled:$messageKey',
            messageId: messageKey,
            conversationId: conversationId,
            actorId: senderId.toString(),
            type: MessageEventType.recalled,
            revision: 1,
            createdAt: createdAt.toUtc(),
          ),
        );
      }
    }
    return events;
  }

  /// Converts legacy UI snapshots into synthetic events for shared storage.
  static List<MessageEvent> eventsFromMessages(
    Iterable<ChatMessage> messages,
    int selfId,
    int friendId,
  ) {
    final low = selfId < friendId ? selfId : friendId;
    final high = selfId < friendId ? friendId : selfId;
    final conversationId = '$low:$high';
    final events = <MessageEvent>[];
    for (final message in messages) {
      final createdAt = DateTime.tryParse(message.createdAt);
      if (createdAt == null || message.messageKey.isEmpty) continue;
      events.add(
        MessageEvent(
          eventId: 'legacy-created:${message.messageKey}',
          messageId: message.messageKey,
          conversationId: conversationId,
          actorId: message.senderId.toString(),
          type: MessageEventType.created,
          revision: 0,
          createdAt: createdAt.toUtc(),
          body: message.text,
        ),
      );
      if (message.isRecalled) {
        events.add(
          MessageEvent(
            eventId: 'legacy-recalled:${message.messageKey}',
            messageId: message.messageKey,
            conversationId: conversationId,
            actorId: message.senderId.toString(),
            type: MessageEventType.recalled,
            revision: 1,
            createdAt: createdAt.toUtc(),
          ),
        );
      }
    }
    return events;
  }
}
