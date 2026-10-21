import 'package:test/test.dart';
import 'package:taiwan_brawl_messaging/taiwan_brawl_messaging.dart';

void main() {
  test('persists explicit peer trust and supports revocation', () async {
    final credentials = _MemoryCredentials();
    final directory = CredentialBackedDeviceIdentityDirectory(
      credentials: credentials,
      decoder: (deviceId, material) async => _Identity('$deviceId:$material'),
    );

    await directory.trust(deviceId: 'peer/device', encodedMaterial: 'key-1');
    final resolved = await directory.resolve('peer/device');

    expect(resolved, isNotNull);
    expect((resolved as _Identity).label, 'peer/device:key-1');
    await directory.revoke('peer/device');
    expect(await directory.resolve('peer/device'), isNull);
  });

  test('does not resolve unknown or malformed trust material', () async {
    final directory = CredentialBackedDeviceIdentityDirectory(
      credentials: _MemoryCredentials({'trusted-device': 'bad'}),
      decoder: (_, material) async {
        throw const FormatException('bad material');
      },
    );

    expect(await directory.resolve('unknown'), isNull);
    await directory.trust(deviceId: 'trusted-device', encodedMaterial: 'bad');
    expect(await directory.resolve('trusted-device'), isNull);
  });
}

class _MemoryCredentials implements CredentialStore {
  _MemoryCredentials([Map<String, String>? initial]) : values = {...?initial};

  final Map<String, String> values;

  @override
  Future<String?> read(String key) async => values[key];

  @override
  Future<void> write(String key, String value) async => values[key] = value;

  @override
  Future<void> delete(String key) async => values.remove(key);
}

class _Identity implements DeviceIdentity {
  _Identity(this.label);

  final String label;

  @override
  String get deviceId => label.split(':').first;

  @override
  Future<String> sign(String payload) async => '$label:$payload';

  @override
  Future<bool> verify(
    String payload,
    String signature,
    String deviceId,
  ) async => signature == '$label:$payload' && deviceId == this.deviceId;
}
