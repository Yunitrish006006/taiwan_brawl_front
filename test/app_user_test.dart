import 'package:flutter_test/flutter_test.dart';
import 'package:taiwan_brawl/config/app_configuration.dart';
import 'package:taiwan_brawl/models/app_user.dart';

void main() {
  test('uses injected LLM defaults when profile fields are absent', () {
    const configuration = AppConfiguration(
      apiBaseUrl: 'https://api.example.test',
      googleWebClientId: 'web',
      googleServerClientId: 'server',
      p2pChatEnabled: false,
      defaultLlmBaseUrl: 'https://llm.example.test/v1',
      defaultLlmModel: 'configured-model',
    );
    final user = AppUser.fromJson({
      'id': 1,
      'name': 'Test',
      'email': 'test@example.com',
      'role': 'player',
      'avatar_url': '/user-avatars/1?v=1',
    }, configuration: configuration);

    expect(user.llmBaseUrl, 'https://llm.example.test/v1');
    expect(user.llmModel, 'configured-model');
    expect(user.avatarUrl, 'https://api.example.test/user-avatars/1?v=1');
  });
}
