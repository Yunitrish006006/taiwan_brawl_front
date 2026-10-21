import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:taiwan_brawl/models/app_user.dart';
import 'package:taiwan_brawl/services/api_client.dart';
import 'package:taiwan_brawl/config/app_configuration.dart';
import 'package:taiwan_brawl/services/llm_bot_service.dart';

void main() {
  test('direct provider checks stay inside the application service', () async {
    late http.BaseRequest request;
    final service = LlmBotService(
      ApiClient(),
      client: MockClient((incoming) async {
        request = incoming;
        return http.Response('{}', 200);
      }),
    );

    await service.testConnection(
      user: _user(hasApiKey: false),
      baseUrl: 'https://provider.test/v1/',
      model: 'test-model',
      apiKey: 'secret',
    );

    expect(request.url.toString(), 'https://provider.test/v1/chat/completions');
    expect(request.headers['authorization'], 'Bearer secret');
    final body = jsonDecode((request as http.Request).body) as Map;
    expect(body['model'], 'test-model');
  });

  test(
    'non-success provider responses expose a stable service error',
    () async {
      final service = LlmBotService(
        ApiClient(),
        client: MockClient(
          (_) async => http.Response(
            jsonEncode({
              'error': {'message': 'bad key'},
            }),
            401,
          ),
        ),
      );

      expect(
        () => service.testConnection(
          user: _user(hasApiKey: false),
          baseUrl: 'https://provider.test/v1',
          model: '',
          apiKey: 'secret',
        ),
        throwsA(
          isA<LlmConnectionException>()
              .having((error) => error.message, 'message', 'bad key')
              .having((error) => error.statusCode, 'statusCode', 401),
        ),
      );
    },
  );

  test('uses injected LLM defaults when fields are blank', () async {
    late http.BaseRequest request;
    final service = LlmBotService(
      ApiClient(),
      configuration: const AppConfiguration(
        apiBaseUrl: 'https://api.example.test',
        googleWebClientId: 'web',
        googleServerClientId: 'server',
        p2pChatEnabled: false,
        defaultLlmBaseUrl: 'https://llm.example.test/v1',
        defaultLlmModel: 'configured-model',
      ),
      client: MockClient((incoming) async {
        request = incoming;
        return http.Response('{}', 200);
      }),
    );

    await service.testConnection(
      user: _user(hasApiKey: false),
      baseUrl: '',
      model: '',
      apiKey: 'secret',
    );

    expect(
      request.url.toString(),
      'https://llm.example.test/v1/chat/completions',
    );
    final body = jsonDecode((request as http.Request).body) as Map;
    expect(body['model'], 'configured-model');
  });
}

AppUser _user({required bool hasApiKey}) {
  return AppUser(
    id: 1,
    name: 'Test',
    email: 'test@example.com',
    role: 'player',
    themeMode: 'system',
    fontSizeScale: 1,
    locale: 'en',
    llmBaseUrl: 'https://api.openai.com/v1',
    llmModel: 'gpt-4o-mini',
    hasLlmApiKey: hasApiKey,
  );
}
