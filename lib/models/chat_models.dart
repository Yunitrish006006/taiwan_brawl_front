class ChatMessage {
  const ChatMessage({
    required this.senderId,
    required this.receiverId,
    required this.text,
    required this.createdAt,
  });

  final int senderId;
  final int receiverId;
  final String text;
  final String createdAt;

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      senderId: (json['senderId'] as num).toInt(),
      receiverId: (json['receiverId'] as num).toInt(),
      text: json['text'] as String? ?? '',
      createdAt: json['createdAt'] as String? ?? '',
    );
  }
}
