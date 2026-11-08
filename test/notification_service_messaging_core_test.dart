import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:taiwan_brawl/models/legacy_chat_record.dart';
import 'package:taiwan_brawl/services/auth_remote_source.dart';
import 'package:taiwan_brawl/services/auth_service.dart';
import 'package:taiwan_brawl/services/legacy_chat_store.dart';
import 'package:taiwan_brawl/services/legacy_installation_store.dart';
import 'package:taiwan_brawl/services/legacy_pending_message_adapter.dart';
import 'package:taiwan_brawl/services/messaging_core_service.dart';
import 'package:taiwan_brawl/services/notification_remote_source.dart';
import 'package:taiwan_brawl/services/notification_service.dart';
import 'package:taiwan_brawl/services/pending_notification_source.dart';
import 'package:taiwan_brawl/services/preview_push_provider.dart';
import 'package:taiwan_brawl_messaging/taiwan_brawl_messaging.dart';

void main() {
  test(
    'notification service accepts pending events through messaging core',
    () async {
      final core = await MessagingCoreService.restore(_MemoryMessagingStore());
      final pendingSource = _PendingSource();
      final auth = AuthService(remoteSource: _AuthSource());
      await auth.init();
      final service = NotificationService(
        legacyPendingMessages: LegacyPendingMessageAdapter(
          localRepository: _UnusedLegacyPendingMessageStore(),
        ),
        messagingCore: core,
        remoteAuthenticator: null,
        credentials: _MemoryCredentials(),
        legacyInstallationStore: _EmptyInstallationStore(),
        pushProvider: PreviewPushProvider(),
        pendingNotificationSource: pendingSource,
        remoteSource: _NotificationSource(),
      );

      service.syncAuth(auth);
      final acknowledgedIds = await pendingSource.handled.future.timeout(
        const Duration(seconds: 2),
      );

      expect(acknowledgedIds, [12]);
      expect(service.pendingConversationUserId, 9);
      expect(
        core.repository.projectionsFor('1:9').single.visibleBody,
        'received event body',
      );

      service.dispose();
      auth.dispose();
      await core.dispose();
    },
  );

  test('does not acknowledge an event held only in memory', () async {
    final core = MessagingCoreService();
    final pendingSource = _PendingSource();
    final auth = AuthService(remoteSource: _AuthSource());
    await auth.init();
    final service = NotificationService(
      legacyPendingMessages: LegacyPendingMessageAdapter(
        localRepository: _UnusedLegacyPendingMessageStore(),
      ),
      messagingCore: core,
      remoteAuthenticator: null,
      credentials: _MemoryCredentials(),
      legacyInstallationStore: _EmptyInstallationStore(),
      pushProvider: PreviewPushProvider(),
      pendingNotificationSource: pendingSource,
      remoteSource: _NotificationSource(),
    );

    service.syncAuth(auth);
    final acknowledgedIds = await pendingSource.handled.future.timeout(
      const Duration(seconds: 2),
    );

    expect(acknowledgedIds, isEmpty);
    expect(service.pendingConversationUserId, 9);
    expect(
      core.repository.projectionsFor('1:9').single.visibleBody,
      'received event body',
    );

    service.dispose();
    auth.dispose();
    await core.dispose();
  });

  test(
    'acknowledges a rejected event only after persisting its conflict',
    () async {
      final store = _MemoryMessagingStore();
      await store.append(
        MessageEvent(
          eventId: 'pending-event-12',
          messageId: 'message-7',
          conversationId: '1:9',
          actorId: '9',
          type: MessageEventType.created,
          revision: 0,
          createdAt: DateTime.utc(2026, 10, 28),
          body: 'original event',
        ),
        pendingOutbox: false,
      );
      final core = await MessagingCoreService.restore(store);
      final pendingSource = _PendingSource();
      final auth = AuthService(remoteSource: _AuthSource());
      await auth.init();
      final service = NotificationService(
        legacyPendingMessages: LegacyPendingMessageAdapter(
          localRepository: _UnusedLegacyPendingMessageStore(),
        ),
        messagingCore: core,
        remoteAuthenticator: null,
        credentials: _MemoryCredentials(),
        legacyInstallationStore: _EmptyInstallationStore(),
        pushProvider: PreviewPushProvider(),
        pendingNotificationSource: pendingSource,
        remoteSource: _NotificationSource(),
      );

      service.syncAuth(auth);
      final acknowledgedIds = await pendingSource.handled.future.timeout(
        const Duration(seconds: 2),
      );

      expect(acknowledgedIds, [12]);
      expect(core.repository.conflicts.single.eventId, 'pending-event-12');
      expect(store.conflictRecords, hasLength(1));
      expect(service.pendingConversationUserId, isNull);

      service.dispose();
      auth.dispose();
      await core.dispose();
    },
  );

  test(
    'notification service delegates legacy rows and acknowledges them',
    () async {
      final core = MessagingCoreService();
      final pendingSource = _LegacyPendingSource();
      final localStore = _UnusedLegacyPendingMessageStore();
      final auth = AuthService(remoteSource: _AuthSource());
      await auth.init();
      final service = NotificationService(
        legacyPendingMessages: LegacyPendingMessageAdapter(
          localRepository: localStore,
        ),
        messagingCore: core,
        remoteAuthenticator: null,
        credentials: _MemoryCredentials(),
        legacyInstallationStore: _EmptyInstallationStore(),
        pushProvider: PreviewPushProvider(),
        pendingNotificationSource: pendingSource,
        remoteSource: _NotificationSource(),
      );

      service.syncAuth(auth);
      final acknowledgedIds = await pendingSource.handled.future.timeout(
        const Duration(seconds: 2),
      );

      expect(acknowledgedIds, [19]);
      expect(localStore.saved.single.text, 'legacy notification body');
      expect(service.pendingConversationUserId, 9);

      service.dispose();
      auth.dispose();
      await core.dispose();
    },
  );
}

