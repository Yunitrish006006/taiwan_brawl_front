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
    this.retryInterval,
  }) : assert(retryInterval == null || retryInterval.inMicroseconds > 0);

  final MessageRepository repository;
  final MessageTransport transport;
  final EventAuthenticator? authenticator;
  final FutureOr<void> Function(MessageEvent event)? onRemoteEvent;

  /// Restricts both outbound flushes and inbound events for this engine.
  final bool Function(MessageEvent event)? eventFilter;
  final Duration? retryInterval;
  StreamSubscription<MessageEvent>? _subscription;
  Future<void> _remoteTail = Future<void>.value();
  Timer? _retryTimer;
  Future<void>? _retryTask;
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
      _startRetryTimer();
    } catch (_) {
      _retryTimer?.cancel();
      _retryTimer = null;
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
    final inScope = eventFilter?.call(event) ?? true;
    final accepted = inScope
        ? await repository.acceptRemote(event, authenticator: authenticator)
        : false;
    final durablyHandled = inScope
        ? accepted
              ? repository.canDurablyRecordEvents
              : repository.canDurablyRecordConflicts
        : await repository.rejectRemote(
            event,
            reason: 'Message event is outside the active sync scope',
          );
    if (durablyHandled) {
      if (transport case final MessageReceiptTransport receiptTransport) {
        await receiptTransport.acknowledgeReceived(event, accepted: accepted);
      }
    }
    if (accepted) await onRemoteEvent?.call(event);
  }

  Future<void> syncNow() async {
    if (!_started) throw StateError('Message sync engine is not started');
    await repository.flush(transport, shouldSend: eventFilter);
  }

  void _startRetryTimer() {
    final interval = retryInterval;
    if (interval == null) return;
    _retryTimer?.cancel();
    _retryTimer = Timer.periodic(interval, (_) {
      if (!_started || _retryTask != null) return;
      final hasPendingEvent = repository.pendingOutbox.any(
        (event) => eventFilter?.call(event) ?? true,
      );
      if (!hasPendingEvent) return;
      final task = _retryOutbox();
      _retryTask = task;
      unawaited(
        task.whenComplete(() {
          if (identical(_retryTask, task)) _retryTask = null;
        }),
      );
    });
  }

  Future<void> _retryOutbox() async {
    try {
      await syncNow();
    } catch (_) {
      // Keep failed events durable and try them again on the next interval.
    }
  }

  Future<void> stop() async {
    _retryTimer?.cancel();
    _retryTimer = null;
    await _retryTask;
    await _subscription?.cancel();
    _subscription = null;
    await _remoteTail;
    await transport.disconnect();
    _started = false;
  }
}
