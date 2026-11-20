import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:taiwan_brawl/models/direct_message.dart';
import 'package:taiwan_brawl/models/message_history_page.dart';
import 'package:taiwan_brawl/pages/social/editable_dm_page.dart';
import 'package:taiwan_brawl/services/direct_message_service.dart';
import 'package:taiwan_brawl/services/direct_message_sync_service.dart';
import 'package:taiwan_brawl/services/chat_device_management_service.dart';
import 'package:taiwan_brawl/services/manual_p2p_dm_service.dart';
import 'package:taiwan_brawl/services/relay_fallback_dm_service.dart';
import 'package:taiwan_brawl/services/retryable_dm_service.dart';

void main() {
  testWidgets('shows P2P route after automatic connection succeeds', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: EditableDmPage(
          service: _FakeDmService(),
          relayFallbackService: _FakeRelayFallbackDmService(),
          friendId: 2,
          friendName: 'Friend',
          currentUserId: 1,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byTooltip('P2P connected'), findsOneWidget);
  });

  testWidgets('lock button opens the new security pairing UI', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: EditableDmPage(
          service: _FakeDmService(),
          relayFallbackService: _FakeRelayFallbackDmService(),
          friendId: 2,
          friendName: 'Friend',
          currentUserId: 1,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('安全配對'));
    await tester.pumpAndSettle();

    expect(find.text('安全配對'), findsOneWidget);
    expect(find.text('P2P 已配對'), findsOneWidget);
    expect(find.text('進階：手動交換配對資料'), findsNothing);
  });

  testWidgets('new pairing button retries the automatic P2P connection', (
    tester,
  ) async {
    final service = _FakeDmService();
    final relay = _FakeRelayFallbackDmService()..p2pActive = false;
    await tester.pumpWidget(
      MaterialApp(
        home: EditableDmPage(
          service: service,
          relayFallbackService: relay,
          friendId: 2,
          friendName: 'Friend',
          currentUserId: 1,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('安全配對'));
    await tester.pumpAndSettle();
    expect(find.text('開始新版配對'), findsOneWidget);
    expect(find.text('雙方開啟聊天頁即可自動協商；任一方都能按鎖頭重試。'), findsOneWidget);

    await tester.tap(find.text('開始新版配對'));
    await tester.pumpAndSettle();

    expect(service.connectCalls.length, greaterThanOrEqualTo(2));
  });

  testWidgets('snapshot sync actions only appear when capability is provided', (
    tester,
  ) async {
    final service = _FakeDmService();
    await tester.pumpWidget(
      MaterialApp(
        home: EditableDmPage(
          service: service,
          friendId: 2,
          friendName: 'Friend',
          currentUserId: 1,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.upload), findsNothing);
    expect(find.byIcon(Icons.download), findsNothing);

    final sync = _FakeDmSyncService();
    await tester.pumpWidget(
      MaterialApp(
        home: EditableDmPage(
          service: service,
          syncService: sync,
          friendId: 2,
          friendName: 'Friend',
          currentUserId: 1,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.upload), findsOneWidget);
    expect(find.byIcon(Icons.download), findsOneWidget);
    await tester.tap(find.byIcon(Icons.upload));
    await tester.pumpAndSettle();
    expect(sync.uploadCalls, 1);

    await tester.tap(find.byIcon(Icons.download));
    await tester.pumpAndSettle();
    expect(sync.downloadCalls, 1);
  });

  testWidgets('ignores repeated sends while the first send is pending', (
    tester,
  ) async {
    final service = _FakeDmService();
    await tester.pumpWidget(
      MaterialApp(
        home: EditableDmPage(
          service: service,
          retryService: service,
          friendId: 2,
          friendName: 'Friend',
          currentUserId: 1,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'hello');
    await tester.tap(find.byIcon(Icons.send));
    await tester.pump();
    expect(service.sendCalls, 1);

    await tester.testTextInput.receiveAction(TextInputAction.send);
    await tester.pump();
    expect(service.sendCalls, 1);

    service.sendCompleter.complete();
    await tester.pumpAndSettle();
  });

  testWidgets('preserves the draft and reports a send failure', (tester) async {
    final service = _FakeDmService()..sendError = StateError('unauthorized');
    await tester.pumpWidget(
      MaterialApp(
        home: EditableDmPage(
          service: service,
          retryService: service,
          friendId: 2,
          friendName: 'Friend',
          currentUserId: 1,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'keep this draft');
    await tester.tap(find.byIcon(Icons.send));
    await tester.pumpAndSettle();

    expect(find.text('keep this draft'), findsOneWidget);
    expect(find.textContaining('Message send failed'), findsOneWidget);
  });

  testWidgets('retries a preserved failed draft through the retry port', (
    tester,
  ) async {
    final service = _FakeDmService()..sendError = StateError('offline');
    await tester.pumpWidget(
      MaterialApp(
        home: EditableDmPage(
          service: service,
          retryService: service,
          friendId: 2,
          friendName: 'Friend',
          currentUserId: 1,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'retry me');
    await tester.tap(find.byIcon(Icons.send));
    await tester.pumpAndSettle();
    service.sendError = null;

    await tester.testTextInput.receiveAction(TextInputAction.send);
    await tester.pumpAndSettle();

    expect(service.sendCalls, 1);
    expect(service.retryCalls, 1);
    expect(find.text('retry me'), findsNothing);
  });

  testWidgets('edits a message through its stable ID and exits the dialog', (
    tester,
  ) async {
    final service = _FakeDmService()
      ..initialHistory = [
        _message(
          7,
          DateTime.utc(2026, 10, 1),
          text: 'editable message',
          authorId: '1',
        ),
      ];
    await tester.pumpWidget(
      MaterialApp(
        home: EditableDmPage(
          service: service,
          friendId: 2,
          friendName: 'Friend',
          currentUserId: 1,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.longPress(find.text('editable message'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Edit'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, 'edited message');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(service.editedMessageIds, ['message-7']);
    expect(service.editedTexts, ['edited message']);
    expect(find.text('Edit message'), findsNothing);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('edit and recall failures return control and report the error', (
    tester,
  ) async {
    final service = _FakeDmService()
      ..initialHistory = [
        _message(
          8,
          DateTime.utc(2026, 10, 1),
          text: 'message to change',
          authorId: '1',
        ),
      ]
      ..editError = StateError('temporary transport failure')
      ..recallError = StateError('temporary transport failure');
    await tester.pumpWidget(
      MaterialApp(
        home: EditableDmPage(
          service: service,
          friendId: 2,
          friendName: 'Friend',
          currentUserId: 1,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.longPress(find.text('message to change'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Edit'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, 'edit attempt');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Edit was not delivered'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    await tester.pump(const Duration(seconds: 5));

    await tester.longPress(find.text('message to change'));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.undo));
    await tester.pumpAndSettle();

    expect(find.textContaining('Recall was not delivered'), findsOneWidget);
    expect(service.recalledMessageIds, ['message-8']);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets(
    'automatically connects without exposing the old pairing button',
    (tester) async {
      final service = _FakeDmService();
      await tester.pumpWidget(
        MaterialApp(
          home: EditableDmPage(
            service: service,
            manualP2pService: _FakeManualP2pService(),
            friendId: 2,
            friendName: 'Friend',
            currentUserId: 1,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byTooltip('Serverless P2P'), findsNothing);
      expect(service.connectCalls, [(1, 2, true)]);
    },
  );

  testWidgets('manual P2P uses the stable role and copy-paste bundle flow', (
    tester,
  ) async {
    final manualService = _FakeManualP2pService();
    await tester.pumpWidget(
      MaterialApp(
        home: EditableDmPage(
          service: _FakeDmService(),
          manualP2pService: manualService,
          friendId: 2,
          friendName: 'Friend',
          currentUserId: 1,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('安全配對'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('進階：手動交換配對資料'));
    await tester.pumpAndSettle();

    expect(find.text('Role'), findsNothing);
    expect(find.textContaining('QR'), findsNothing);
    expect(find.textContaining('Copy your connection bundle'), findsOneWidget);
    await tester.tap(find.text('Prepare'));
    await tester.pumpAndSettle();

    expect(manualService.preparedRoles, [true]);
    expect(find.text('signed-bundle'), findsOneWidget);
    expect(find.text('Copy'), findsOneWidget);
  });

  testWidgets('switches from connected P2P to relay and back manually', (
    tester,
  ) async {
    final relayService = _FakeRelayFallbackDmService();
    await tester.pumpWidget(
      MaterialApp(
        home: EditableDmPage(
          service: _FakeDmService(),
          relayFallbackService: relayService,
          friendId: 2,
          friendName: 'Friend',
          currentUserId: 1,
        ),
      ),
    );
    await tester.pumpAndSettle();

    final relaySwitch = find.byKey(const Key('dm-server-relay-switch'));
    expect(tester.widget<SwitchListTile>(relaySwitch).value, isFalse);
    expect(relayService.useCalls, 0);
    await tester.tap(relaySwitch);
    await tester.pumpAndSettle();
    expect(relayService.useCalls, 1);
    expect(tester.widget<SwitchListTile>(relaySwitch).value, isTrue);
    expect(find.byTooltip('Using server relay'), findsOneWidget);

    await tester.tap(relaySwitch);
    await tester.pumpAndSettle();
    expect(relayService.disableCalls, 1);
    expect(tester.widget<SwitchListTile>(relaySwitch).value, isFalse);
    expect(find.byTooltip('P2P connected'), findsOneWidget);
  });

  testWidgets('hides relay choice until the E2EE relay path is ready', (
    tester,
  ) async {
    final dmService = _FakeDmService()
      ..connectError = StateError('P2P unavailable');
    final relayService = _FakeRelayFallbackDmService()
      ..relayFallbackChoiceRequired = true;
    await tester.pumpWidget(
      MaterialApp(
        home: EditableDmPage(
          service: dmService,
          relayFallbackService: relayService,
          allowServerRelay: false,
          friendId: 2,
          friendName: 'Friend',
          currentUserId: 1,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('dm-server-relay-switch')), findsNothing);
    expect(find.text('Connection unavailable'), findsNothing);
    expect(relayService.useCalls, 0);
  });

  testWidgets('lists devices and revokes only another device', (tester) async {
    final devices = _FakeChatDeviceManagementService([
      ChatDeviceInfo(
        deviceId: 'phone-12345678',
        createdAt: DateTime.utc(2026, 10, 20),
        lastSeenAt: DateTime.utc(2026, 10, 28),
      ),
      ChatDeviceInfo(
        deviceId: 'tablet-abcdefgh',
        createdAt: DateTime.utc(2026, 10, 21),
        lastSeenAt: DateTime.utc(2026, 10, 27),
      ),
    ]);
    await tester.pumpWidget(
      MaterialApp(
        home: EditableDmPage(
          service: _FakeDmService(),
          friendId: 2,
          friendName: 'Friend',
          currentUserId: 1,
          currentDeviceId: 'phone-12345678',
          deviceManagementService: devices,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Chat devices'));
    await tester.pumpAndSettle();

    expect(find.text('This device'), findsOneWidget);
    expect(find.text('Device tablet-a'), findsOneWidget);
    expect(find.byTooltip('Revoke relay access'), findsOneWidget);
    await tester.tap(find.byTooltip('Revoke relay access'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Revoke'));
    await tester.pumpAndSettle();

    expect(devices.revokedDeviceIds, ['tablet-abcdefgh']);
    expect(find.text('Device tablet-a'), findsNothing);
    expect(find.text('This device'), findsOneWidget);
  });

  testWidgets('refreshes current-device activity while the chat is open', (
    tester,
  ) async {
    final devices = _FakeChatDeviceManagementService(const []);
    await tester.pumpWidget(
      MaterialApp(
        home: EditableDmPage(
          service: _FakeDmService(),
          friendId: 2,
          friendName: 'Friend',
          currentUserId: 1,
          currentDeviceId: 'phone-12345678',
          deviceManagementService: devices,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(devices.registeredDeviceIds, ['phone-12345678']);

    await tester.pump(const Duration(minutes: 5));
    await tester.pump();

    expect(devices.registeredDeviceIds, ['phone-12345678', 'phone-12345678']);
  });

  testWidgets('P2P connection loss retries without selecting relay', (
    tester,
  ) async {
    final relayService = _FakeRelayFallbackDmService()
      ..p2pRetryInterval = const Duration(seconds: 1);
    final dmService = _FakeDmService();
    await tester.pumpWidget(
      MaterialApp(
        home: EditableDmPage(
          service: dmService,
          relayFallbackService: relayService,
          friendId: 2,
          friendName: 'Friend',
          currentUserId: 1,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byTooltip('P2P connected'), findsOneWidget);

    relayService
      ..p2pActive = false
      ..relayFallbackChoiceRequired = true
      ..retryResults.add(true)
      .._connectionChanges.add(null);
    await tester.pumpAndSettle();

    expect(find.text('Connection unavailable'), findsNothing);
    expect(find.byTooltip('Waiting for P2P'), findsOneWidget);
    await tester.pump(relayService.p2pRetryInterval);
    await tester.pumpAndSettle();

    expect(relayService.useCalls, 0);
    expect(find.byTooltip('P2P connected'), findsOneWidget);
    expect(find.text('Connection unavailable'), findsNothing);
  });

  testWidgets('retries P2P with backoff while the relay switch is off', (
    tester,
  ) async {
    final dmService = _FakeDmService()
      ..connectError = StateError('temporary P2P outage');
    final relayService = _FakeRelayFallbackDmService()
      ..relayFallbackChoiceRequired = true
      ..p2pActive = false
      ..p2pRetryInterval = const Duration(seconds: 1)
      ..retryResults.addAll([false, false, true]);
    await tester.pumpWidget(
      MaterialApp(
        home: EditableDmPage(
          service: dmService,
          relayFallbackService: relayService,
          friendId: 2,
          friendName: 'Friend',
          currentUserId: 1,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.pump(relayService.p2pRetryInterval);
    await tester.pumpAndSettle();
    expect(relayService.retryCalls, 1);
    expect(find.byTooltip('Waiting for P2P'), findsOneWidget);

    await tester.pump(const Duration(seconds: 2));
    await tester.pump();
    await tester.pumpAndSettle();
    expect(relayService.retryCalls, 2);
    expect(find.byTooltip('Waiting for P2P'), findsOneWidget);

    await tester.pump(const Duration(seconds: 4));
    await tester.pump();
    await tester.pumpAndSettle();
    expect(relayService.retryCalls, 3);
    expect(find.byTooltip('P2P connected'), findsOneWidget);
    expect(relayService.useCalls, 0);
  });

  testWidgets('loads older history at the top and keeps the page cursor', (
    tester,
  ) async {
    final initialMessages = [
      for (var index = 0; index < 60; index++)
        _message(index, DateTime.utc(2026, 10, 1, 0, index)),
    ];
    final olderMessage = _message(
      100,
      DateTime.utc(2026, 9, 30, 23, 59),
      text: 'older history item',
    );
    const firstCursor = MessageHistoryCursor(
      createdAt: '2026-10-01T00:00:00.000Z',
      rowId: 1,
    );
    final service = _FakeDmService()
      ..initialHistory = initialMessages
      ..olderHistory = [olderMessage, ...initialMessages]
      ..initialCursor = firstCursor;

    await tester.pumpWidget(
      MaterialApp(
        home: EditableDmPage(
          service: service,
          friendId: 2,
          friendName: 'Friend',
          currentUserId: 1,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.drag(find.byType(ListView), const Offset(0, 10000));
    await tester.pumpAndSettle();

    expect(service.requestedPageCursors, [null, firstCursor]);

    await tester.drag(find.byType(ListView), const Offset(0, 1000));
    await tester.pumpAndSettle();
    expect(find.text('older history item'), findsOneWidget);
  });
}

DirectMessage _message(
  int index,
  DateTime createdAt, {
  String? text,
  String authorId = '2',
}) => DirectMessage(
  id: 'message-$index',
  conversationId: '1:2',
  authorId: authorId,
  createdAt: createdAt,
  revision: 0,
  text: text ?? 'history item $index',
  isRecalled: false,
  readBy: const {},
  isPending: false,
);

class _FakeManualP2pService implements ManualP2pDmService {
  final preparedRoles = <bool>[];

  @override
  bool get enabled => true;

  @override
  String? get localDeviceId => null;

  @override
  Future<void> prepare({required bool isCaller}) async {
    preparedRoles.add(isCaller);
  }

  @override
  Future<String> exportBundle({
    required String sessionId,
    required String senderDeviceId,
  }) async => 'signed-bundle';

  @override
  Future<void> importBundle(
    String encoded, {
    String? expectedSessionId,
    String? expectedSenderDeviceId,
  }) async {}

  @override
  Future<void> complete() async {}
}

class _FakeRelayFallbackDmService implements RelayFallbackDmService {
  final StreamController<void> _connectionChanges =
      StreamController<void>.broadcast();

  @override
  Stream<void> get connectionStateChanges => _connectionChanges.stream;

  @override
  Duration p2pRetryInterval = const Duration(milliseconds: 50);
  @override
  bool relayFallbackChoiceRequired = false;
  @override
  bool relayFallbackActive = false;
  @override
  bool p2pActive = true;
  @override
  bool get relayFallbackEnabled => relayFallbackActive;
  int useCalls = 0;
  int disableCalls = 0;
  int retryCalls = 0;
  final List<bool> retryResults = <bool>[];

  @override
  Future<bool> retryP2PConnection() async {
    retryCalls++;
    final connected = retryResults.isNotEmpty && retryResults.removeAt(0);
    p2pActive = connected;
    relayFallbackChoiceRequired = !connected;
    _connectionChanges.add(null);
    return connected;
  }

  @override
  Future<void> disableRelayFallback() async {
    disableCalls++;
    relayFallbackActive = false;
    p2pActive = true;
    _connectionChanges.add(null);
  }

  @override
  Future<void> useRelayFallback() async {
    useCalls++;
    relayFallbackChoiceRequired = false;
    relayFallbackActive = true;
    p2pActive = false;
    _connectionChanges.add(null);
  }
}

class _FakeChatDeviceManagementService implements ChatDeviceManagementService {
  _FakeChatDeviceManagementService(this.devices);

  List<ChatDeviceInfo> devices;
  final registeredDeviceIds = <String>[];
  final revokedDeviceIds = <String>[];

  @override
  Future<void> registerCurrentDevice(String deviceId) async {
    registeredDeviceIds.add(deviceId);
  }

  @override
  Future<List<ChatDeviceInfo>> loadActiveDevices() async => devices;

  @override
  Future<void> revokeDevice(String deviceId) async {
    revokedDeviceIds.add(deviceId);
    devices = devices.where((device) => device.deviceId != deviceId).toList();
  }
}

class _FakeDmService implements DirectMessageService, RetryableDmService {
  final sendCompleter = Completer<void>();
  int sendCalls = 0;
  int retryCalls = 0;
  Object? sendError;
  Object? editError;
  Object? recallError;
  Object? connectError;
  final editedMessageIds = <String>[];
  final editedTexts = <String>[];
  final recalledMessageIds = <String>[];
  final connectCalls = <(int, int, bool)>[];
  List<DirectMessage> initialHistory = const [];
  List<DirectMessage> olderHistory = const [];
  MessageHistoryCursor? initialCursor;
  final requestedPageCursors = <MessageHistoryCursor?>[];

  @override
  Stream<DirectMessage> get directMessageStream => const Stream.empty();

  @override
  Future<List<DirectMessage>> loadConversation(
    int selfId,
    int friendId, {
    MessageHistoryCursor? before,
  }) async => [];

  @override
  Future<MessageHistoryPage<DirectMessage>> loadConversationPage(
    int selfId,
    int friendId, {
    MessageHistoryCursor? before,
  }) async {
    requestedPageCursors.add(before);
    return MessageHistoryPage(
      messages: before == null ? initialHistory : olderHistory,
      hasMore: before == null && initialCursor != null,
      nextCursor: before == null ? initialCursor : null,
    );
  }

  @override
  Future<List<DirectMessage>> refreshConversation(
    int selfId,
    int friendId,
  ) async => [];

  @override
  Future<void> sendText(int friendId, String text) {
    sendCalls++;
    if (sendError case final error?) throw error;
    return sendCompleter.future;
  }

  @override
  Future<void> retryPendingMessage(int receiverId, String text) async {
    retryCalls++;
    if (sendError case final error?) throw error;
  }

  @override
  Future<void> editProjectedMessage(String messageId, String text) async {
    editedMessageIds.add(messageId);
    editedTexts.add(text);
    if (editError case final error?) throw error;
  }

  @override
  Future<void> recallProjectedMessage(String messageId) async {
    recalledMessageIds.add(messageId);
    if (recallError case final error?) throw error;
  }

  @override
  Future<void> markProjectedMessageRead(String messageId) async {}

  @override
  Future<void> connectToDm(
    int selfId,
    int friendId, {
    bool isCaller = true,
  }) async {
    connectCalls.add((selfId, friendId, isCaller));
    if (connectError case final error?) throw error;
  }

  @override
  void disconnect() {}
}

class _FakeDmSyncService implements DirectMessageSyncService {
  int uploadCalls = 0;
  int downloadCalls = 0;

  @override
  Future<void> uploadSyncData(int selfId, int friendId) async {
    uploadCalls++;
  }

  @override
  Future<void> downloadAndMergeSyncData(int friendId) async {
    downloadCalls++;
  }
}