class _PendingSource implements PendingNotificationSource {
  final handled = Completer<List<int>>();

  @override
  MessageEvent? eventFromPendingRow(
    Map<String, dynamic> row, {
    required int selfId,
    required int friendId,
  }) => MessageEvent(
    eventId: 'pending-event-${row['id']}',
    messageId: 'message-7',
    conversationId: '$selfId:$friendId',
    actorId: '$friendId',
    type: MessageEventType.created,
    revision: 0,
    createdAt: DateTime.utc(2026, 10, 28),
    body: 'received event body',
  );

  @override
  Future<void> poll({
    required int selfId,
    required int? activeConversationUserId,
    required PendingNotificationHandler onItem,
  }) async {
    try {
      final result = await onItem({
        'id': 12,
        'sender_id': 9,
        'event_id': 'pending-event-12',
        'message_id': 'message-7',
        'event_type': 'created',
      });
      handled.complete(result.toList());
    } catch (error, stackTrace) {
      handled.completeError(error, stackTrace);
    }
  }

  @override
  void dispose() {}
}

class _LegacyPendingSource implements PendingNotificationSource {
  final handled = Completer<List<int>>();

  @override
  MessageEvent? eventFromPendingRow(
    Map<String, dynamic> row, {
    required int selfId,
    required int friendId,
  }) => null;

  @override
  Future<void> poll({
    required int selfId,
    required int? activeConversationUserId,
    required PendingNotificationHandler onItem,
  }) async {
    try {
      final result = await onItem({
        'id': 19,
        'senderId': 9,
        'receiverId': selfId,
        'text': 'legacy notification body',
        'createdAt': '2026-10-28T00:00:00.000Z',
        'isPending': false,
        'isRecalled': false,
      });
      handled.complete(result.toList());
    } catch (error, stackTrace) {
      handled.completeError(error, stackTrace);
    }
  }

  @override
  void dispose() {}
}

class _AuthSource implements AuthRemoteSource {
  @override
  Future<Map<String, dynamic>> loadCurrentUser() async => {
    'user': {'id': 1, 'name': 'Player', 'email': 'player@example.test'},
  };

  @override
  Future<void> clearSession() async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _NotificationSource implements NotificationRemoteSource {
  @override
  Future<Map<String, dynamic>> loadConfiguration() async => const {};

  @override
  Future<void> registerDevice(Map<String, dynamic> payload) async {}

  @override
  Future<void> unregisterDevice(Map<String, dynamic> payload) async {}
}

class _MemoryCredentials implements CredentialStore {
  final values = <String, String>{};

  @override
  Future<String?> read(String key) async => values[key];

  @override
  Future<void> write(String key, String value) async => values[key] = value;

  @override
  Future<void> delete(String key) async => values.remove(key);
}

class _EmptyInstallationStore implements LegacyInstallationStore {
  @override
  Future<String?> readInstallationId() async => null;
}

class _UnusedLegacyPendingMessageStore implements LegacyPendingMessageStore {
  final saved = <LegacyChatRecord>[];

  @override
  Future<void> saveMessage(int selfId, LegacyChatRecord message) async {
    saved.add(message);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _MemoryMessagingStore implements MessageEventStore, MessageConflictStore {
  final events = <MessageEvent>[];
  final pendingOutbox = <MessageEvent>[];
  final conflictRecords = <MessageConflict>[];

  @override
  Future<List<MessageEvent>> loadAll() async => List.of(events);

  @override
  Future<List<MessageEvent>> loadPendingOutbox() async =>
      List.of(pendingOutbox);

  @override
  Future<void> append(MessageEvent event, {required bool pendingOutbox}) async {
    if (!events.any((stored) => stored.eventId == event.eventId)) {
      events.add(event);
    }
    if (pendingOutbox &&
        !this.pendingOutbox.any((stored) => stored.eventId == event.eventId)) {
      this.pendingOutbox.add(event);
    }
  }

  @override
  Future<void> acknowledgeOutbox(String eventId) async {
    pendingOutbox.removeWhere((event) => event.eventId == eventId);
  }

  @override
  Future<List<MessageConflict>> loadConflicts() async =>
      List.of(conflictRecords);

  @override
  Future<void> appendConflict(MessageConflict conflict) async {
    if (!conflictRecords.any(
      (stored) =>
          stored.eventId == conflict.eventId &&
          stored.messageId == conflict.messageId &&
          stored.reason == conflict.reason,
    )) {
      conflictRecords.add(conflict);
    }
  }
}
