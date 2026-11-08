@TestOn('chrome')
library;

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';
import 'package:taiwan_brawl/config/app_configuration.dart';
import 'package:taiwan_brawl/services/api_client.dart';
import 'package:taiwan_brawl/services/fallback_message_transport.dart';
import 'package:taiwan_brawl/services/messaging_transport_factory.dart';
import 'package:taiwan_brawl/services/peer_trust_service.dart';
import 'package:taiwan_brawl/services/p2p_message_transport.dart';
import 'package:taiwan_brawl/services/server_message_transport.dart';
import 'package:taiwan_brawl/services/secure_device_identity.dart';
import 'package:taiwan_brawl_messaging/taiwan_brawl_messaging.dart';

void main() {
  test(
    'establishes real WebRTC peers through signed manual negotiation bundles',
    () async {
      const sessionId = 'dm:1:2';
      final callerSignaling = ManualPeerSignaling();
      final answererSignaling = ManualPeerSignaling();
      final caller = P2PMessageTransport(
        friendId: 2,
        signalingService: callerSignaling,
        isCaller: true,
        iceConfiguration: const {'iceServers': <Object>[]},
      );
      final answerer = P2PMessageTransport(
        friendId: 1,
        signalingService: answererSignaling,
        isCaller: false,
        iceConfiguration: const {'iceServers': <Object>[]},
      );
      final callerCredentials = _MemoryCredentials();
      final answererCredentials = _MemoryCredentials();
      final callerIdentity = await SecureDeviceIdentity.restore(
        credentials: callerCredentials,
      );
      final answererIdentity = await SecureDeviceIdentity.restore(
        credentials: answererCredentials,
      );
      final callerTrust = PeerTrustService(credentials: callerCredentials);
      final answererTrust = PeerTrustService(credentials: answererCredentials);
      final callerInvitation = callerTrust.createInvitation(callerIdentity);
      final answererInvitation = answererTrust.createInvitation(
        answererIdentity,
      );
      await callerTrust.trustInvitation(
        answererInvitation.encode(),
        confirmedFingerprint: answererInvitation.fingerprint,
      );
      await answererTrust.trustInvitation(
        callerInvitation.encode(),
        confirmedFingerprint: callerInvitation.fingerprint,
      );
      final callerAuthenticator = callerTrust.remoteAuthenticator(
        local: callerIdentity,
      );
      final answererAuthenticator = answererTrust.remoteAuthenticator(
        local: answererIdentity,
      );
      final callerRepository = MessageRepository();
      final answererRepository = MessageRepository();
      final callerEngine = MessageSyncEngine(
        repository: callerRepository,
        transport: caller,
        authenticator: callerAuthenticator,
      );
      final answererEngine = MessageSyncEngine(
        repository: answererRepository,
        transport: answerer,
        authenticator: answererAuthenticator,
      );

      Future<void> exchange({
        required ManualPeerSignaling from,
        required ManualPeerSignaling to,
        required String senderDeviceId,
        required EventAuthenticator senderAuthenticator,
        required EventAuthenticator receiverAuthenticator,
      }) async {
        final signedBundle = await from.exportSignedBundle(
          sessionId: sessionId,
          senderDeviceId: senderDeviceId,
          authenticator: senderAuthenticator,
        );
        await to.importSignedBundle(
          signedBundle,
          authenticator: receiverAuthenticator,
          expectedSessionId: sessionId,
          expectedSenderDeviceId: senderDeviceId,
        );
      }

      try {
        await Future.wait([caller.prepare(), answerer.prepare()]);
        final callerConnected = caller.connect();
        final answererConnected = answerer.connect();
        final negotiationPump = () async {
          final deadline = DateTime.now().add(const Duration(seconds: 25));
          while (!(caller.isConnected && answerer.isConnected)) {
            if (DateTime.now().isAfter(deadline)) {
              throw TimeoutException(
                'Signed manual WebRTC negotiation did not connect',
              );
            }
            await exchange(
              from: callerSignaling,
              to: answererSignaling,
              senderDeviceId: callerIdentity.deviceId,
              senderAuthenticator: callerAuthenticator,
              receiverAuthenticator: answererAuthenticator,
            );
            await exchange(
              from: answererSignaling,
              to: callerSignaling,
              senderDeviceId: answererIdentity.deviceId,
              senderAuthenticator: answererAuthenticator,
              receiverAuthenticator: callerAuthenticator,
            );
            await Future<void>.delayed(const Duration(milliseconds: 25));
          }
        }();
        await Future.wait([
          callerConnected,
          answererConnected,
          negotiationPump,
        ]).timeout(
          const Duration(seconds: 30),
          onTimeout: () => throw TimeoutException(
            'Timed out establishing signed manual WebRTC peers',
          ),
        );
        expect(caller.isConnected, isTrue);
        expect(answerer.isConnected, isTrue);

        await Future.wait([callerEngine.start(), answererEngine.start()]);
        const messageId = 'manual-webrtc-message';
        final received = answererRepository.changes
            .firstWhere((projection) => projection.messageId == messageId)
            .timeout(const Duration(seconds: 5));
        await callerRepository.addLocal(
          MessageEvent(
            eventId: 'manual-webrtc-create',
            messageId: messageId,
            conversationId: sessionId,
            actorId: '1',
            deviceId: callerIdentity.deviceId,
            type: MessageEventType.created,
            revision: 0,
            createdAt: DateTime.utc(2026, 1, 1),
            body: 'signed out-of-band handshake',
          ),
          authenticator: callerAuthenticator,
        );
        await callerEngine.syncNow();
        expect((await received).visibleBody, 'signed out-of-band handshake');
      } finally {
        await callerEngine.stop();
        await answererEngine.stop();
        await caller.dispose();
        await answerer.dispose();
      }
    },
  );

  test('buffers ICE candidates delivered before their SDP description', () async {
    final callerSignaling = _BufferedSignaling.pair();
    final answererSignaling = callerSignaling.peer;
    final caller = P2PMessageTransport(
      friendId: 2,
      signalingService: callerSignaling,
      isCaller: true,
      iceConfiguration: const {'iceServers': <Object>[]},
    );
    final answerer = P2PMessageTransport(
      friendId: 1,
      signalingService: answererSignaling,
      isCaller: false,
      iceConfiguration: const {'iceServers': <Object>[]},
    );
    final callerConnecting = caller.connect();
    final answererConnecting = answerer.connect();

    try {
      final deadline = DateTime.now().add(const Duration(seconds: 25));
      while (!(caller.isConnected && answerer.isConnected)) {
        if (DateTime.now().isAfter(deadline)) {
          throw TimeoutException('P2P negotiation did not settle');
        }
        if (callerSignaling.hasOfferAndCandidate) {
          callerSignaling.deliverPendingInReverseOrder();
        }
        if (answererSignaling.hasAnswerAndCandidate) {
          answererSignaling.deliverPendingInReverseOrder();
        }
        await Future<void>.delayed(const Duration(milliseconds: 20));
      }
      await Future.wait([callerConnecting, answererConnecting]);

      final received = answerer.events.firstWhere(
        (event) => event.eventId == 'reordered-ice-event',
      );
      await caller.send(
        MessageEvent(
          eventId: 'reordered-ice-event',
          messageId: 'reordered-ice-message',
          conversationId: '1:2',
          actorId: '1',
          type: MessageEventType.created,
          revision: 0,
          createdAt: DateTime.utc(2026, 10, 28),
          body: 'ICE was delivered first',
        ),
      );
      expect((await received).body, 'ICE was delivered first');
    } finally {
      await caller.dispose();
      await answerer.dispose();
      callerSignaling.dispose();
      answererSignaling.dispose();
    }
  });

  test('one recovering WebRTC peer reconnects and delivers over P2P again', () async {
    final (callerSignaling, answererSignaling) = _LoopbackSignaling.pair();
    final callerPeer = P2PMessageTransport(
      friendId: 2,
      signalingService: callerSignaling,
      isCaller: true,
      iceConfiguration: const {'iceServers': <Object>[]},
    );
    final answererPeer = P2PMessageTransport(
      friendId: 1,
      signalingService: answererSignaling,
      isCaller: false,
      iceConfiguration: const {'iceServers': <Object>[]},
    );
    final caller = FallbackMessageTransport(
      primary: callerPeer,
      fallback: _UnusedMessageTransport(),
    );
    final answerer = FallbackMessageTransport(
      primary: answererPeer,
      fallback: _UnusedMessageTransport(),
    );
    final callerRepository = MessageRepository();
    final answererRepository = MessageRepository();
    final callerEngine = MessageSyncEngine(
      repository: callerRepository,
      transport: caller,
    );
    final answererEngine = MessageSyncEngine(
      repository: answererRepository,
      transport: answerer,
    );

    try {
      await Future.wait([callerEngine.start(), answererEngine.start()]).timeout(
        const Duration(seconds: 20),
      );
      expect(caller.p2pActive, isTrue);
      expect(answerer.p2pActive, isTrue);
      await callerPeer.disconnect();
      expect(caller.relayChoiceRequired, isTrue);
      expect(caller.relayActive, isFalse);
      expect(answerer.relayActive, isFalse);

      final queuedWhileDisconnected = MessageEvent(
        eventId: 'webrtc-after-reconnect',
        messageId: 'message-after-reconnect',
        conversationId: '1:2',
        actorId: '1',
        type: MessageEventType.created,
        revision: 0,
        createdAt: DateTime.utc(2026, 10, 28),
        body: 'P2P recovered',
      );
      await callerRepository.addLocal(queuedWhileDisconnected);
      expect(callerRepository.pendingOutbox, [queuedWhileDisconnected]);

      expect(
        await caller.retryPrimary().timeout(const Duration(seconds: 25)),
        isTrue,
      );
      await _waitUntil(() => answerer.p2pActive);
      expect(caller.p2pActive, isTrue);
      expect(answerer.p2pActive, isTrue);
      expect(caller.relayChoiceRequired, isFalse);
      expect(answerer.relayChoiceRequired, isFalse);
      expect(caller.relayActive, isFalse);
      expect(answerer.relayActive, isFalse);

      final received = answererRepository.changes.firstWhere(
        (projection) =>
            projection.messageId == queuedWhileDisconnected.messageId,
      );
      await callerEngine.syncNow();
      expect((await received).visibleBody, 'P2P recovered');
      expect(callerRepository.pendingOutbox, isEmpty);
      expect(
        answererRepository.events.map((event) => event.eventId),
        ['webrtc-after-reconnect'],
      );
    } finally {
      await callerEngine.stop();
      await answererEngine.stop();
      await caller.dispose();
      await answerer.dispose();
      callerSignaling.dispose();
      answererSignaling.dispose();
    }
  });

  test(
    'carries read, edit and recall through two real browser WebRTC peers',
    () async {
      final (callerSignaling, answererSignaling) = _LoopbackSignaling.pair();
      final caller = MessagingTransportFactory(
        _apiClient(),
        signalingFactory: ({required selfId, required friendId}) =>
            callerSignaling,
        p2pIceConfiguration: const {'iceServers': <Object>[]},
      ).create(selfId: 1, friendId: 2, isCaller: true);
      final answerer = MessagingTransportFactory(
        _apiClient(),
        signalingFactory: ({required selfId, required friendId}) =>
            answererSignaling,
        p2pIceConfiguration: const {'iceServers': <Object>[]},
      ).create(selfId: 2, friendId: 1, isCaller: false);
      final callerSelection = caller as FallbackMessageTransport;
      final answererSelection = answerer as FallbackMessageTransport;
      final callerPeer = callerSelection.primary as P2PMessageTransport;
      final answererPeer = answererSelection.primary as P2PMessageTransport;
      expect(callerSelection.fallback, isA<ServerMessageTransport>());
      expect(answererSelection.fallback, isA<ServerMessageTransport>());
      final receiverRepository = MessageRepository();
      final senderRepository = MessageRepository();
      const messageId = 'webrtc-runtime-message';
      const conversationId = '1:2';
      final callerCredentials = _MemoryCredentials();
      final answererCredentials = _MemoryCredentials();
      final callerIdentity = await SecureDeviceIdentity.restore(
        credentials: callerCredentials,
      );
      final answererIdentity = await SecureDeviceIdentity.restore(
        credentials: answererCredentials,
      );
      final callerTrust = PeerTrustService(credentials: callerCredentials);
      final answererTrust = PeerTrustService(credentials: answererCredentials);
      final callerInvitation = callerTrust.createInvitation(callerIdentity);
      final answererInvitation = answererTrust.createInvitation(
        answererIdentity,
      );
      await callerTrust.trustInvitation(
        answererInvitation.encode(),
        confirmedFingerprint: answererInvitation.fingerprint,
      );
      await answererTrust.trustInvitation(
        callerInvitation.encode(),
        confirmedFingerprint: callerInvitation.fingerprint,
      );
      final callerAuthenticator = callerTrust.remoteAuthenticator(
        local: callerIdentity,
      );
      final forgedVerification = Completer<bool>();
      final answererAuthenticator = _ObservedAuthenticator(
        delegate: answererTrust.remoteAuthenticator(local: answererIdentity),
        observedEventId: 'webrtc-forged',
        onObserved: forgedVerification.complete,
      );
      final callerEngine = MessageSyncEngine(
        repository: senderRepository,
        transport: caller,
        authenticator: callerAuthenticator,
      );
      final answererEngine = MessageSyncEngine(
        repository: receiverRepository,
        transport: answerer,
        authenticator: answererAuthenticator,
      );
      final callerConnectionStates = <bool>[];
      final callerConnectionStateSubscription = callerPeer
          .connectionStateChanges
          .listen(callerConnectionStates.add);

      try {
        await Future.wait([
          callerEngine.start(),
          answererEngine.start(),
        ]).timeout(
          const Duration(seconds: 20),
          onTimeout: () => throw TimeoutException(
            'Timed out opening the loopback WebRTC data channel',
          ),
        );
        expect(callerPeer.isConnected, isTrue);
        expect(answererPeer.isConnected, isTrue);

        Future<MessageProjection> waitForProjection(
          MessageRepository repository,
          int revision,
        ) {
          final current = repository.projectionFor(messageId);
          if (current != null && current.revision >= revision) {
            return Future.value(current);
          }
          return repository.changes
              .firstWhere(
                (projection) =>
                    projection.messageId == messageId &&
                    projection.revision >= revision,
              )
              .timeout(const Duration(seconds: 5));
        }

        Future<void> transmit({
          required MessageEvent event,
          required MessageSyncEngine senderEngine,
          required MessageRepository senderEvents,
          required EventAuthenticator senderAuthenticator,
          required MessageRepository receiverEvents,
          required int revision,
        }) async {
          final received = waitForProjection(receiverEvents, revision);
          await senderEvents.addLocal(
            event,
            authenticator: senderAuthenticator,
          );
          await senderEngine.syncNow();
          await received;
        }

        final createdAt = DateTime.utc(2026, 1, 1);
        MessageEvent event({
          required String eventId,
          required String actorId,
          required MessageEventType type,
          required int revision,
          String? body,
        }) => MessageEvent(
          eventId: eventId,
          messageId: messageId,
          conversationId: conversationId,
          actorId: actorId,
          deviceId: actorId == '1'
              ? callerIdentity.deviceId
              : answererIdentity.deviceId,
          type: type,
          revision: revision,
          createdAt: createdAt.add(Duration(seconds: revision)),
          body: body,
        );

        await transmit(
          event: event(
            eventId: 'webrtc-created',
            actorId: '1',
            type: MessageEventType.created,
            revision: 0,
            body: 'original',
          ),
          senderEngine: callerEngine,
          senderEvents: senderRepository,
          senderAuthenticator: callerAuthenticator,
          receiverEvents: receiverRepository,
          revision: 0,
        );
        await transmit(
          event: event(
            eventId: 'webrtc-read',
            actorId: '2',
            type: MessageEventType.read,
            revision: 1,
          ),
          senderEngine: answererEngine,
          senderEvents: receiverRepository,
          senderAuthenticator: answererAuthenticator,
          receiverEvents: senderRepository,
          revision: 1,
        );
        await transmit(
          event: event(
            eventId: 'webrtc-edited',
            actorId: '1',
            type: MessageEventType.edited,
            revision: 2,
            body: 'edited after read',
          ),
          senderEngine: callerEngine,
          senderEvents: senderRepository,
          senderAuthenticator: callerAuthenticator,
          receiverEvents: receiverRepository,
          revision: 2,
        );
        await transmit(
          event: event(
            eventId: 'webrtc-recalled',
            actorId: '1',
            type: MessageEventType.recalled,
            revision: 3,
          ),
          senderEngine: callerEngine,
          senderEvents: senderRepository,
          senderAuthenticator: callerAuthenticator,
          receiverEvents: receiverRepository,
          revision: 3,
        );

        final projection = receiverRepository.projectionFor(messageId);
        expect(projection?.readBy, contains('2'));
        expect(projection?.revision, 3);
        expect(projection?.visibleBody, recalledMessageText);
        expect(receiverRepository.events, hasLength(4));

        final forged = event(
          eventId: 'webrtc-forged',
          actorId: '1',
          type: MessageEventType.edited,
          revision: 4,
          body: 'forged edit',
        ).withSignature('ed25519:invalid');
        await caller.send(forged);
        expect(
          await forgedVerification.future.timeout(const Duration(seconds: 5)),
          isFalse,
        );
        await _waitUntil(() => receiverRepository.conflicts.isNotEmpty);
        expect(
          receiverRepository.conflicts.single.reason,
          contains('signature is invalid'),
        );
        expect(
          receiverRepository.projectionFor(messageId)?.visibleBody,
          recalledMessageText,
        );
        expect(receiverRepository.events, hasLength(4));

        await callerPeer.disconnect();
        expect(callerConnectionStates, containsAllInOrder([true, false]));
        expect(callerSelection.p2pActive, isFalse);
        expect(callerSelection.relayChoiceRequired, isTrue);
        expect(callerSelection.relayActive, isFalse);
      } finally {
        await callerConnectionStateSubscription.cancel();
        await callerEngine.stop();
        await answererEngine.stop();
        await callerSelection.dispose();
        await answererSelection.dispose();
        callerSignaling.dispose();
        answererSignaling.dispose();
      }
    },
  );
}

