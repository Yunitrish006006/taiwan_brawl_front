import 'package:flutter_test/flutter_test.dart';
import 'package:taiwan_brawl/services/push_provider.dart';
import 'package:taiwan_brawl_messaging/taiwan_brawl_messaging.dart';

void main() {
  const payload = <String, dynamic>{
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
  };

  test('Firebase adapter owns provider id and remote config parsing', () {
    final provider = FirebasePushProvider();
    final parsed = provider.parseConfiguration(payload);

    expect(provider.providerId, 'fcm');
    expect(parsed, isA<FirebasePushProviderOptions>());
    final config = parsed! as FirebasePushProviderOptions;
    expect(config.enabledPlatforms, {'android', 'ios', 'web'});
    expect(config.firebaseOptions.projectId, 'taiwan-brawl');
    expect(config.firebaseOptions.apiKey, 'api-key');
    expect(config.firebaseOptions.appId, '1:123:web:abc');
    expect(config.firebaseOptions.messagingSenderId, '123');
    expect(config.firebaseOptions.authDomain, 'taiwan-brawl.firebaseapp.com');
    expect(provider.canDeleteToken(config), isTrue);
  });

  test('Firebase adapter gates delivery by server flags and platform', () {
    final provider = FirebasePushProvider();
    final config = provider.parseConfiguration(payload)!;

    expect(provider.isEnabledForPlatform(config, 'android'), isTrue);
    expect(provider.isEnabledForPlatform(config, 'ios'), isTrue);
    expect(provider.isEnabledForPlatform(config, 'web'), isTrue);
    expect(provider.isEnabledForPlatform(config, 'macos'), isFalse);
    expect(provider.isEnabledForPlatform(config, null), isFalse);

    final noVapid = provider.parseConfiguration({
      ...payload,
      'fcm': {...payload['fcm'] as Map<String, dynamic>, 'webVapidKey': null},
    })!;
    expect(provider.isEnabledForPlatform(noVapid, 'android'), isTrue);
    expect(provider.isEnabledForPlatform(noVapid, 'web'), isFalse);

    final deliveryDisabled = provider.parseConfiguration({
      ...payload,
      'deliveryEnabled': false,
    })!;
    expect(provider.isEnabledForPlatform(deliveryDisabled, 'android'), isFalse);
    expect(provider.canDeleteToken(deliveryDisabled), isTrue);

    final providerDisabled = provider.parseConfiguration({
      ...payload,
      'fcm': {...payload['fcm'] as Map<String, dynamic>, 'enabled': false},
    })!;
    expect(provider.isEnabledForPlatform(providerDisabled, 'android'), isFalse);
  });

  test(
    'Firebase adapter returns no config when required Firebase fields are missing',
    () {
      final provider = FirebasePushProvider();

      expect(provider.parseConfiguration(null), isNull);
      expect(provider.parseConfiguration({'deliveryEnabled': true}), isNull);
      expect(
        provider.parseConfiguration({
          ...payload,
          'fcm': {...payload['fcm'] as Map<String, dynamic>, 'apiKey': '  '},
        }),
        isNull,
      );
    },
  );

  test(
    'adapter configuration stays opaque to the shared messaging contract',
    () {
      final configuration = FirebasePushProvider().parseConfiguration(payload);
      expect(configuration, isA<PushProviderConfiguration>());
    },
  );
}
