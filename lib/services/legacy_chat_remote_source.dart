import 'dart:convert';

import '../models/chat_models.dart';
import 'api_client.dart';
import 'service_utils.dart';

/// Replaceable remote compatibility boundary for the legacy DM API.
abstract interface class LegacyChatRemoteSource {
  Future<List<ChatMessage>> fetchHistory(int friendId, {String? before});

  Future<void> uploadSyncData(int friendId, Map<String, dynamic> data);

  Future<Map<String, dynamic>> downloadSyncData(int friendId);

  Future<Map<String, dynamic>> sendMessage(int friendId, String text);

  Future<void> recallMessage(int friendId, String messageKey);
}

/// HTTP adapter for the existing Cloudflare chat compatibility endpoints.
class ServerLegacyChatRemoteSource implements LegacyChatRemoteSource {
  ServerLegacyChatRemoteSource(this._apiClient);

  final ApiClient _apiClient;

  @override
  Future<List<ChatMessage>> fetchHistory(int friendId, {String? before}) async {
    final query = before == null
        ? ''
        : '?before=${Uri.encodeQueryComponent(before)}';
    final response = await _apiClient.getJson(
      '/api/chat/dm/$friendId/history$query',
    );
    return jsonModelList(response, 'messages', ChatMessage.fromJson);
  }

  @override
  Future<void> uploadSyncData(int friendId, Map<String, dynamic> data) async {
    await _apiClient.postRaw(
      '/api/chat/dm/$friendId/sync-upload',
      jsonEncode(data),
    );
  }

  @override
  Future<Map<String, dynamic>> downloadSyncData(int friendId) async {
    final raw = await _apiClient.getRaw('/api/chat/dm/$friendId/sync-download');
    return Map<String, dynamic>.from(jsonDecode(raw) as Map);
  }

  @override
  Future<Map<String, dynamic>> sendMessage(int friendId, String text) {
    return _apiClient.postJson('/api/chat/dm/$friendId/send', {'text': text});
  }

  @override
  Future<void> recallMessage(int friendId, String messageKey) async {
    await _apiClient.postJson('/api/chat/dm/$friendId/recall', {
      'messageKey': messageKey,
    });
  }
}
