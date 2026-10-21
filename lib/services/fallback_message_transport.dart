import 'dart:async';

import 'package:taiwan_brawl_messaging/taiwan_brawl_messaging.dart';

/// Connects a preferred transport first and falls back to a durable relay
/// transport when the preferred path cannot be established.
class FallbackMessageTransport implements MessageReceiptTransport {
  FallbackMessageTransport({required this.primary, required this.fallback});

  final MessageTransport primary;
  final MessageTransport fallback;

  final StreamController<MessageEvent> _events =
      StreamController<MessageEvent>.broadcast();
  StreamSubscription<MessageEvent>? _subscription;
  MessageTransport? _active;

  @override
  Stream<MessageEvent> get events => _events.stream;

  @override
  Future<void> connect() async {
    if (_active != null) return;
    try {
      await primary.connect();
      _active = primary;
    } catch (_) {
      await primary.disconnect();
      _active = null;
      await _connectFallback();
    }
    await _listenToActive();
  }

  @override
  Future<void> send(MessageEvent event) async {
    final active = _active;
    if (active == null) throw StateError('Message transport is not connected');
    try {
      await active.send(event);
    } catch (_) {
      if (!identical(active, primary)) rethrow;
      await primary.disconnect();
      _active = null;
      try {
        await _connectFallback();
        await _listenToActive();
        await fallback.send(event);
      } catch (_) {
        await fallback.disconnect();
        _active = null;
        rethrow;
      }
    }
  }

  @override
  Future<void> acknowledgeReceived(
    MessageEvent event, {
    required bool accepted,
  }) async {
    final active = _active;
    if (active case final MessageReceiptTransport receiptTransport) {
      await receiptTransport.acknowledgeReceived(event, accepted: accepted);
    }
  }

  @override
  Future<void> disconnect() async {
    await _subscription?.cancel();
    _subscription = null;
    await primary.disconnect();
    await fallback.disconnect();
    _active = null;
  }

  Future<void> _connectFallback() async {
    await fallback.connect();
    _active = fallback;
  }

  Future<void> _listenToActive() async {
    await _subscription?.cancel();
    _subscription = _active!.events.listen(
      _events.add,
      onError: _events.addError,
    );
  }

  Future<void> dispose() async {
    await disconnect();
    await _events.close();
  }
}
