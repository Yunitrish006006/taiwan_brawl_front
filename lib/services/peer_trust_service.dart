import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:taiwan_brawl_messaging/taiwan_brawl_messaging.dart';

import 'secure_device_identity.dart';

/// Versioned serverless trust invitation. v2 contains only an Ed25519 public
/// key; v1 HMAC invitations remain readable for migration compatibility.
class PeerTrustInvitation {
  const PeerTrustInvitation({
    required this.deviceId,
    required this.algorithm,
    required this.encodedMaterial,
    required this.fingerprint,
    required this.wireVersion,
  });

  static const int version = 2;
  static const int legacyVersion = 1;

  final String deviceId;
  final String algorithm;
  final String encodedMaterial;
  final String fingerprint;
  final int wireVersion;

  String encode() => jsonEncode({
    'version': wireVersion,
    'deviceId': deviceId,
    'algorithm': algorithm,
    'encodedMaterial': encodedMaterial,
    'fingerprint': fingerprint,
  });

  factory PeerTrustInvitation.decode(String encoded) {
    final raw = jsonDecode(encoded);
    if (raw is! Map) {
      throw const FormatException('Peer trust invitation must be an object');
    }
    final version = raw['version'];
    if (version != legacyVersion && version != PeerTrustInvitation.version) {
      throw const FormatException('Unsupported peer trust invitation version');
    }
    final deviceId = _requiredText(raw['deviceId'], 'deviceId');
    final material = _requiredText(raw['encodedMaterial'], 'encodedMaterial');
    final fingerprint = _requiredText(raw['fingerprint'], 'fingerprint');
    final algorithm = version == legacyVersion
        ? 'hmac-sha256'
        : _requiredText(raw['algorithm'], 'algorithm');
    if (algorithm != 'hmac-sha256' && algorithm != 'ed25519') {
      throw const FormatException('Unsupported peer trust key algorithm');
    }
    final expected = version == legacyVersion
        ? _legacyFingerprint(deviceId, material)
        : _fingerprint(algorithm, deviceId, material);
    if (fingerprint != expected) {
      throw const FormatException('Peer trust invitation fingerprint mismatch');
    }
    return PeerTrustInvitation(
      deviceId: deviceId,
      algorithm: algorithm,
      encodedMaterial: material,
      fingerprint: fingerprint,
      wireVersion: version as int,
    );
  }

  static PeerTrustInvitation fromDevice(SecureDeviceIdentity identity) {
    const algorithm = 'ed25519';
    final material = identity.publicKeyMaterial;
    return PeerTrustInvitation(
      deviceId: identity.deviceId,
      encodedMaterial: material,
      algorithm: algorithm,
      fingerprint: _fingerprint(algorithm, identity.deviceId, material),
      wireVersion: version,
    );
  }

  static String _fingerprint(
    String algorithm,
    String deviceId,
    String material,
  ) => sha256.convert(utf8.encode('$algorithm:$deviceId:$material')).toString();

  static String _legacyFingerprint(String deviceId, String material) =>
      sha256.convert(utf8.encode('$deviceId:$material')).toString();

  static String _requiredText(Object? value, String field) {
    final text = (value as String?)?.trim();
    if (text == null || text.isEmpty) {
      throw FormatException('$field is required');
    }
    return text;
  }
}

/// Application boundary for explicit, out-of-band peer trust.
///
/// Trust remains explicit and requires independent fingerprint confirmation.
/// The directory accepts v2 public keys and legacy v1 shared secrets.
class PeerTrustService {
  PeerTrustService({
    required CredentialStore credentials,
    String keyPrefix = 'taiwan_brawl.trusted-device.',
  }) : _directory = CredentialBackedDeviceIdentityDirectory(
         credentials: credentials,
         keyPrefix: keyPrefix,
         decoder: (deviceId, encodedMaterial) =>
             SecureDeviceIdentity.fromTrustedMaterial(
               deviceId: deviceId,
               encodedMaterial: encodedMaterial,
             ),
       );

  final CredentialBackedDeviceIdentityDirectory _directory;

  Future<void> trustPeer({
    required String deviceId,
    required String encodedMaterial,
  }) => _directory.trust(deviceId: deviceId, encodedMaterial: encodedMaterial);

  PeerTrustInvitation createInvitation(SecureDeviceIdentity identity) {
    return PeerTrustInvitation.fromDevice(identity);
  }

  /// Accepts an invitation only after the caller confirms its displayed
  /// fingerprint through an independent channel (for example voice or QR).
  Future<void> trustInvitation(
    String encoded, {
    required String confirmedFingerprint,
  }) async {
    final invitation = PeerTrustInvitation.decode(encoded);
    if (invitation.fingerprint != confirmedFingerprint.trim()) {
      throw const FormatException('Peer trust fingerprint was not confirmed');
    }
    await trustPeer(
      deviceId: invitation.deviceId,
      encodedMaterial: '${invitation.algorithm}:${invitation.encodedMaterial}',
    );
  }

  Future<void> revokePeer(String deviceId) => _directory.revoke(deviceId);

  EventAuthenticator remoteAuthenticator({required DeviceIdentity local}) {
    return DeviceEventAuthenticator(
      localIdentity: local,
      directory: _directory,
    );
  }
}
