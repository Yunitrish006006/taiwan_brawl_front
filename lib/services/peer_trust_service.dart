import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:taiwan_brawl_messaging/taiwan_brawl_messaging.dart';

import 'secure_device_identity.dart';

/// Versioned, serverless trust invitation for the current HMAC identity
/// adapter. The material is still a shared secret; the fingerprint exists so
/// two users can compare the invitation through an independent channel before
/// accepting it.
class PeerTrustInvitation {
  const PeerTrustInvitation({
    required this.deviceId,
    required this.encodedMaterial,
    required this.fingerprint,
  });

  static const int version = 1;

  final String deviceId;
  final String encodedMaterial;
  final String fingerprint;

  String encode() => jsonEncode({
    'version': version,
    'deviceId': deviceId,
    'encodedMaterial': encodedMaterial,
    'fingerprint': fingerprint,
  });

  factory PeerTrustInvitation.decode(String encoded) {
    final raw = jsonDecode(encoded);
    if (raw is! Map) {
      throw const FormatException('Peer trust invitation must be an object');
    }
    if (raw['version'] != version) {
      throw const FormatException('Unsupported peer trust invitation version');
    }
    final deviceId = _requiredText(raw['deviceId'], 'deviceId');
    final material = _requiredText(raw['encodedMaterial'], 'encodedMaterial');
    final fingerprint = _requiredText(raw['fingerprint'], 'fingerprint');
    final expected = _fingerprint(deviceId, material);
    if (fingerprint != expected) {
      throw const FormatException('Peer trust invitation fingerprint mismatch');
    }
    return PeerTrustInvitation(
      deviceId: deviceId,
      encodedMaterial: material,
      fingerprint: fingerprint,
    );
  }

  static PeerTrustInvitation fromDevice(SecureDeviceIdentity identity) {
    final material = identity.trustedMaterial;
    return PeerTrustInvitation(
      deviceId: identity.deviceId,
      encodedMaterial: material,
      fingerprint: _fingerprint(identity.deviceId, material),
    );
  }

  static String _fingerprint(String deviceId, String material) =>
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
/// The shared-secret decoder is a migration bridge for the current local HMAC
/// identity. It does not provide automatic key exchange: callers must obtain
/// the material through a separately authenticated user flow before calling
/// [trust].
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
               encodedSecret: encodedMaterial,
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
      encodedMaterial: invitation.encodedMaterial,
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
