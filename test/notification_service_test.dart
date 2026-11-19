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
    expect(config.isEnabledForPlatform('ios'), isFalse);
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

  test(
    'Apple uses its own Firebase App ID and rejects Android configuration',
    () {
      final fixture = {
        'enabled': true,
        'projectId': 'taiwan-brawl',
        'apiKey': 'api-key',
        'appId': '1:123:android:abc',
        'messagingSenderId': '123',
      };
      PushConfiguration parse(Map<String, Object?> fcm) =>
          PushConfiguration.fromJson({
            'deliveryEnabled': true,
            'enabledPlatforms': ['android', 'ios'],
            'fcm': fcm,
          })!;

      final androidOnly = parse(fixture);
      expect(androidOnly.isEnabledForPlatform('android'), isTrue);
      expect(androidOnly.isEnabledForPlatform('ios'), isFalse);
      expect(
        () => androidOnly.toFirebaseOptions(platform: 'ios'),
        throwsStateError,
      );
      final both = parse({...fixture, 'iosAppId': '1:123:ios:abc123'});
      expect(both.isEnabledForPlatform('ios'), isTrue);
      expect(both.toFirebaseOptions(platform: 'ios').appId, '1:123:ios:abc123');
      expect(
        both.toFirebaseOptions(platform: 'android').appId,
        '1:123:android:abc',
      );
      final legacy = parse({...fixture, 'appId': '1:123:ios:abc123'});
      expect(legacy.isEnabledForPlatform('ios'), isTrue);
    },
  );

  test('PushConfiguration returns null for missing config', () {
    expect(PushConfiguration.fromJson(null), isNull);
  });
}
