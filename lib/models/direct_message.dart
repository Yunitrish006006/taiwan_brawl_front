import 'package:taiwan_brawl_messaging/taiwan_brawl_messaging.dart';

/// Frontend-facing view of a shared, versioned direct-message projection.
class DirectMessage {
  DirectMessage({
    required this.id,
    required this.conversationId,
    required this.authorId,
    required this.createdAt,
    required this.revision,
    required this.text,
    required this.isRecalled,
    required Set<String> readBy,
    required this.isPending,
  }) : readBy = Set.unmodifiable(readBy);

  factory DirectMessage.fromProjection(
    MessageProjection projection, {
    required bool isPending,
  }) => DirectMessage(
    id: projection.messageId,
    conversationId: projection.conversationId,
    authorId: projection.authorId,
    createdAt: projection.createdAt,
    revision: projection.revision,
    text: projection.visibleBody ?? '',
    isRecalled: projection.recalled,
    readBy: projection.readBy,
    isPending: isPending,
  );

  final String id;
  final String conversationId;
  final String authorId;
  final DateTime createdAt;
  final int revision;
  final String text;
  final bool isRecalled;
  final Set<String> readBy;
  final bool isPending;
}
