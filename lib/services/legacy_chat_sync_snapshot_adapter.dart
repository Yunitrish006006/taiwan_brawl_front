import 'package:taiwan_brawl_messaging/taiwan_brawl_messaging.dart';

import 'legacy_chat_event_mapper.dart';
import 'legacy_chat_remote_source.dart';
import 'legacy_chat_store.dart';
import 'message_chat_sync_adapter.dart';
import 'messaging_core_service.dart';

/// Bridges the legacy whole-history sync endpoint with shared message events.
class LegacyChatSyncSnapshotAdapter {
  const LegacyChatSyncSnapshotAdapter({
    required MessagingCoreService messagingCore,
    required LegacyChatSnapshotStore localRepository,
    required LegacyChatSnapshotRemoteSource remoteSource,
  }) : _messagingCore = messagingCore,
       _localRepository = localRepository,
       _remoteSource = remoteSource;

  final MessagingCoreService _messagingCore;
  final LegacyChatSnapshotStore _localRepository;
  final LegacyChatSnapshotRemoteSource _remoteSource;

  Future<void> upload(int selfId, int friendId) async {
    final projections = _messagingCore.repository.projectionsFor(
      _conversationId(selfId, friendId),
    );
    final fromEvents = MessageChatSyncAdapter.exportProjections(
      projections,
      selfId,
      friendId,
      pendingMessageIds: _messagingCore.repository.pendingOutbox
          .where((event) => event.type == MessageEventType.created)
          .map((event) => event.messageId),
    );
    final hasEventSnapshot = fromEvents.values.any(
      (messages) => messages.isNotEmpty,
    );
    final exported = hasEventSnapshot
        ? fromEvents
        : await _localRepository.exportAll(selfId, [friendId]);
    if (exported.isEmpty) return;
    await _remoteSource.uploadSyncData(friendId, exported);
  }

  Future<void> downloadAndMerge(int friendId, {int? selfId}) async {
    final downloaded = await _remoteSource.downloadSyncData(friendId);
    final data = LegacyChatEventMapper.validateSnapshot(downloaded.data);
    if (selfId != null) {
      final events = LegacyChatEventMapper.fromValidatedSnapshot(
        data,
        selfId,
        friendId,
      );
      if (!await _messagingCore.acceptRemoteBatch(events)) {
        throw StateError('Snapshot merge rejected conflicting message events.');
      }
    }
    await _localRepository.importAll(data);
    final snapshotId = downloaded.snapshotId;
    if (snapshotId != null) {
      await _remoteSource.acknowledgeSyncData(friendId, snapshotId);
    }
  }

  static String _conversationId(int userIdA, int userIdB) {
    final low = userIdA < userIdB ? userIdA : userIdB;
    final high = userIdA < userIdB ? userIdB : userIdA;
    return '$low:$high';
  }
}
