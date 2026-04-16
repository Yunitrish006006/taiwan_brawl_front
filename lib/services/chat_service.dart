import 'dart:async';
import 'dart:convert';

import 'package:web_socket_channel/web_socket_channel.dart';

import '../constants/app_constants.dart';
import '../models/chat_models.dart';
import 'api_client.dart';
import 'room_socket_channel.dart';
import 'service_utils.dart';

class ChatService {
  ChatService(this._apiClient);

  final ApiClient _apiClient;

  WebSocketChannel? _channel;
  final StreamController<ChatMessage> _messageStream =
      StreamController.broadcast();

  Stream<ChatMessage> get messageStream => _messageStream.stream;

  // ── history ───────────────────────────────────────────────────────────────

  Future<List<ChatMessage>> fetchHistory(int friendId, {String? before}) async {
    final query = before != null ? '?before=${Uri.encodeQueryComponent(before)}' : '';
    final res = await _apiClient.getJson('/api/chat/dm/$friendId/history$query');
    return jsonModelList(res, 'messages', ChatMessage.fromJson);
  }

  // ── WebSocket ─────────────────────────────────────────────────────────────

  void connectToDm(int friendId) {
    disconnect();

    final baseUri = Uri.parse(AppConstants.apiBaseUrl);
    final scheme = baseUri.scheme == 'https' ? 'wss' : 'ws';
    final uri = baseUri.replace(
      scheme: scheme,
      path: '/api/chat/dm/$friendId/ws',
      query: '',
    );

    _channel = connectRoomSocket(uri, headers: _apiClient.webSocketHeaders());

    _channel!.stream.listen(
      (raw) {
        try {
          final payload = jsonDecode(raw as String) as Map<String, dynamic>;
          if (payload['type'] == 'new_message') {
            final msg = ChatMessage.fromJson(
              payload['message'] as Map<String, dynamic>,
            );
            _messageStream.add(msg);
          }
        } catch (_) {}
      },
      onDone: () {},
      onError: (_) {},
      cancelOnError: false,
    );
  }

  void sendMessage(int receiverId, String text) {
    _channel?.sink.add(jsonEncode({
      'type': 'send_message',
      'receiverId': receiverId,
      'text': text,
    }));
  }

  void disconnect() {
    _channel?.sink.close();
    _channel = null;
  }

  void dispose() {
    disconnect();
    _messageStream.close();
  }
}
