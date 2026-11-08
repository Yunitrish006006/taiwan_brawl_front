import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taiwan_brawl/services/secure_device_identity.dart';
import 'package:taiwan_brawl_messaging/taiwan_brawl_messaging.dart';

void main() {
  test('restores the same device identity and verifies signatures', () async {
    final credentials = _MemoryCredentials();
    final first = await SecureDeviceIdentity.restore(credentials: credentials);
    final signature = await first.sign('canonical payload');
    final restored = await SecureDeviceIdentity.restore(
      credentials: credentials,
    );

    expect(restored.deviceId, first.deviceId);
    expect(signature, startsWith('ed25519:'));
    expect(
      credentials.values['taiwan_brawl.device-identity.ed25519.seed'],
      isNotNull,
    );
    expect(
      await restored.verify('canonical payload', signature, first.deviceId),
      isTrue,
    );
    expect(
      await restored.verify('tampered', signature, first.deviceId),
      isFalse,
    );
  });

  test('different credential stores cannot impersonate one another', () async {
    final first = await SecureDeviceIdentity.restore(
      credentials: _MemoryCredentials(),
    );
    final second = await SecureDeviceIdentity.restore(
      credentials: _MemoryCredentials(),
    );
    final signature = await first.sign('payload');

    expect(await second.verify('payload', signature, first.deviceId), isFalse);
  });

  test(
    'verifies legacy HMAC signatures while signing new events with Ed25519',
    () async {
      final credentials = _MemoryCredentials()
        ..values['taiwan_brawl.device-identity.id'] = 'legacy-device'
        ..values['taiwan_brawl.device-identity.secret'] = base64UrlEncode(
          List<int>.generate(32, (index) => index),
        );
      final identity = await SecureDeviceIdentity.restore(
        credentials: credentials,
      );
      const payload = 'legacy canonical payload';
      final secret = base64Url.decode(
        credentials.values['taiwan_brawl.device-identity.secret']!,
      );
      final oldSignature = base64UrlEncode(
        Hmac(sha256, secret).convert(utf8.encode(payload)).bytes,
      );

      expect(
        await identity.verify(payload, oldSignature, 'legacy-device'),
        isTrue,
      );
      expect(
        await identity.verify(
          '$payload changed',
          oldSignature,
          'legacy-device',
        ),
        isFalse,
      );
      expect(await identity.sign(payload), startsWith('ed25519:'));
    },
  );
}

class _MemoryCredentials implements CredentialStore {
  final values = <String, String>{};

  @override
  Future<String?> read(String key) async => values[key];

  @override
  Future<void> write(String key, String value) async => values[key] = value;

  @override
  Future<void> delete(String key) async => values.remove(key);
}
