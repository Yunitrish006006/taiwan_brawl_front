import 'dart:async';
import 'dart:convert';

import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:taiwan_brawl_messaging/taiwan_brawl_messaging.dart';

/// Adapts one ordered WebRTC DataChannel to the shared message transport.
///
/// Signaling and peer-connection lifecycle remain owned by the frontend's
/// WebRTC coordinator. This class only serializes verified event envelopes and
/// exposes them through the transport-neutral port.
class WebRtcMessageTransport implements MessageTransport {
  WebRtcMessageTransport(this._channel);

  final RTCDataChannel _channel;
  final StreamController<MessageEvent> _events =
      StreamController<MessageEvent>.broadcast();
  bool _connected = false;

  @override
  Stream<MessageEvent> get events => _events.stream;

  @override
  Future<void> connect() async {
    if (_channel.state == RTCDataChannelState.RTCDataChannelOpen) {
      _connected = true;
      _bindMessageHandler();
      return;
    }
    final completer = Completer<void>();
    late void Function(RTCDataChannelState) listener;
    listener = (state) {
      if (state == RTCDataChannelState.RTCDataChannelOpen &&
          !completer.isCompleted) {
        _connected = true;
        _bindMessageHandler();
        completer.complete();
      } else if (state == RTCDataChannelState.RTCDataChannelClosed &&
          !completer.isCompleted) {
        completer.completeError(StateError('WebRTC data channel closed'));
      }
    };
    _channel.onDataChannelState = listener;
    await completer.future;
  }

  @override
  Future<void> send(MessageEvent event) async {
    if (!_connected ||
        _channel.state != RTCDataChannelState.RTCDataChannelOpen) {
      throw StateError('WebRTC message transport is not connected');
    }
    _channel.send(RTCDataChannelMessage(jsonEncode(event.toJson())));
  }

  @override
  Future<void> disconnect() async {
    _connected = false;
    await _channel.close();
  }

  Future<void> dispose() async {
    await disconnect();
    await _events.close();
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
