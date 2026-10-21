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
