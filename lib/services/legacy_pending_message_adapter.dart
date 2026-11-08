import '../models/legacy_chat_record.dart';
import 'legacy_chat_store.dart';

/// Applies legacy pending rows to the compatibility cache during migration.
class LegacyPendingMessageAdapter {
  const LegacyPendingMessageAdapter({
    required LegacyPendingMessageStore localRepository,
  }) : _localRepository = localRepository;

  final LegacyPendingMessageStore _localRepository;

  Future<LegacyPendingMessageResult> apply(
    Map<String, dynamic> item, {
    required int selfId,
    required int friendId,
    required String type,
    required int? pendingId,
  }) async {
    if (type == 'recall') {
      final messageKey = (item['text'] as String? ?? '').trim();
      if (messageKey.isNotEmpty) {
        await _localRepository.markRecalled(selfId, friendId, messageKey);
      }
      return LegacyPendingMessageResult(
        acknowledgedIds: pendingId == null ? const [] : [pendingId],
        opensConversation: false,
      );
    }

    final message = LegacyChatRecord.fromLegacyServerJson(item);
    await _localRepository.saveMessage(selfId, message);
    final acknowledgedId = message.pendingId ?? pendingId;
    return LegacyPendingMessageResult(
      acknowledgedIds: acknowledgedId == null ? const [] : [acknowledgedId],
      opensConversation: true,
    );
  }
}

class LegacyPendingMessageResult {
  const LegacyPendingMessageResult({
    required this.acknowledgedIds,
    required this.opensConversation,
  });

  final List<int> acknowledgedIds;
  final bool opensConversation;
}
