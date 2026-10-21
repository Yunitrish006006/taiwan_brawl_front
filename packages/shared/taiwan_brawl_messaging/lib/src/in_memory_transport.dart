import 'dart:async';

import 'message_event.dart';
import 'message_transport.dart';

/// Deterministic transport for tests and local simulation.
///
/// It intentionally models delivery only; it is not a WebRTC implementation.
class InMemoryMessageTransport implements MessageTransport {
  InMemoryMessageTransport._(this._incoming);

  final StreamController<MessageEvent> _incoming;
  late final StreamController<MessageEvent> _outgoing;
  bool _connected = false;

  static (InMemoryMessageTransport, InMemoryMessageTransport) pair() {
    final leftToRight = StreamController<MessageEvent>();
    final rightToLeft = StreamController<MessageEvent>();
    final left = InMemoryMessageTransport._(rightToLeft);
    final right = InMemoryMessageTransport._(leftToRight);
    left._outgoing = leftToRight;
    right._outgoing = rightToLeft;
    return (left, right);
  }

  @override
  Stream<MessageEvent> get events => _incoming.stream;

  @override
  Future<void> connect() async => _connected = true;

  @override
  Future<void> send(MessageEvent event) async {
    if (!_connected) throw StateError('Message transport is not connected');
    _outgoing.add(event);
  }

  @override
  Future<void> disconnect() async {
    _connected = false;
  }

  Future<void> dispose() async {
    // Each pair shares its two controllers: one side's incoming stream is the
    // other side's outgoing stream. Closing both from each endpoint would try
    // to close the same controller twice.
    await _incoming.close();
  }
}