ApiClient _apiClient() => ApiClient(
  client: MockClient((_) async => throw StateError('unexpected HTTP request')),
  configuration: const AppConfiguration(
    apiBaseUrl: 'https://example.test',
    googleWebClientId: 'test-web-client',
    googleServerClientId: 'test-server-client',
    p2pChatEnabled: true,
  ),
);

Future<void> _waitUntil(bool Function() condition) async {
  final deadline = DateTime.now().add(const Duration(seconds: 5));
  while (!condition()) {
    if (DateTime.now().isAfter(deadline)) {
      throw TimeoutException('Condition was not met before the deadline');
    }
    await Future<void>.delayed(const Duration(milliseconds: 5));
  }
}

class _ObservedAuthenticator implements EventAuthenticator {
  const _ObservedAuthenticator({
    required this.delegate,
    required this.observedEventId,
    required this.onObserved,
  });

  final EventAuthenticator delegate;
  final String observedEventId;
  final void Function(bool valid) onObserved;

  @override
  Future<String> sign(MessageEvent event) => delegate.sign(event);

  @override
  Future<bool> verify(MessageEvent event) async {
    final valid = await delegate.verify(event);
    if (event.eventId == observedEventId) onObserved(valid);
    return valid;
  }
}

class _MemoryCredentials implements CredentialStore {
  final Map<String, String> _values = {};

