import 'dart:async';
import 'dart:convert';

import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:taiwan_brawl_messaging/taiwan_brawl_messaging.dart';

import 'api_client.dart';
import 'room_socket_channel.dart';

typedef SignalingChannelFactory =
    WebSocketChannel Function(Uri uri, {Map<String, dynamic>? headers});

/// Handles WebRTC signaling over a WebSocket connection to SignalRoom DO.
/// Relays offer / answer / ice_candidate messages between peers.
class SignalingService implements PeerSignalingChannel {
  SignalingService(this._apiClient, {SignalingChannelFactory? channelFactory})
    : _channelFactory = channelFactory ?? connectRoomSocket;

  final ApiClient _apiClient;
  final SignalingChannelFactory _channelFactory;

  WebSocketChannel? _channel;
  StreamSubscription<dynamic>? _channelSubscription;
  int? _friendId;

  final StreamController<Map<String, dynamic>> _signalStream =
      StreamController.broadcast();

  /// Emits raw signaling payloads received from the peer.
  @override
  Stream<Map<String, dynamic>> get signalStream => _signalStream.stream;

  bool get isConnected => _channel != null;

  @override
  Future<void> connect(int friendId) async {
    if (_friendId == friendId && isConnected) return;
    disconnect();
    _friendId = friendId;

    final baseUri = Uri.parse(_apiClient.apiBaseUrl);
    final scheme = baseUri.scheme == 'https' ? 'wss' : 'ws';
    final uri = baseUri.replace(
      scheme: scheme,
      path: '/api/chat/signal/$friendId',
      query: '',
    );

    final headers = await _apiClient.loadWebSocketHeaders();
    if (_friendId != friendId) return;
    try {
      _channel = _channelFactory(uri, headers: headers);
    } catch (_) {
      _friendId = null;
      rethrow;
    }

    final channel = _channel!;
    _channelSubscription = channel.stream.listen(
      (raw) {
        try {
          final payload = jsonDecode(raw as String) as Map<String, dynamic>;
          _signalStream.add(payload);
        } catch (_) {}
      },
      onDone: () {
        if (identical(_channel, channel)) {
          _channel = null;
          _friendId = null;
        }
      },
      onError: (_) {
        if (identical(_channel, channel)) {
          _channel = null;
          _friendId = null;
        }
      },
      cancelOnError: false,
    );
  }

  /// Send a signaling payload to the peer via the server.
  /// [targetUserId] is the peer's user id.
  @override
  void send(int targetUserId, Map<String, dynamic> payload) {
    _channel?.sink.add(jsonEncode({...payload, 'targetUserId': targetUserId}));
  }

  @override
  void disconnect() {
    unawaited(_channelSubscription?.cancel());
    _channelSubscription = null;
    _channel?.sink.close();
    _channel = null;
    _friendId = null;
  }

  @override
  void dispose() {
    disconnect();
    _signalStream.close();
  }
}
