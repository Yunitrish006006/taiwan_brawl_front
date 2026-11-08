import 'package:taiwan_brawl_messaging/taiwan_brawl_messaging.dart';

import '../models/legacy_chat_record.dart';
import '../models/message_history_page.dart';
import 'legacy_chat_event_mapper.dart';
import 'legacy_chat_remote_source.dart';
import 'legacy_chat_store.dart';
import 'messaging_core_service.dart';
import 'remote_source_exception.dart';

/// Reads compatibility history and promotes it into the shared event store.
/// It never returns the legacy UI model to application callers.
class LegacyChatHistoryAdapter {
  const LegacyChatHistoryAdapter({
    required MessagingCoreService messagingCore,
    required LegacyChatHistoryStore localRepository,
    required LegacyChatHistoryRemoteSource remoteSource,
    EventAuthenticator? remoteAuthenticator,
  }) : _messagingCore = messagingCore,
       _localRepository = localRepository,
       _remoteSource = remoteSource,
       _remoteAuthenticator = remoteAuthenticator;

  final MessagingCoreService _messagingCore;
  final LegacyChatHistoryStore _localRepository;
  final LegacyChatHistoryRemoteSource _remoteSource;
  final EventAuthenticator? _remoteAuthenticator;

  /// Loads legacy history only when needed, retaining the source rows for
  /// recovery if the event store later loses a projection.
  Future<void> loadAndPromote(
    int selfId,
    int friendId, {
    MessageHistoryCursor? before,
  }) async {
    final migrationComplete = await _promoteLocalHistory(selfId, friendId);
    final hasProjection = _messagingCore.repository
        .projectionsFor(_conversationId(selfId, friendId))
        .isNotEmpty;
    if (before == null && (migrationComplete || hasProjection)) return;
    try {
      await _fetchAndPromote(selfId, friendId, before: before);
    } catch (error) {
      if (error is RemoteSourceException && error.statusCode != null) rethrow;
    }
  }

  /// Reads one server page after promoting any retained local legacy rows.
  /// A failed initial fetch leaves the local projection available offline;
  /// failed older-page fetches are thrown so the UI can retry.
  Future<MessageHistoryPage<LegacyChatRecord>> loadPageAndPromote(
    int selfId,
    int friendId, {
    MessageHistoryCursor? before,
  }) async {
    await _promoteLocalHistory(selfId, friendId);
    MessageHistoryPage<LegacyChatRecord> page;
    try {
      page = await _remoteSource.fetchHistory(friendId, before: before);
    } catch (error) {
      if (error is RemoteSourceException && error.statusCode != null) rethrow;
      if (before != null) rethrow;
      return MessageHistoryPage(
        messages: const [],
        hasMore: false,
        nextCursor: null,
      );
    }
    await _promoteLegacyRecords(page.messages, selfId, friendId);
    return page;
  }

  /// Explicitly refreshes from the legacy server, merging into shared events.
  Future<void> refreshAndPromote(int selfId, int friendId) =>
      _fetchLatestAndPromote(selfId, friendId);

  Future<bool> _promoteLocalHistory(int selfId, int friendId) async {
    final migratedIds = await _localRepository.migratedEventMessageIds(
      selfId,
      friendId,
    );
    final migrationComplete =
        migratedIds != null &&
        migratedIds.every(
          (messageId) =>
              _messagingCore.repository.projectionFor(messageId) != null,
        );
    if (migrationComplete) return true;

    final localSnapshot = await _localRepository.getHistorySnapshot(
      selfId,
      friendId,
    );
    final local = localSnapshot.messages;
    if (local.isEmpty) return false;

    final promotedIds = await _promoteLegacyRecords(local, selfId, friendId);
    if (promotedIds != null &&
        promotedIds.length == local.length &&
        localSnapshot.invalidRowKeys.isEmpty) {
      final marked = await _localRepository.markEventMessagesMigrated(
        selfId,
        friendId,
        promotedIds,
        expectedSourceRevision: localSnapshot.sourceRevision,
      );
      return marked;
    }
    return false;
  }

  Future<void> _fetchLatestAndPromote(int selfId, int friendId) async {
    try {
      final page = await _remoteSource.fetchHistory(friendId);
      await _promoteLegacyRecords(page.messages, selfId, friendId);
    } catch (error) {
      if (error is RemoteSourceException && error.statusCode != null) rethrow;
    }
  }

  Future<MessageHistoryPage<LegacyChatRecord>> _fetchAndPromote(
    int selfId,
    int friendId, {
    MessageHistoryCursor? before,
  }) async {
    final page = await _remoteSource.fetchHistory(friendId, before: before);
    await _promoteLegacyRecords(page.messages, selfId, friendId);
    return page;
  }

  Future<Set<String>?> _promoteLegacyRecords(
    Iterable<LegacyChatRecord> messages,
    int selfId,
    int friendId,
  ) async {
    final legacyMessages = messages.toList(growable: false);
    final events = LegacyChatEventMapper.fromRecords(
      legacyMessages,
      selfId,
      friendId,
    );
    if (!await _messagingCore.acceptRemoteBatch(
      events,
      authenticator: _remoteAuthenticator,
    )) {
      return null;
    }
    final messageIds = events
        .where((event) => event.type == MessageEventType.created)
        .map((event) => event.messageId)
        .toSet();
    if (messageIds.length != legacyMessages.length ||
        messageIds.any(
          (messageId) =>
              _messagingCore.repository.projectionFor(messageId) == null,
        )) {
      return null;
    }
    return messageIds;
  }

  static String _conversationId(int userIdA, int userIdB) {
    final low = userIdA < userIdB ? userIdA : userIdB;
    final high = userIdA < userIdB ? userIdB : userIdA;
    return '$low:$high';
  }
}