  @override
  Future<String?> read(String key) async => _values[key];

  @override
  Future<void> write(String key, String value) async => _values[key] = value;

  @override
  Future<void> delete(String key) async => _values.remove(key);
}

class _LoopbackSignaling implements PeerSignalingChannel {
  _LoopbackSignaling._();

  final StreamController<Map<String, dynamic>> _incoming =
      StreamController<Map<String, dynamic>>.broadcast();
  late _LoopbackSignaling _peer;
  bool _disposed = false;

  static (_LoopbackSignaling, _LoopbackSignaling) pair() {
    final first = _LoopbackSignaling._();
    final second = _LoopbackSignaling._();
    first._peer = second;
    second._peer = first;
    return (first, second);
  }

  @override
  Stream<Map<String, dynamic>> get signalStream => _incoming.stream;

  @override
  Future<void> connect(int peerId) async {
    if (_disposed) throw StateError('Loopback signaling is disposed');
  }

  @override
  void send(int peerId, Map<String, dynamic> payload) {
    if (!_disposed && !_peer._disposed) {
      _peer._incoming.add(Map<String, dynamic>.from(payload));
    }
  }

  @override
  void disconnect() {}

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    unawaited(_incoming.close());
  }
}

class _BufferedSignaling implements PeerSignalingChannel {
  _BufferedSignaling._();

