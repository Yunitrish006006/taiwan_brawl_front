import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/app_user.dart';
import '../config/app_configuration.dart';

import 'api_client.dart';
import 'llm_bot_remote_source.dart';

/// Application service for testing the configured LLM connection.
///
/// The settings widget owns form state only; HTTP provider details and the
/// backend-proxy/direct-provider split stay behind this service boundary.
class LlmBotService {
  LlmBotService(
    ApiClient apiClient, {
    LlmBotRemoteSource? remoteSource,
    http.Client? client,
    AppConfiguration? configuration,
  }) : _remoteSource =
           remoteSource ?? ServerLlmBotRemoteSource(apiClient, client: client),
       _configuration = configuration ?? AppConfiguration.environment;

  final LlmBotRemoteSource _remoteSource;
  final AppConfiguration _configuration;

  Future<void> testConnection({
    required AppUser user,
    required String baseUrl,
    required String model,
    String? apiKey,
  }) async {
    final key = apiKey?.trim() ?? '';
    if (key.isEmpty && user.hasLlmApiKey) {
      await _remoteSource.requestBackendDecision(_testState);
      return;
    }
    if (key.isEmpty) {
      throw LlmConnectionException('An API key is required');
    }

    final normalizedBaseUrl = baseUrl.trim().isEmpty
        ? _configuration.defaultLlmBaseUrl
        : baseUrl.trim().replaceAll(RegExp(r'/+$'), '');
    final url = normalizedBaseUrl.endsWith('/chat/completions')
        ? normalizedBaseUrl
        : '$normalizedBaseUrl/chat/completions';
    final effectiveModel = model.trim().isEmpty
        ? _configuration.defaultLlmModel
        : model.trim();

    final requestHeaders = {
      'Authorization': 'Bearer $key',
      'Content-Type': 'application/json',
    };
    final requestBody = {
      'model': effectiveModel,
      'messages': [
        {'role': 'user', 'content': 'reply with ok'},
      ],
      'max_tokens': 8,
    };
    final response = await _remoteSource.requestProvider(
      uri: Uri.parse(url),
      headers: requestHeaders,
      body: requestBody,
    );
    if (response.statusCode >= 200 && response.statusCode < 300) return;

    var message = '';
    try {
      final body = jsonDecode(response.body);
      message = body is Map
          ? (body['error'] is Map
                ? body['error']['message']?.toString() ?? ''
                : body['error']?.toString() ?? '')
          : '';
    } catch (_) {
      // Keep the status code when a provider does not return JSON.
    }
    throw LlmConnectionException(
      message.isEmpty
          ? 'Provider returned HTTP ${response.statusCode}'
          : message,
      statusCode: response.statusCode,
    );
  }

  static const Map<String, dynamic> _testState = {
    'roomCode': 'TEST',
    'playerSide': 'left',
    'timeRemainingMs': 60000,
    'players': {
      'left': {
        'userId': 0,
        'deckCards': [
          {'id': 'test_card', 'name': 'Test Card', 'energyCost': 1},
        ],
        'handCardIds': [],
        'queueCardIds': [],
        'towerHp': 1000,
        'maxTowerHp': 1000,
      },
      'right': {
        'userId': 1,
        'deckCards': [
          {'id': 'test_card', 'name': 'Test Card', 'energyCost': 1},
        ],
        'handCardIds': [],
        'queueCardIds': [],
        'towerHp': 1000,
        'maxTowerHp': 1000,
      },
    },
    'units': [],
    'events': [],
  };
}

class LlmConnectionException implements Exception {
  const LlmConnectionException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}
