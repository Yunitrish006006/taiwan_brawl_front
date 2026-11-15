import 'package:flutter_test/flutter_test.dart';
import 'package:taiwan_brawl_messaging/taiwan_brawl_messaging.dart';
import 'package:taiwan_brawl/services/secure_conversation_key_store.dart';

void main() {
  test('stores and resolves a 256-bit conversation key', () async {
    final credentials = _MemoryCredentials();
    final store = SecureConversationKeyStore(credentials: credentials);
    final key = List<int>.generate(32, (index) => index);

    await store.save(conversationId: '1:2', keyId: 'key-1', key: key);

    expect(await store.resolve('1:2', 'key-1'), key);
    expect(await store.resolve('1:2', 'other'), isNull);
  });

  test('rejects keys that are not 256 bits', () async {
    final store = SecureConversationKeyStore(credentials: _MemoryCredentials());

    expect(
      () => store.save(
        conversationId: '1:2',
        keyId: 'key-1',
        key: List<int>.filled(16, 1),
      ),
      throwsFormatException,
    );
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
