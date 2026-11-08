import 'dart:async';
import 'dart:convert';

import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:taiwan_brawl_messaging/taiwan_brawl_messaging.dart';

import 'connection_aware_message_transport.dart';

/// Adapts one ordered WebRTC DataChannel to the shared message transport.
///
/// Signaling and peer-connection lifecycle remain owned by the frontend's
/// WebRTC coordinator. This class only serializes verified event envelopes and
/// exposes them through the transport-neutral port.
class WebRtcMessageTransport
    implements MessageTransport, ConnectionAwareMessageTransport {
  WebRtcMessageTransport(this._channel);

  final RTCDataChannel _channel;
  final StreamController<MessageEvent> _events =
      StreamController<MessageEvent>.broadcast();
  final StreamController<bool> _connectionStates =
      StreamController<bool>.broadcast();
  bool _connected = false;
  Completer<void>? _connectCompleter;

  @override
  Stream<MessageEvent> get events => _events.stream;

  @override
  Stream<bool> get connectionStateChanges => _connectionStates.stream;

  @override
  bool get isTransportConnected =>
      _connected && _channel.state == RTCDataChannelState.RTCDataChannelOpen;

  @override
  Future<void> connect() async {
    _channel.onDataChannelState = _handleChannelState;
    if (_channel.state == RTCDataChannelState.RTCDataChannelOpen) {
      _setConnected(true);
      _bindMessageHandler();
      return;
    }
    final completer = Completer<void>();
    _connectCompleter = completer;
    await completer.future;
  }

  @override
  Future<void> send(MessageEvent event) async {
    if (!isTransportConnected ||
        _channel.state != RTCDataChannelState.RTCDataChannelOpen) {
      throw StateError('WebRTC message transport is not connected');
    }
    _channel.send(RTCDataChannelMessage(jsonEncode(event.toJson())));
  }

  @override
  Future<void> disconnect() async {
    _setConnected(false);
    await _channel.close();
  }

  Future<void> dispose() async {
    await disconnect();
    await _events.close();
    await _connectionStates.close();
  }

  void _handleChannelState(RTCDataChannelState state) {
    if (state == RTCDataChannelState.RTCDataChannelOpen) {
      _setConnected(true);
      _bindMessageHandler();
      final completer = _connectCompleter;
      if (completer != null && !completer.isCompleted) completer.complete();
      return;
    }
    if (state == RTCDataChannelState.RTCDataChannelClosed) {
      final completer = _connectCompleter;
      _setConnected(false);
      if (completer != null && !completer.isCompleted) {
        completer.completeError(StateError('WebRTC data channel closed'));
      }
    }
  }

  void _setConnected(bool connected) {
    if (_connected == connected) return;
    _connected = connected;
    if (!_connectionStates.isClosed) _connectionStates.add(connected);
    if (!connected) _connectCompleter = null;
  }

  void _bindMessageHandler() {
    _channel.onMessage = (message) {
      try {
        final decoded = jsonDecode(message.text);
        if (decoded is! Map) {
          throw const FormatException('Event is not an object');
        }
        _events.add(MessageEvent.fromJson(Map<String, Object?>.from(decoded)));
      } catch (error, stackTrace) {
        _events.addError(error, stackTrace);
      }
    };
  }
}
