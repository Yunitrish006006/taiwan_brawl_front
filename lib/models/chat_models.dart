class ChatMessage {
  const ChatMessage({
    required this.senderId,
    required this.receiverId,
    required this.text,
    required this.createdAt,
    this.isPending = false,
    this.pendingId,
  });

  final int senderId;
  final int receiverId;
  final String text;
  final String createdAt;

  /// True when the message was sent via offline relay and not yet ack'd.
  final bool isPending;

  /// Server-assigned id from pending_messages table (used for ack).
  final int? pendingId;

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      senderId: (json['senderId'] ?? json['sender_id'] as num).toInt(),
      receiverId: (json['receiverId'] ?? json['receiver_id'] as num).toInt(),
      text: json['text'] as String? ?? '',
      createdAt: json['createdAt'] ?? json['created_at'] as String? ?? '',
      pendingId: json['id'] != null ? (json['id'] as num).toInt() : null,
    );
  }

  ChatMessage copyWith({bool? isPending, int? pendingId}) {
    return ChatMessage(
      senderId: senderId,
      receiverId: receiverId,
      text: text,
      createdAt: createdAt,
      isPending: isPending ?? this.isPending,
      pendingId: pendingId ?? this.pendingId,
    );
  }
}
