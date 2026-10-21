import 'dart:convert';

import 'package:http/http.dart' as http;

import 'api_client.dart';

class LlmProviderResponse {
  const LlmProviderResponse({required this.statusCode, required this.body});

  final int statusCode;
  final String body;
}

abstract interface class LlmBotRemoteSource {
  Future<void> requestBackendDecision(Map<String, dynamic> state);

  Future<LlmProviderResponse> requestProvider({
    required Uri uri,
    required Map<String, String> headers,
    required Map<String, dynamic> body,
  });
}

class ServerLlmBotRemoteSource implements LlmBotRemoteSource {
  ServerLlmBotRemoteSource(this._apiClient, {http.Client? client})
    : _client = client ?? http.Client();

  final ApiClient _apiClient;
  final http.Client _client;

  @override
  Future<void> requestBackendDecision(Map<String, dynamic> state) async {
    await _apiClient.postJson('/api/llm-bot/decide', {'state': state});
  }

  @override
  Future<LlmProviderResponse> requestProvider({
    required Uri uri,
    required Map<String, String> headers,
    required Map<String, dynamic> body,
  }) async {
    final response = await _client.post(
      uri,
      headers: headers,
      body: jsonEncode(body),
    );
    return LlmProviderResponse(
      statusCode: response.statusCode,
      body: response.body,
    );
  }
}
