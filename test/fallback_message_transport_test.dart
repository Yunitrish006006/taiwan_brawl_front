import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:taiwan_brawl_messaging/taiwan_brawl_messaging.dart';
import 'package:taiwan_brawl/services/fallback_message_transport.dart';

void main() {
  test(
    'falls back to relay when the preferred transport cannot connect',
    () async {
      final primary = _FakeTransport(connectError: StateError('offline'));
      final fallback = _FakeTransport();
      final transport = FallbackMessageTransport(
        primary: primary,
        fallback: fallback,
      );
      addTearDown(transport.dispose);

      await transport.connect();
      final event = MessageEvent(
        eventId: 'event-1',
        messageId: 'message-1',
        conversationId: '1:2',
        actorId: '1',
        type: MessageEventType.created,
        revision: 0,
        createdAt: DateTime.utc(2026, 1, 1),
        body: 'offline-safe',
      );
      await transport.send(event);

      expect(primary.connectCalls, 1);
      expect(primary.disconnectCalls, 1);
      expect(fallback.connectCalls, 1);
      expect(fallback.sent, [event]);
    },
  );

  test(
    'switches to relay when the preferred transport fails during send',
    () async {
      final primary = _FakeTransport(sendError: StateError('peer-lost'));
      final fallback = _FakeTransport();
      final transport = FallbackMessageTransport(
        primary: primary,
        fallback: fallback,
      );
      addTearDown(transport.dispose);

      await transport.connect();
      final event = MessageEvent(
        eventId: 'event-2',
        messageId: 'message-2',
        conversationId: '1:2',
        actorId: '1',
        type: MessageEventType.edited,
        revision: 1,
        createdAt: DateTime.utc(2026, 1, 1),
        body: 'relay-recovery',
      );
      await transport.send(event);

      expect(primary.connectCalls, 1);
      expect(primary.disconnectCalls, 1);
      expect(fallback.connectCalls, 1);
      expect(fallback.sent, [event]);
    },
  );

  test('clears the active transport when relay recovery also fails', () async {
    final primary = _FakeTransport(sendError: StateError('peer-lost'));
    final fallback = _FakeTransport(connectError: StateError('relay-offline'));
    final transport = FallbackMessageTransport(
      primary: primary,
      fallback: fallback,
    );
    addTearDown(transport.dispose);

    await transport.connect();
    final event = MessageEvent(
      eventId: 'event-3',
      messageId: 'message-3',
      conversationId: '1:2',
      actorId: '1',
      type: MessageEventType.created,
      revision: 0,
      createdAt: DateTime.utc(2026, 1, 1),
      body: 'recovery-fails',
    );

    await expectLater(transport.send(event), throwsStateError);
    await expectLater(transport.send(event), throwsStateError);
    expect(primary.disconnectCalls, greaterThanOrEqualTo(1));
    expect(fallback.disconnectCalls, greaterThanOrEqualTo(1));
  });
}

class _FakeTransport implements MessageTransport {
  _FakeTransport({this.connectError, this.sendError});

  final Object? connectError;
  final Object? sendError;
  final StreamController<MessageEvent> _events =
      StreamController<MessageEvent>.broadcast();
  final List<MessageEvent> sent = <MessageEvent>[];
  int connectCalls = 0;
  int disconnectCalls = 0;

  @override
  Stream<MessageEvent> get events => _events.stream;

  @override
  Future<void> connect() async {
    connectCalls++;
    if (connectError != null) throw connectError!;
  }

  @override
  Future<void> send(MessageEvent event) async {
    if (sendError != null) throw sendError!;
    sent.add(event);
  }

  @override
  Future<void> disconnect() async {
    disconnectCalls++;
  }
}
