import 'package:flutter_test/flutter_test.dart';
import 'package:taiwan_brawl/services/secure_messaging_key_provider.dart';
import 'package:taiwan_brawl_messaging/taiwan_brawl_messaging.dart';

void main() {
  test('secure messaging key provider persists and reuses a 256-bit key', () async {
    final credentials = _MemoryCredentials();
    final provider = SecureMessagingKeyProvider(credentials: credentials);

    final first = await provider.loadOrCreate('messages');
    final second = await provider.loadOrCreate('messages');

    expect(first, hasLength(32));
    expect(second, first);
    expect(credentials.values, hasLength(1));
  });

  test('invalid stored key is replaced', () async {
    final credentials = _MemoryCredentials()
      ..values['taiwan_brawl.messaging.key.messages'] = 'invalid';
    final provider = SecureMessagingKeyProvider(credentials: credentials);

    final key = await provider.loadOrCreate('messages');

    expect(key, hasLength(32));
  });
}

class _MemoryCredentials implements CredentialStore {
  final values = <String, String>{};

  @override
  Future<void> delete(String key) async => values.remove(key);

  @override
  Future<String?> read(String key) async => values[key];

  @override
  Future<void> write(String key, String value) async => values[key] = value;
}
