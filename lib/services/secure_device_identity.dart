import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:taiwan_brawl_messaging/taiwan_brawl_messaging.dart';

/// Device identity backed by the same secure credential boundary as the local
/// message encryption key. It is intentionally independent from an account id.
///
/// HMAC is used here as a local signing adapter. The server must not treat this
/// as a replacement for account authentication or public-key identity until a
/// key distribution protocol is defined.
class SecureDeviceIdentity implements DeviceIdentity {
  SecureDeviceIdentity._({required this.deviceId, required List<int> secret})
    : _secret = List<int>.unmodifiable(secret);

  final List<int> _secret;

  /// Material for an explicit, user-approved out-of-band trust invitation.
  ///
  /// This is intentionally not part of [DeviceIdentity]. Callers should only
  /// expose it through a local QR/copy flow after the user chooses to pair a
  /// device; it must never be sent as a chat event or server message.
  String get trustedMaterial => base64UrlEncode(_secret);

  @override
  final String deviceId;

  static Future<SecureDeviceIdentity> restore({
    required CredentialStore credentials,
    String keyPrefix = 'taiwan_brawl.device-identity.',
  }) async {
    final idKey = '${keyPrefix}id';
    final secretKey = '${keyPrefix}secret';
    final storedId = await credentials.read(idKey);
    final deviceId = storedId?.isNotEmpty == true
        ? storedId!
        : _randomToken(16);
    if (storedId == null || storedId.isEmpty) {
      await credentials.write(idKey, deviceId);
    }

    final storedSecret = await credentials.read(secretKey);
    List<int>? secret;
    if (storedSecret != null) {
      try {
        final decoded = base64Url.decode(storedSecret);
        if (decoded.length == 32) secret = decoded;
      } on FormatException {
        // Replace malformed or truncated key material below.
      }
    }
    secret ??= List<int>.generate(32, (_) => Random.secure().nextInt(256));
    if (storedSecret == null ||
        secret.length == 32 && storedSecret != base64UrlEncode(secret)) {
      await credentials.write(secretKey, base64UrlEncode(secret));
    }

    return SecureDeviceIdentity._(deviceId: deviceId, secret: secret);
  }

  /// Rehydrates a peer identity from explicitly trusted out-of-band material.
  ///
  /// This is intentionally separate from [restore]. It must only be called
  /// after the user or another authenticated channel has approved the
  /// material; it is not an automatic key-exchange protocol.
  static Future<SecureDeviceIdentity> fromTrustedMaterial({
    required String deviceId,
    required String encodedSecret,
  }) async {
    final normalizedId = deviceId.trim();
    if (normalizedId.isEmpty) {
      throw const FormatException('Trusted device id is required');
    }
    final secret = base64Url.decode(encodedSecret.trim());
    if (secret.length != 32) {
      throw const FormatException('Trusted device secret must be 32 bytes');
    }
    return SecureDeviceIdentity._(deviceId: normalizedId, secret: secret);
  }

  @override
  Future<String> sign(String payload) async {
    final digest = Hmac(sha256, _secret).convert(utf8.encode(payload));
    return base64UrlEncode(digest.bytes);
  }

  @override
  Future<bool> verify(
    String payload,
    String signature,
    String candidateDeviceId,
  ) async {
    if (candidateDeviceId != deviceId) return false;
    final expected = await sign(payload);
    return _constantTimeEquals(expected, signature);
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
