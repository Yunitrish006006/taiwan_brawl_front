import 'dart:convert';

enum MessageEventType { created, edited, recalled, read }

/// An append-only operation over one logical message.
///
/// [revision] starts at zero for creation and increases by one for every
/// subsequent operation on the same message. Transports may deliver events out
/// of order; repositories are responsible for deterministic reconstruction.
class MessageEvent {
  const MessageEvent({
    required this.eventId,
    required this.messageId,
    required this.conversationId,
    required this.actorId,
    this.deviceId,
    required this.type,
    required this.revision,
    required this.createdAt,
    this.body,
    this.signature,
  });

  final String eventId;
  final String messageId;
  final String conversationId;
  final String actorId;
  final String? deviceId;
  final MessageEventType type;
  final int revision;
  final DateTime createdAt;
  final String? body;
  final String? signature;

  bool get changesMessage =>
      type == MessageEventType.created ||
      type == MessageEventType.edited ||
      type == MessageEventType.recalled;

  /// Stable payload for signing. The signature itself is excluded.
  String get canonicalPayload => jsonEncode({
    'actorId': actorId,
    if (deviceId != null) 'deviceId': deviceId,
    'body': body,
    'conversationId': conversationId,
    'createdAt': createdAt.toUtc().toIso8601String(),
    'eventId': eventId,
    'messageId': messageId,
    'revision': revision,
    'type': type.name,
  });

  MessageEvent withSignature(String value) => MessageEvent(
    eventId: eventId,
    messageId: messageId,
    conversationId: conversationId,
    actorId: actorId,
    deviceId: deviceId,
    type: type,
    revision: revision,
    createdAt: createdAt,
    body: body,
    signature: value,
  );

  Map<String, Object?> toJson() => {
    'eventId': eventId,
    'messageId': messageId,
    'conversationId': conversationId,
    'actorId': actorId,
    if (deviceId != null) 'deviceId': deviceId,
    'type': type.name,
    'revision': revision,
    'createdAt': createdAt.toUtc().toIso8601String(),
    if (body != null) 'body': body,
    if (signature != null) 'signature': signature,
  };

  factory MessageEvent.fromJson(Map<String, Object?> json) {
    final typeName = json['type'];
    final type = MessageEventType.values.firstWhere(
      (value) => value.name == typeName,
      orElse: () =>
          throw FormatException('Unknown message event type: $typeName'),
    );
    final revision = json['revision'];
    if (revision is! int || revision < 0) {
      throw const FormatException(
        'Message event revision must be non-negative',
      );
    }
    final createdAtValue = json['createdAt'];
    if (createdAtValue is! String) {
      throw const FormatException('Message event createdAt is invalid');
    }
    final createdAt = DateTime.tryParse(createdAtValue);
    if (createdAt == null) {
      throw const FormatException('Message event createdAt is invalid');
    }
    final deviceId = _optionalString(json, 'deviceId');
    final body = _optionalString(json, 'body');
    final signature = _optionalString(json, 'signature');
    return MessageEvent(
      eventId: _requiredString(json, 'eventId'),
      messageId: _requiredString(json, 'messageId'),
      conversationId: _requiredString(json, 'conversationId'),
      actorId: _requiredString(json, 'actorId'),
      deviceId: deviceId?.trim().isEmpty == true ? null : deviceId,
      type: type,
      revision: revision,
      createdAt: createdAt,
      body: body,
      signature: signature,
    );
  }

  static String _requiredString(Map<String, Object?> json, String key) {
    final value = json[key];
    if (value is! String || value.isEmpty) {
      throw FormatException('Message event $key is required');
    }
    return value;
  }

  static String? _optionalString(Map<String, Object?> json, String key) {
    final value = json[key];
    if (value != null && value is! String) {
      throw FormatException('Message event $key must be a string');
    }
    return value as String?;
  }
}
