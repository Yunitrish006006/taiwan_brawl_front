import 'message_event.dart';

const recalledMessageText = '訊息已收回';

class MessageProjection {
  const MessageProjection({
    required this.messageId,
    required this.conversationId,
    required this.authorId,
    required this.createdAt,
    required this.revision,
    required this.body,
    required this.recalled,
    required this.readBy,
    required this.lastEventId,
  });

  final String messageId;
  final String conversationId;
  final String authorId;
  final DateTime createdAt;
  final int revision;
  final String? body;
  final bool recalled;
  final Set<String> readBy;
  final String lastEventId;

  String? get visibleBody => recalled ? recalledMessageText : body;

  MessageProjection copyWith({
    int? revision,
    String? body,
    bool? recalled,
    Set<String>? readBy,
    String? lastEventId,
  }) {
    return MessageProjection(
      messageId: messageId,
      conversationId: conversationId,
      authorId: authorId,
      createdAt: createdAt,
      revision: revision ?? this.revision,
      body: body ?? this.body,
      recalled: recalled ?? this.recalled,
      readBy: Set.unmodifiable(readBy ?? this.readBy),
      lastEventId: lastEventId ?? this.lastEventId,
    );
  }

  static MessageProjection fromCreated(MessageEvent event) {
    if (event.type != MessageEventType.created || event.body == null) {
      throw const FormatException(
        'A message projection must start with created',
      );
    }
    return MessageProjection(
      messageId: event.messageId,
      conversationId: event.conversationId,
      authorId: event.actorId,
      createdAt: event.createdAt,
      revision: event.revision,
      body: event.body,
      recalled: false,
      readBy: const {},
      lastEventId: event.eventId,
    );
  }

  MessageProjection apply(MessageEvent event) {
    if (event.messageId != messageId ||
        event.conversationId != conversationId) {
      throw const FormatException('Message event belongs to another message');
    }
    if (event.revision <= revision) return this;
    if (event.revision != revision + 1) {
      throw FormatException(
        'Message revision gap: expected ${revision + 1}, got ${event.revision}',
      );
    }
    switch (event.type) {
      case MessageEventType.edited:
        if (event.actorId != authorId || event.body == null || recalled) {
          throw const FormatException(
            'Only the author may edit an active message',
          );
        }
        return copyWith(
          revision: event.revision,
          body: event.body,
          lastEventId: event.eventId,
        );
      case MessageEventType.recalled:
        if (event.actorId != authorId) {
          throw const FormatException('Only the author may recall a message');
        }
        return copyWith(
          revision: event.revision,
          recalled: true,
          lastEventId: event.eventId,
        );
      case MessageEventType.read:
        return copyWith(
          revision: event.revision,
          readBy: {...readBy, event.actorId},
          lastEventId: event.eventId,
        );
      case MessageEventType.created:
        throw const FormatException('A message cannot be created twice');
    }
  }
}