  final StreamController<Map<String, dynamic>> _incoming =
      StreamController<Map<String, dynamic>>.broadcast();
  final List<Map<String, dynamic>> _pending = [];
  late _BufferedSignaling peer;
  bool _disposed = false;

  static _BufferedSignaling pair() {
    final first = _BufferedSignaling._();
    final second = _BufferedSignaling._();
    first.peer = second;
    second.peer = first;
    return first;
  }

  bool get hasOfferAndCandidate =>
      _pending.any((signal) => signal['type'] == 'offer') &&
      _pending.any((signal) => signal['type'] == 'ice_candidate');

  bool get hasAnswerAndCandidate =>
      _pending.any((signal) => signal['type'] == 'answer') &&
      _pending.any((signal) => signal['type'] == 'ice_candidate');

  @override
  Stream<Map<String, dynamic>> get signalStream => _incoming.stream;

  @override
  Future<void> connect(int peerId) async {
    if (_disposed) throw StateError('Buffered signaling is disposed');
  }

  @override
  void send(int peerId, Map<String, dynamic> payload) {
    if (!_disposed) _pending.add(Map<String, dynamic>.from(payload));
  }

  void deliverPendingInReverseOrder() {
    final pending = List<Map<String, dynamic>>.from(_pending.reversed);
    _pending.clear();
    for (final signal in pending) {
      if (!peer._disposed) peer._incoming.add(signal);
    }
  }

  @override
  void disconnect() {}

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    unawaited(_incoming.close());
    _pending.clear();
  }
}

class _UnusedMessageTransport implements MessageTransport {
  @override
  Stream<MessageEvent> get events => const Stream<MessageEvent>.empty();

  @override
  Future<void> connect() async {}

  @override
  Future<void> disconnect() async {}

  @override
  Future<void> send(MessageEvent event) async {
    throw StateError('The relay must not be selected in this test');
  }
}
