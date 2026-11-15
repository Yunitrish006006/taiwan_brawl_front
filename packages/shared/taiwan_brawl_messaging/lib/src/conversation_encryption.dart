/// A transport-neutral encrypted body carried by a chat event.
///
/// This is deliberately only a wire contract. The shared package does not
/// choose a cryptographic implementation or store conversation keys.
class EncryptedMessageBody {
  const EncryptedMessageBody({
    required this.version,
    required this.algorithm,
    required this.keyId,
    required this.nonce,
    required this.ciphertext,
  });

  final int version;
  final String algorithm;
  final String keyId;
  final String nonce;
  final String ciphertext;

  Map<String, Object?> toJson() => {
    'version': version,
    'algorithm': algorithm,
    'keyId': keyId,
    'nonce': nonce,
    'ciphertext': ciphertext,
  };

  factory EncryptedMessageBody.fromJson(Map<String, Object?> json) {
    final version = json['version'];
    if (version is! int || version <= 0) {
      throw const FormatException('Encrypted body version is invalid');
    }
    return EncryptedMessageBody(
      version: version,
      algorithm: _required(json, 'algorithm'),
      keyId: _required(json, 'keyId'),
      nonce: _required(json, 'nonce'),
      ciphertext: _required(json, 'ciphertext'),
    );
  }

  static String _required(Map<String, Object?> json, String key) {
    final value = json[key];
    if (value is! String || value.isEmpty) {
      throw FormatException('Encrypted body $key is required');
    }
    return value;
  }
}

abstract interface class ConversationKeyResolver {
  Future<List<int>?> resolve(String conversationId, String keyId);
}

/// Encryption boundary; implementations must provide authenticated encryption.
abstract interface class ConversationEncryptor {
  Future<EncryptedMessageBody> encrypt({
    required String conversationId,
    required String keyId,
    required String plaintext,
  });

  Future<String> decrypt({
    required String conversationId,
    required EncryptedMessageBody body,
  });
}
