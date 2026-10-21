/// A durable record explaining why an event could not enter the active
/// message projection.
class MessageConflict {
  const MessageConflict({
    required this.eventId,
    required this.messageId,
    required this.reason,
  });

  final String eventId;
  final String messageId;
  final String reason;

  Map<String, Object?> toJson() => {
    'eventId': eventId,
    'messageId': messageId,
    'reason': reason,
  };

  factory MessageConflict.fromJson(Map<String, Object?> json) {
    final eventId = json['eventId'];
    final messageId = json['messageId'];
    final reason = json['reason'];
    if (eventId is! String ||
        messageId is! String ||
        reason is! String ||
        eventId.isEmpty ||
        messageId.isEmpty ||
        reason.isEmpty) {
      throw const FormatException('Invalid message conflict');
    }
    return MessageConflict(
      eventId: eventId,
      messageId: messageId,
      reason: reason,
    );
  }
}
