import 'dart:async';
import 'dart:convert';

import 'package:web_socket_channel/web_socket_channel.dart';

import '../constants/app_constants.dart';
import 'api_client.dart';
import 'room_socket_channel.dart';

/// Handles WebRTC signaling over a WebSocket connection to SignalRoom DO.
/// Relays offer / answer / ice_candidate messages between peers.
class SignalingService {
  SignalingService(this._apiClient);

  final ApiClient _apiClient;

  WebSocketChannel? _channel;
  int? _friendId;

  final StreamController<Map<String, dynamic>> _signalStream =
      StreamController.broadcast();

  /// Emits raw signaling payloads received from the peer.
  Stream<Map<String, dynamic>> get signalStream => _signalStream.stream;

  bool get isConnected => _channel != null;

  void connect(int friendId) {
    if (_friendId == friendId && isConnected) return;
    disconnect();
    _friendId = friendId;

    final baseUri = Uri.parse(AppConstants.apiBaseUrl);
    final scheme = baseUri.scheme == 'https' ? 'wss' : 'ws';
    final uri = baseUri.replace(
      scheme: scheme,
      path: '/api/chat/signal/$friendId',
      query: '',
    );

    _channel = connectRoomSocket(uri, headers: _apiClient.webSocketHeaders());

    _channel!.stream.listen(
      (raw) {
        try {
          final payload = jsonDecode(raw as String) as Map<String, dynamic>;
          _signalStream.add(payload);
        } catch (_) {}
      },
      onDone: () { _channel = null; },
      onError: (_) { _channel = null; },
      cancelOnError: false,
    );
  }

  /// Send a signaling payload to the peer via the server.
  /// [targetUserId] is the peer's user id.
  void send(int targetUserId, Map<String, dynamic> payload) {
    _channel?.sink.add(jsonEncode({
      ...payload,
      'targetUserId': targetUserId,
    }));
  }

  void disconnect() {
    _channel?.sink.close();
    _channel = null;
    _friendId = null;
  }

  void dispose() {
    disconnect();
    _signalStream.close();
  }
}
