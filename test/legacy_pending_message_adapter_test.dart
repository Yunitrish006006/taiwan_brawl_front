import 'package:flutter_test/flutter_test.dart';
import 'package:taiwan_brawl/models/legacy_chat_record.dart';
import 'package:taiwan_brawl/services/legacy_chat_store.dart';
import 'package:taiwan_brawl/services/legacy_pending_message_adapter.dart';

void main() {
  test('persists a legacy message and acknowledges its relay row', () async {
    final store = _RecordingLegacyPendingMessageStore();
    final adapter = LegacyPendingMessageAdapter(localRepository: store);

    final result = await adapter.apply(
      {
        'id': 41,
        'senderId': 9,
        'receiverId': 1,
        'text': 'old format',
        'createdAt': '2026-10-28T00:00:00.000Z',
        'isPending': false,
        'isRecalled': false,
      },
      selfId: 1,
      friendId: 9,
      type: 'message',
      pendingId: 41,
    );

    expect(store.saved.single.text, 'old format');
    expect(store.savedSingleId, 1);
    expect(result.acknowledgedIds, [41]);
    expect(result.opensConversation, isTrue);
  });

  test('applies legacy recall without opening a conversation', () async {
    final store = _RecordingLegacyPendingMessageStore();
    final adapter = LegacyPendingMessageAdapter(localRepository: store);

    final result = await adapter.apply(
      {'text': '2026-10-28T00:00:00.000Z_9'},
      selfId: 1,
      friendId: 9,
      type: 'recall',
      pendingId: 42,
    );

    expect(store.recalled, ['1:9:2026-10-28T00:00:00.000Z_9']);
    expect(result.acknowledgedIds, [42]);
    expect(result.opensConversation, isFalse);
  });
}

class _RecordingLegacyPendingMessageStore implements LegacyPendingMessageStore {
  final saved = <LegacyChatRecord>[];
  final recalled = <String>[];
  int? savedSingleId;

  @override
  Future<void> saveMessage(int selfId, LegacyChatRecord message) async {
    savedSingleId = selfId;
    saved.add(message);
  }

  @override
  Future<void> markRecalled(int selfId, int friendId, String messageKey) async {
    recalled.add('$selfId:$friendId:$messageKey');
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
