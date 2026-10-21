import 'dart:async';

import 'message_event.dart';
import 'message_repository.dart';
import 'message_transport.dart';

/// Connects a local event repository to any message transport.
///
/// The repository remains the durable local source of truth. This coordinator
/// only connects streams and drains the outbox; it does not know whether the
/// transport is WebRTC, server-backed, or a deterministic test adapter.
class MessageSyncEngine {
  MessageSyncEngine({
    required this.repository,
    required this.transport,
    this.authenticator,
    this.onRemoteEvent,
    this.eventFilter,
  });

  final MessageRepository repository;
  final MessageTransport transport;
  final EventAuthenticator? authenticator;
  final FutureOr<void> Function(MessageEvent event)? onRemoteEvent;
  final bool Function(MessageEvent event)? eventFilter;
  StreamSubscription<MessageEvent>? _subscription;
  Future<void> _remoteTail = Future<void>.value();
  bool _started = false;

  bool get started => _started;

  Future<void> start() async {
    if (_started) return;
    _subscription = transport.events.listen(_handleRemoteEvent);
    try {
      await transport.connect();
      _started = true;
      await _remoteTail;
      await syncNow();
    } catch (_) {
      await _subscription?.cancel();
      _subscription = null;
      await transport.disconnect();
      _started = false;
      rethrow;
    }
  }

  void _handleRemoteEvent(MessageEvent event) {
    final run = _remoteTail.then<void>((_) => _processRemoteEvent(event));
    _remoteTail = run.catchError((Object _, StackTrace __) {});
  }

  Future<void> _processRemoteEvent(MessageEvent event) async {
    final accepted = await repository.acceptRemote(
      event,
      authenticator: authenticator,
    );
    if (transport case final MessageReceiptTransport receiptTransport) {
      await receiptTransport.acknowledgeReceived(event, accepted: accepted);
    }
    if (accepted) await onRemoteEvent?.call(event);
  }

  Future<void> syncNow() async {
    if (!_started) throw StateError('Message sync engine is not started');
    await repository.flush(transport, shouldSend: eventFilter);
  }

  Future<void> stop() async {
    await _subscription?.cancel();
    _subscription = null;
    await _remoteTail;
    await transport.disconnect();
    _started = false;
  }
}
