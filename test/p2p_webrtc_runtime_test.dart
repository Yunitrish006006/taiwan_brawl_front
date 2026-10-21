@TestOn('chrome')
library;

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:taiwan_brawl/services/p2p_message_transport.dart';
import 'package:taiwan_brawl_messaging/taiwan_brawl_messaging.dart';

void main() {
  test(
    'opens two real browser WebRTC data channels and carries an event',
    () async {
      final (callerSignaling, answererSignaling) = _LoopbackSignaling.pair();
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

      try {
        await Future.wait([caller.connect(), answerer.connect()]).timeout(
          const Duration(seconds: 20),
          onTimeout: () => throw TimeoutException(
            'Timed out opening the loopback WebRTC data channel',
          ),
        );
        expect(caller.isConnected, isTrue);
        expect(answerer.isConnected, isTrue);

        final received = answerer.events.first.timeout(
          const Duration(seconds: 5),
        );
        final event = MessageEvent(
          eventId: 'webrtc-runtime-event',
          messageId: 'webrtc-runtime-message',
          conversationId: '1:2',
          actorId: '1',
          type: MessageEventType.created,
          revision: 0,
          createdAt: DateTime.utc(2026, 1, 1),
          body: 'real browser data channel',
        );
        await caller.send(event);
        expect((await received).toJson(), event.toJson());
      } finally {
        await caller.dispose();
        await answerer.dispose();
        callerSignaling.dispose();
        answererSignaling.dispose();
      }
    },
  );
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
