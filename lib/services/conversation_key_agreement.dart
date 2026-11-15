import 'dart:convert';

import 'package:cryptography/cryptography.dart';

/// The public half of one ephemeral X25519 conversation-key exchange.
class ConversationKeyOffer {
  const ConversationKeyOffer({
    required this.version,
    required this.conversationId,
    required this.deviceId,
    required this.publicKey,
    this.signature,
  });

  final int version;
  final String conversationId;
  final String deviceId;
  final String publicKey;
  final String? signature;

  String get canonicalPayload => jsonEncode({
    'version': version,
    'conversationId': conversationId,
    'deviceId': deviceId,
    'publicKey': publicKey,
  });

  Map<String, Object?> toJson() => {
    'version': version,
    'conversationId': conversationId,
    'deviceId': deviceId,
    'publicKey': publicKey,
    if (signature != null) 'signature': signature,
  };

  factory ConversationKeyOffer.fromJson(Map<String, Object?> json) {
    final version = json['version'];
    if (version != 1) {
      throw const FormatException('Unsupported conversation key version');
    }
    return ConversationKeyOffer(
      version: 1,
      conversationId: _required(json, 'conversationId'),
      deviceId: _required(json, 'deviceId'),
      publicKey: _required(json, 'publicKey'),
      signature: json['signature'] as String?,
    );
  }

  ConversationKeyOffer withSignature(String value) => ConversationKeyOffer(
    version: version,
    conversationId: conversationId,
    deviceId: deviceId,
    publicKey: publicKey,
    signature: value,
  );

  static String _required(Map<String, Object?> json, String key) {
    final value = json[key];
    if (value is! String || value.isEmpty) {
      throw FormatException('Conversation key $key is required');
    }
    return value;
  }
}

/// Creates a conversation key after the P2P channel has authenticated the
/// peer's device identity.
///
/// Authentication of the offer's device id/public key association remains the
/// caller's responsibility and must use the existing trusted-device flow.
class ConversationKeyAgreement {
  ConversationKeyAgreement._({
    required this.conversationId,
    required this.localDeviceId,
    required X25519 algorithm,
    required KeyExchangeWand wand,
    required String publicKey,
  }) : _algorithm = algorithm,
       _wand = wand,
       offer = ConversationKeyOffer(
         version: 1,
         conversationId: conversationId,
         deviceId: localDeviceId,
         publicKey: publicKey,
       );

  static const _outputLength = 32;

  final String conversationId;
  final String localDeviceId;
  final X25519 _algorithm;
  final KeyExchangeWand _wand;
  final ConversationKeyOffer offer;

  static Future<ConversationKeyAgreement> create({
    required String conversationId,
    required String localDeviceId,
    X25519? algorithm,
  }) async {
    final selected = algorithm ?? X25519();
    final wand = await selected.newKeyExchangeWand();
    final publicKey = await wand.extractPublicKey();
    return ConversationKeyAgreement._(
      conversationId: conversationId,
      localDeviceId: localDeviceId,
      algorithm: selected,
      wand: wand,
      publicKey: base64UrlEncode((publicKey as SimplePublicKey).bytes),
    );
  }

  Future<List<int>> deriveKey(ConversationKeyOffer remote) async {
    if (remote.version != offer.version ||
        remote.conversationId != conversationId ||
        remote.deviceId == localDeviceId) {
      throw const FormatException('Conversation key offer does not match');
    }
    final remoteBytes = _decodePublicKey(remote.publicKey);
    final remoteKey = SimplePublicKey(remoteBytes, type: KeyPairType.x25519);
    final shared = await _wand.sharedSecretKey(remotePublicKey: remoteKey);
    final lowDevice = localDeviceId.compareTo(remote.deviceId) < 0
        ? localDeviceId
        : remote.deviceId;
    final highDevice = localDeviceId.compareTo(remote.deviceId) < 0
        ? remote.deviceId
        : localDeviceId;
    final info = utf8.encode(
      'taiwan-brawl/conversation-key/v1/$conversationId/$lowDevice/$highDevice',
    );
    final derived = await Hkdf(
      hmac: Hmac.sha256(),
      outputLength: _outputLength,
    ).deriveKey(secretKey: shared, info: info);
    return derived.extractBytes();
  }

  static List<int> _decodePublicKey(String value) {
    try {
      final bytes = base64Url.decode(base64Url.normalize(value));
      if (bytes.length != 32) throw const FormatException();
      return bytes;
    } on FormatException {
      throw const FormatException('Conversation public key is invalid');
    }
  }
}
