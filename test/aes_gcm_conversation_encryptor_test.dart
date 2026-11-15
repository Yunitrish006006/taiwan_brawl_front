import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:taiwan_brawl_messaging/taiwan_brawl_messaging.dart';

import 'package:taiwan_brawl/services/aes_gcm_conversation_encryptor.dart';

void main() {
  const conversationId = '1:2';
  const keyId = 'conversation-key-1';

  AesGcmConversationEncryptor createEncryptor({int seed = 7}) {
    return AesGcmConversationEncryptor(
      keyResolver: InMemoryConversationKeyResolver({
        '$conversationId:$keyId':
            InMemoryConversationKeyResolver.deterministicKey(seed),
      }),
    );
  }

  test('encrypts and decrypts a message body', () async {
    final encryptor = createEncryptor();
    final encrypted = await encryptor.encrypt(
      conversationId: conversationId,
      keyId: keyId,
      plaintext: '你好，P2P',
    );

    expect(encrypted.algorithm, AesGcmConversationEncryptor.algorithmName);
    expect(encrypted.ciphertext, isNot(contains('你好')));
    expect(
      await encryptor.decrypt(conversationId: conversationId, body: encrypted),
      '你好，P2P',
    );
  });

  test('uses a different nonce for repeated encryption', () async {
    final encryptor = createEncryptor();
    final first = await encryptor.encrypt(
      conversationId: conversationId,
      keyId: keyId,
      plaintext: 'same',
    );
    final second = await encryptor.encrypt(
      conversationId: conversationId,
      keyId: keyId,
      plaintext: 'same',
    );

    expect(first.nonce, isNot(second.nonce));
  });

  test('rejects a wrong key and modified ciphertext', () async {
    final encrypted = await createEncryptor().encrypt(
      conversationId: conversationId,
      keyId: keyId,
      plaintext: 'protected',
    );

    expect(
      () => createEncryptor(
        seed: 8,
      ).decrypt(conversationId: conversationId, body: encrypted),
      throwsA(anything),
    );

    final bytes = base64Url.decode(base64Url.normalize(encrypted.ciphertext));
    bytes[0] ^= 1;
    final modified = EncryptedMessageBody(
      version: encrypted.version,
      algorithm: encrypted.algorithm,
      keyId: encrypted.keyId,
      nonce: encrypted.nonce,
      ciphertext: base64UrlEncode(bytes),
    );
    expect(
      () => createEncryptor().decrypt(
        conversationId: conversationId,
        body: modified,
      ),
      throwsA(anything),
    );
  });
}
