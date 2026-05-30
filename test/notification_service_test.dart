import 'package:flutter_test/flutter_test.dart';
import 'package:taiwan_brawl/services/notification_service.dart';

void main() {
  test('PushConfiguration parses FCM config and Firebase options', () {
    final config = PushConfiguration.fromJson({
      'deliveryEnabled': true,
      'enabledPlatforms': ['android', 'ios', 'web', 'web'],
      'fcm': {
        'enabled': true,
        'projectId': ' taiwan-brawl ',
        'apiKey': ' api-key ',
        'appId': ' 1:123:web:abc ',
        'messagingSenderId': ' 123 ',
        'webVapidKey': ' vapid-key ',
        'authDomain': 'taiwan-brawl.firebaseapp.com',
      },
    });

    expect(config, isNotNull);
    expect(config!.hasFirebaseOptions, isTrue);
    expect(config.enabledPlatforms, ['android', 'ios', 'web']);
    expect(config.isEnabledForPlatform('android'), isTrue);
    expect(config.isEnabledForPlatform('ios'), isTrue);
    expect(config.isEnabledForPlatform('web'), isTrue);
    expect(config.isEnabledForPlatform('macos'), isFalse);

    final options = config.toFirebaseOptions();
    expect(options.projectId, 'taiwan-brawl');
    expect(options.apiKey, 'api-key');
    expect(options.appId, '1:123:web:abc');
    expect(options.messagingSenderId, '123');
    expect(options.authDomain, 'taiwan-brawl.firebaseapp.com');
  });

  test('PushConfiguration requires delivery config and web VAPID key', () {
    final config = PushConfiguration.fromJson({
      'deliveryEnabled': false,
      'enabledPlatforms': ['android', 'web'],
      'fcm': {
        'enabled': true,
        'projectId': 'taiwan-brawl',
        'apiKey': 'api-key',
        'appId': '1:123:web:abc',
        'messagingSenderId': '123',
      },
    });

    expect(config, isNotNull);
    expect(config!.isEnabledForPlatform('android'), isFalse);
    expect(config.isEnabledForPlatform('web'), isFalse);

    final deliveryOnlyConfig = PushConfiguration.fromJson({
      'deliveryEnabled': true,
      'enabledPlatforms': ['android', 'web'],
      'fcm': {
        'enabled': true,
        'projectId': 'taiwan-brawl',
        'apiKey': 'api-key',
        'appId': '1:123:web:abc',
        'messagingSenderId': '123',
      },
    });

    expect(deliveryOnlyConfig!.isEnabledForPlatform('android'), isTrue);
    expect(deliveryOnlyConfig.isEnabledForPlatform('web'), isFalse);
  });

  test('PushConfiguration returns null for missing config', () {
    expect(PushConfiguration.fromJson(null), isNull);
  });
}
