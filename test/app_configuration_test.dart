import 'package:flutter_test/flutter_test.dart';
import 'package:taiwan_brawl/config/app_configuration.dart';

void main() {
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
