import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:taiwan_brawl_messaging/taiwan_brawl_messaging.dart';
import 'package:taiwan_brawl/services/connection_aware_message_transport.dart';
import 'package:taiwan_brawl/services/fallback_message_transport.dart';

void main() {
  test('waits for player consent before connecting the relay', () async {
    final primary = _FakeTransport(connectError: StateError('offline'));
    final fallback = _FakeTransport();
    final transport = FallbackMessageTransport(
      primary: primary,
      fallback: fallback,
    );
    addTearDown(transport.dispose);

    await expectLater(
      transport.connect(),
      throwsA(isA<RelayFallbackChoiceRequired>()),
    );
    expect(transport.relayChoiceRequired, isTrue);
    expect(fallback.connectCalls, 0);
    transport.selectRelayFallback();
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
  });

  test('requires player consent when P2P fails during send', () async {
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
    await expectLater(
      transport.send(event),
      throwsA(isA<RelayFallbackChoiceRequired>()),
    );

    expect(primary.connectCalls, 1);
    expect(primary.disconnectCalls, 1);
    expect(fallback.connectCalls, 0);
    expect(transport.relayChoiceRequired, isTrue);
    transport.selectRelayFallback();
    await transport.connect();
    await transport.send(event);
    expect(fallback.connectCalls, 1);
    expect(fallback.sent, [event]);
  });

  test('retries recovered P2P without connecting the relay', () async {
    final primary = _FakeTransport(
      connectErrors: [StateError('temporary outage'), null],
    );
    final fallback = _FakeTransport();
    final transport = FallbackMessageTransport(
      primary: primary,
      fallback: fallback,
    );
    addTearDown(transport.dispose);

    await expectLater(
      transport.connect(),
      throwsA(isA<RelayFallbackChoiceRequired>()),
    );
    expect(transport.relayChoiceRequired, isTrue);
    expect(await transport.retryPrimary(), isTrue);

    expect(transport.p2pActive, isTrue);
    expect(transport.relayChoiceRequired, isFalse);
    expect(primary.connectCalls, 2);
    expect(fallback.connectCalls, 0);
  });

  test('reports P2P loss and recovery without selecting the relay', () async {
    final primary = _ConnectionAwareTransport();
    final fallback = _FakeTransport();
    final transport = FallbackMessageTransport(
      primary: primary,
      fallback: fallback,
    );
    addTearDown(primary.dispose);
    addTearDown(transport.dispose);

    await transport.connect();
    expect(transport.p2pActive, isTrue);

    final lost = Completer<void>();
    final changes = transport.connectionStateChanges.listen((_) {
      if (transport.relayChoiceRequired && !lost.isCompleted) lost.complete();
    });
    addTearDown(changes.cancel);
    primary.setConnected(false);
    await lost.future;
    expect(transport.p2pActive, isFalse);
    expect(transport.relayChoiceRequired, isTrue);
    expect(fallback.connectCalls, 0);

    final recovered = Completer<void>();
    final recoveryChanges = transport.connectionStateChanges.listen((_) {
      if (transport.p2pActive && !recovered.isCompleted) {
        recovered.complete();
      }
    });
    addTearDown(recoveryChanges.cancel);
    primary.setConnected(true);
    await recovered.future;
    expect(transport.p2pActive, isTrue);
    expect(transport.relayChoiceRequired, isFalse);
    expect(fallback.connectCalls, 0);
  });

  test('relay failure remains visible after the player chooses it', () async {
    final primary = _FakeTransport(connectError: StateError('offline'));
    final fallback = _FakeTransport(
      connectErrors: [StateError('relay-offline'), null],
    );
    final transport = FallbackMessageTransport(
      primary: primary,
      fallback: fallback,
    );
    addTearDown(transport.dispose);

    await expectLater(
      transport.connect(),
      throwsA(isA<RelayFallbackChoiceRequired>()),
    );
    transport.selectRelayFallback();
    await expectLater(transport.connect(), throwsStateError);
    expect(transport.relayChoiceRequired, isTrue);
    expect(fallback.connectCalls, 1);

    // The player's relay choice remains selected, so retrying does not
    // reconnect P2P or require consent a second time.
    transport.selectRelayFallback();
    await transport.connect();
    expect(transport.relayChoiceRequired, isFalse);
    expect(primary.connectCalls, 1);
    expect(fallback.connectCalls, 2);
    expect(primary.disconnectCalls, greaterThanOrEqualTo(1));
    expect(fallback.disconnectCalls, greaterThanOrEqualTo(1));
  });
}

class _FakeTransport implements MessageTransport {
  _FakeTransport({
    this.connectError,
    List<Object?>? connectErrors,
    this.sendError,
  }) : connectErrors = connectErrors == null ? null : List.of(connectErrors);

  Object? connectError;
  final List<Object?>? connectErrors;
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
    final errors = connectErrors;
    final error = errors == null
        ? connectError
        : (errors.isEmpty ? null : errors.removeAt(0));
    if (error != null) throw error;
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

class _ConnectionAwareTransport extends _FakeTransport
    implements ConnectionAwareMessageTransport {
  final StreamController<bool> _states = StreamController<bool>.broadcast();
  bool _connected = false;

  @override
  Stream<bool> get connectionStateChanges => _states.stream;

  @override
  bool get isTransportConnected => _connected;

  @override
  Future<void> connect() async {
    await super.connect();
    setConnected(true);
  }

  @override
  Future<void> disconnect() async {
    await super.disconnect();
    setConnected(false);
  }

  void setConnected(bool connected) {
    _connected = connected;
    _states.add(connected);
  }

  Future<void> dispose() => _states.close();
}
