import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:cryptography/cryptography.dart' hide Hmac;
import 'package:taiwan_brawl_messaging/taiwan_brawl_messaging.dart';

/// Device identity backed by the secure credential boundary and independent
/// from an account id. New event signatures use Ed25519; legacy HMAC material
/// is retained only to verify existing peers during the migration window.
class SecureDeviceIdentity implements DeviceIdentity {
  SecureDeviceIdentity._({
    required this.deviceId,
    required Ed25519 algorithm,
    SimpleKeyPair? signingKeyPair,
    SimplePublicKey? publicKey,
    List<int>? legacySecret,
  }) : _algorithm = algorithm,
       _signingKeyPair = signingKeyPair,
       _publicKey = publicKey,
       _legacySecret = legacySecret;

  final Ed25519 _algorithm;
  final SimpleKeyPair? _signingKeyPair;
  final SimplePublicKey? _publicKey;
  final List<int>? _legacySecret;

  /// Public signing key for an explicit, fingerprint-confirmed trust flow.
  /// The private seed is never included in this material.
  String get publicKeyMaterial {
    final key = _publicKey;
    if (key == null) throw StateError('Device public key is unavailable');
    return base64UrlEncode(key.bytes);
  }

  @override
  final String deviceId;

  static Future<SecureDeviceIdentity> restore({
    required CredentialStore credentials,
    String keyPrefix = 'taiwan_brawl.device-identity.',
  }) async {
    final idKey = '${keyPrefix}id';
    final seedKey = '${keyPrefix}ed25519.seed';
    final legacySecretKey = '${keyPrefix}secret';
    final storedId = await credentials.read(idKey);
    final deviceId = storedId?.isNotEmpty == true
        ? storedId!
        : _randomToken(16);
    if (storedId == null || storedId.isEmpty) {
      await credentials.write(idKey, deviceId);
    }

    List<int>? legacySecret;
    final storedLegacySecret = await credentials.read(legacySecretKey);
    if (storedLegacySecret != null) {
      try {
        final decoded = base64Url.decode(storedLegacySecret);
        if (decoded.length == 32) {
          legacySecret = List<int>.unmodifiable(decoded);
        }
      } on FormatException {
        // Keep malformed legacy material out of the active identity.
      }
    }

    List<int> seed;
    final storedSeed = await credentials.read(seedKey);
    List<int>? decodedSeed;
    try {
      decodedSeed = storedSeed == null ? null : base64Url.decode(storedSeed);
    } on FormatException {
      decodedSeed = null;
    }
    if (decodedSeed != null && decodedSeed.length == 32) {
      seed = decodedSeed;
    } else {
      seed = List<int>.generate(32, (_) => Random.secure().nextInt(256));
    }
    final encodedSeed = base64UrlEncode(seed);
    if (storedSeed != encodedSeed) {
      await credentials.write(seedKey, encodedSeed);
    }

    final algorithm = Ed25519();
    final keyPair = await algorithm.newKeyPairFromSeed(seed);
    final publicKey = await keyPair.extractPublicKey();
    return SecureDeviceIdentity._(
      deviceId: deviceId,
      algorithm: algorithm,
      signingKeyPair: keyPair,
      publicKey: publicKey,
      legacySecret: legacySecret,
    );
  }

  /// Creates a verifier from explicit trust material. `ed25519:` material is
  /// public-only; unprefixed base64 is accepted solely for v1 HMAC migration.
  static Future<SecureDeviceIdentity> fromTrustedMaterial({
    required String deviceId,
    required String encodedMaterial,
  }) async {
    final normalizedId = deviceId.trim();
    if (normalizedId.isEmpty) {
      throw const FormatException('Trusted device id is required');
    }
    final material = encodedMaterial.trim();
    if (material.startsWith('ed25519:')) {
      final bytes = _decodeKey(material.substring('ed25519:'.length));
      if (bytes.length != 32) {
        throw const FormatException(
          'Trusted Ed25519 public key must be 32 bytes',
        );
      }
      return SecureDeviceIdentity._(
        deviceId: normalizedId,
        algorithm: Ed25519(),
        publicKey: SimplePublicKey(bytes, type: KeyPairType.ed25519),
      );
    }

    final legacySecret = _decodeKey(
      material.startsWith('hmac-sha256:')
          ? material.substring('hmac-sha256:'.length)
          : material,
    );
    if (legacySecret.length != 32) {
      throw const FormatException('Trusted legacy HMAC key must be 32 bytes');
    }
    return SecureDeviceIdentity._(
      deviceId: normalizedId,
      algorithm: Ed25519(),
      legacySecret: List<int>.unmodifiable(legacySecret),
    );
  }

  @override
  Future<String> sign(String payload) async {
    final keyPair = _signingKeyPair;
    if (keyPair == null) {
      throw StateError('A trusted peer public key cannot sign messages');
    }
    final signature = await _algorithm.sign(
      utf8.encode(payload),
      keyPair: keyPair,
    );
    return 'ed25519:${base64UrlEncode(signature.bytes)}';
  }

  @override
  Future<bool> verify(
    String payload,
    String signature,
    String candidateDeviceId,
  ) async {
    if (candidateDeviceId != deviceId) return false;
    if (signature.startsWith('ed25519:')) {
      final publicKey = _publicKey;
      if (publicKey == null) return false;
      try {
        final signatureBytes = _decodeKey(
          signature.substring('ed25519:'.length),
        );
        return await _algorithm.verify(
          utf8.encode(payload),
          signature: Signature(signatureBytes, publicKey: publicKey),
        );
      } on FormatException {
        return false;
      }
    }

    final legacySecret = _legacySecret;
    if (legacySecret == null) return false;
    final expected = base64UrlEncode(
      Hmac(sha256, legacySecret).convert(utf8.encode(payload)).bytes,
    );
    return _constantTimeEquals(expected, signature);
  }

  static List<int> _decodeKey(String encoded) {
    try {
      return base64Url.decode(base64Url.normalize(encoded));
    } on FormatException {
      throw const FormatException('Trusted signing key encoding is invalid');
    }
  }

  static bool _constantTimeEquals(String left, String right) {
    final leftBytes = utf8.encode(left);
    final rightBytes = utf8.encode(right);
    var difference = leftBytes.length ^ rightBytes.length;
    final length = min(leftBytes.length, rightBytes.length);
    for (var index = 0; index < length; index++) {
      difference |= leftBytes[index] ^ rightBytes[index];
    }
    return difference == 0;
  }

  static String _randomToken(int byteLength) {
    final bytes = List<int>.generate(
      byteLength,
      (_) => Random.secure().nextInt(256),
    );
    return base64UrlEncode(bytes);
  }
}
