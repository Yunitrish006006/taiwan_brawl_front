import 'dart:convert';

import 'package:cryptography/cryptography.dart';
import 'package:taiwan_brawl_messaging/taiwan_brawl_messaging.dart';

/// AES-GCM adapter for relay message bodies.
///
/// Conversation keys are resolved by the injected resolver. This class does
/// not persist keys; the resolver reads keys created by authenticated P2P
/// pairing for encrypted relay fallback.
class AesGcmConversationEncryptor implements ConversationEncryptor {
  AesGcmConversationEncryptor({
    required ConversationKeyResolver keyResolver,
    AesGcm? algorithm,
  }) : _keyResolver = keyResolver,
       _algorithm = algorithm ?? AesGcm.with256bits();

  static const algorithmName = 'aes-256-gcm';
  static const version = 1;
  static const _macLength = 16;

  final ConversationKeyResolver _keyResolver;
  final AesGcm _algorithm;

  @override
  Future<EncryptedMessageBody> encrypt({
    required String conversationId,
    required String keyId,
    required String plaintext,
  }) async {
    final key = await _resolveKey(conversationId, keyId);
    final box = await _algorithm.encrypt(
      utf8.encode(plaintext),
      secretKey: key,
      nonce: _algorithm.newNonce(),
    );
    final authenticatedCiphertext = <int>[...box.cipherText, ...box.mac.bytes];
    return EncryptedMessageBody(
      version: version,
      algorithm: algorithmName,
      keyId: keyId,
      nonce: base64UrlEncode(box.nonce),
      ciphertext: base64UrlEncode(authenticatedCiphertext),
    );
  }

  @override
  Future<String> decrypt({
    required String conversationId,
    required EncryptedMessageBody body,
  }) async {
    if (body.version != version || body.algorithm != algorithmName) {
      throw const FormatException('Unsupported conversation encryption');
    }
    final key = await _resolveKey(conversationId, body.keyId);
    final nonceBytes = _decode(body.nonce, 'nonce');
    final combined = _decode(body.ciphertext, 'ciphertext');
    if (nonceBytes.length != 12 || combined.length < _macLength) {
      throw const FormatException('Invalid AES-GCM payload lengths');
    }
    final split = combined.length - _macLength;
    final box = SecretBox(
      combined.sublist(0, split),
      nonce: nonceBytes,
      mac: Mac(combined.sublist(split)),
    );
    final cleartext = await _algorithm.decrypt(box, secretKey: key);
    return utf8.decode(cleartext);
  }

  Future<SecretKey> _resolveKey(String conversationId, String keyId) async {
    final bytes = await _keyResolver.resolve(conversationId, keyId);
    if (bytes == null || bytes.length != 32) {
      throw StateError('A 256-bit conversation key is required');
    }
    return SecretKey(bytes);
  }

  static List<int> _decode(String value, String field) {
    try {
      return base64Url.decode(base64Url.normalize(value));
    } on FormatException {
      throw FormatException('Encrypted body $field is not valid base64url');
    }
  }
}

/// Small in-memory resolver useful for unit tests and local pairing spikes.
class InMemoryConversationKeyResolver implements ConversationKeyResolver {
  InMemoryConversationKeyResolver(Map<String, List<int>> keys)
    : _keys = {
        for (final entry in keys.entries)
          entry.key: List<int>.unmodifiable(entry.value),
      };

  final Map<String, List<int>> _keys;

  @override
  Future<List<int>?> resolve(String conversationId, String keyId) async {
    final key = _keys['$conversationId:$keyId'];
    return key == null ? null : List<int>.unmodifiable(key);
  }

  static List<int> deterministicKey(int seed) =>
      List<int>.generate(32, (index) => (seed + index * 17) % 256);
}
