import 'dart:async';

import 'package:taiwan_brawl_messaging/taiwan_brawl_messaging.dart';

import 'connection_aware_message_transport.dart';

class RelayFallbackChoiceRequired implements Exception {
  const RelayFallbackChoiceRequired(this.cause);

  final Object cause;

  @override
  String toString() =>
      'P2P is unavailable; player choice is required for relay';
}

/// Connects a preferred transport first and falls back to a durable relay
/// only after the player chooses it.
class FallbackMessageTransport implements MessageReceiptTransport {
  FallbackMessageTransport({required this.primary, required this.fallback}) {
    final primaryTransport = primary;
    if (primaryTransport is ConnectionAwareMessageTransport) {
      final stateAware = primaryTransport as ConnectionAwareMessageTransport;
      _primaryStateSubscription = stateAware.connectionStateChanges.listen(
        _handlePrimaryConnectionState,
      );
    }
  }

  final MessageTransport primary;
  final MessageTransport fallback;

  final StreamController<MessageEvent> _events =
      StreamController<MessageEvent>.broadcast();
  final StreamController<void> _connectionChanges =
      StreamController<void>.broadcast();
  StreamSubscription<MessageEvent>? _subscription;
  StreamSubscription<bool>? _primaryStateSubscription;
  MessageTransport? _active;
  bool _relayChoiceRequired = false;
  bool _relaySelected = false;

  @override
  Stream<MessageEvent> get events => _events.stream;

  Stream<void> get connectionStateChanges => _connectionChanges.stream;

  bool get relayChoiceRequired => _relayChoiceRequired;
  bool get p2pActive {
    if (!identical(_active, primary)) return false;
    final transport = primary;
    return transport is! ConnectionAwareMessageTransport ||
        (transport as ConnectionAwareMessageTransport).isTransportConnected;
  }

  bool get relayActive => identical(_active, fallback);

  /// Retries only the primary P2P transport while relay has not been chosen.
  /// A failed retry keeps the consent prompt state and never connects relay.
  Future<bool> retryPrimary() async {
    if (_relaySelected || relayActive) return false;
    if (p2pActive) return true;
    _relayChoiceRequired = false;
    try {
      await _subscription?.cancel();
      _subscription = null;
      if (identical(_active, primary)) {
        _active = null;
        await primary.disconnect();
      }
      await _connectAndListen(primary);
      return true;
    } catch (_) {
      _relayChoiceRequired = true;
      return false;
    }
  }

  @override
  Future<void> connect() async {
    if (_active != null) return;
    if (_relaySelected) {
      try {
        await _connectAndListen(fallback);
      } catch (_) {
        _relayChoiceRequired = true;
        rethrow;
      }
      return;
    }
    if (_relayChoiceRequired) {
      throw RelayFallbackChoiceRequired(
        StateError('P2P connection requires a relay choice'),
      );
    }
    try {
      await _connectAndListen(primary);
    } catch (error) {
      _active = null;
      await _subscription?.cancel();
      _subscription = null;
      _relayChoiceRequired = true;
      throw RelayFallbackChoiceRequired(error);
    }
  }

  @override
  Future<void> send(MessageEvent event) async {
    final active = _active;
    if (active == null) throw StateError('Message transport is not connected');
    try {
      await active.send(event);
    } catch (error) {
      await active.disconnect();
      await _subscription?.cancel();
      _subscription = null;
      _active = null;
      _relayChoiceRequired = true;
      if (identical(active, primary)) {
        throw RelayFallbackChoiceRequired(error);
      }
      rethrow;
    }
  }

  /// Records the player's explicit consent. The sync engine then reconnects
  /// this transport so its listener is installed before the relay's first poll.
  void selectRelayFallback() {
    if (_relaySelected) {
      _relayChoiceRequired = false;
      return;
    }
    if (!_relayChoiceRequired && !_relaySelected) {
      throw StateError('Relay fallback was not requested');
    }
    _relaySelected = true;
    _relayChoiceRequired = false;
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
    _active = null;
    await _subscription?.cancel();
    _subscription = null;
    await primary.disconnect();
    await fallback.disconnect();
    _notifyConnectionChanged();
  }

  Future<void> _connectAndListen(MessageTransport transport) async {
    _active = transport;
    _subscription = transport.events.listen(
      _events.add,
      onError: _events.addError,
    );
    try {
      await transport.connect();
    } catch (_) {
      await _subscription?.cancel();
      _subscription = null;
      _active = null;
      await transport.disconnect();
      rethrow;
    }
  }

  Future<void> dispose() async {
    await disconnect();
    await _primaryStateSubscription?.cancel();
    _primaryStateSubscription = null;
    await _events.close();
    await _connectionChanges.close();
  }

  void _handlePrimaryConnectionState(bool connected) {
    if (_relaySelected || !identical(_active, primary)) return;
    _relayChoiceRequired = !connected;
    _notifyConnectionChanged();
  }

  void _notifyConnectionChanged() {
    if (!_connectionChanges.isClosed) _connectionChanges.add(null);
  }
}
