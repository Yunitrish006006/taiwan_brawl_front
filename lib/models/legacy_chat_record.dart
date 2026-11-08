/// Frontend-owned representation of a message stored in the legacy chat box.
///
/// Keep [toJson] aligned with the existing Hive row shape until the explicit
/// legacy-history compatibility audit permits removing that format.
class LegacyChatRecord {
  const LegacyChatRecord({
    required this.senderId,
    required this.receiverId,
    required this.text,
    required this.createdAt,
    this.isPending = false,
    this.isRecalled = false,
    this.pendingId,
  });

  final int senderId;
  final int receiverId;
  final String text;
  final String createdAt;
  final bool isPending;
  final bool isRecalled;
  final int? pendingId;

  /// This is also the historical Hive row key and server recall key.
  String get messageKey => '${createdAt}_$senderId';

  factory LegacyChatRecord.fromJson(Map<String, dynamic> json) {
    final senderId = json['senderId'] ?? json['sender_id'];
    final receiverId = json['receiverId'] ?? json['receiver_id'];
    final createdAt = json['createdAt'] ?? json['created_at'];
    final pendingId = json['pendingId'] ?? json['id'];
    if (senderId is! num || receiverId is! num) {
      throw const FormatException('Legacy chat record has invalid user IDs.');
    }
    if (createdAt != null && createdAt is! String) {
      throw const FormatException('Legacy chat record has invalid timestamp.');
    }
    if (pendingId != null && pendingId is! num) {
      throw const FormatException('Legacy chat record has invalid pending ID.');
    }
    return LegacyChatRecord(
      senderId: senderId.toInt(),
      receiverId: receiverId.toInt(),
      text: json['text'] as String? ?? '',
      createdAt: createdAt as String? ?? '',
      isPending: json['isPending'] as bool? ?? false,
      isRecalled: json['isRecalled'] as bool? ?? false,
      pendingId: pendingId?.toInt(),
    );
  }

  /// Parses the existing HTTP row shape with the same defaults as the old
  /// Legacy server parser contract: `id` is the acknowledgement ID, and
  /// delivery/recall flags start false.
  factory LegacyChatRecord.fromLegacyServerJson(Map<String, dynamic> json) {
    final senderId = json['senderId'] ?? json['sender_id'];
    final receiverId = json['receiverId'] ?? json['receiver_id'];
    final createdAt = json['createdAt'] ?? json['created_at'];
    final pendingId = json['id'];
    if (senderId is! num || receiverId is! num) {
      throw const FormatException('Legacy server row has invalid user IDs.');
    }
    if (createdAt != null && createdAt is! String) {
      throw const FormatException('Legacy server row has invalid timestamp.');
    }
    if (pendingId != null && pendingId is! num) {
      throw const FormatException('Legacy server row has invalid ID.');
    }
    return LegacyChatRecord(
      senderId: senderId.toInt(),
      receiverId: receiverId.toInt(),
      text: json['text'] as String? ?? '',
      createdAt: createdAt as String? ?? '',
      pendingId: pendingId?.toInt(),
    );
  }

  Map<String, Object?> toJson() => {
    'senderId': senderId,
    'receiverId': receiverId,
    'text': text,
    'createdAt': createdAt,
    'isPending': isPending,
    'isRecalled': isRecalled,
    'pendingId': pendingId,
  };
}
