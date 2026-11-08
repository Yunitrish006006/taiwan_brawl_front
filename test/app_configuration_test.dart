import 'package:flutter_test/flutter_test.dart';
import 'package:taiwan_brawl/config/app_configuration.dart';

void main() {
  test('production environment defaults direct messages to P2P', () {
    expect(AppConfiguration.environment.p2pChatEnabled, isTrue);
  });

  test('P2P transport follows an explicit compile-time deployment override', () {
    const expected = bool.fromEnvironment(
      'P2P_CHAT_ENABLED',
      defaultValue: true,
    );
    expect(AppConfiguration.environment.p2pChatEnabled, expected);
  });

  test('shared configuration is injectable by the composition root', () {
    const configuration = AppConfiguration(
      apiBaseUrl: 'https://local.example.test',
      googleWebClientId: 'web-client',
      googleServerClientId: 'server-client',
      p2pChatEnabled: true,
      peerVerificationEnabled: true,
      previewMode: true,
    );

    expect(configuration.apiBaseUrl, 'https://local.example.test');
    expect(configuration.googleWebClientId, 'web-client');
    expect(configuration.googleServerClientId, 'server-client');
    expect(configuration.p2pChatEnabled, isTrue);
    expect(configuration.peerVerificationEnabled, isTrue);
    expect(configuration.previewMode, isTrue);
  });
}
