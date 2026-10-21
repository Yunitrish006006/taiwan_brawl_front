import 'dart:convert';

import 'platform_ports.dart';

/// Decodes opaque, application-owned trust material into a device identity.
///
/// The shared package does not prescribe a key format. A frontend may decode a
/// public key, a platform key reference, or another authenticated record while
/// keeping the material out of the event and transport layers.
typedef DeviceIdentityDecoder =
    Future<DeviceIdentity> Function(String deviceId, String encodedMaterial);

/// Persistent opt-in directory for trusted peer devices.
///
/// Trust is explicit: an unknown device is unresolved, and revocation removes
/// its material from the injected [CredentialStore]. The default application
/// composition does not create this directory, so remote verification remains
/// disabled until a product supplies a trust workflow and decoder.
class CredentialBackedDeviceIdentityDirectory
    implements DeviceIdentityDirectory {
  CredentialBackedDeviceIdentityDirectory({
    required CredentialStore credentials,
    required DeviceIdentityDecoder decoder,
    this.keyPrefix = 'taiwan_brawl.trusted-device.',
  }) : _credentials = credentials,
       _decoder = decoder;

  final CredentialStore _credentials;
  final DeviceIdentityDecoder _decoder;
  final String keyPrefix;

  Future<void> trust({
    required String deviceId,
    required String encodedMaterial,
  }) async {
    final normalizedId = _normalize(deviceId);
    final material = encodedMaterial.trim();
    if (normalizedId.isEmpty || material.isEmpty) {
      throw const FormatException('Trusted device material is required');
    }
    await _credentials.write(_key(normalizedId), material);
  }

  Future<void> revoke(String deviceId) async {
    final normalizedId = _normalize(deviceId);
    if (normalizedId.isEmpty) return;
    await _credentials.delete(_key(normalizedId));
  }

  @override
  Future<DeviceIdentity?> resolve(String deviceId) async {
    final normalizedId = _normalize(deviceId);
    if (normalizedId.isEmpty) return null;
    final material = await _credentials.read(_key(normalizedId));
    if (material == null || material.trim().isEmpty) return null;
    try {
      return await _decoder(normalizedId, material);
    } on FormatException {
      return null;
    }
  }

  String _key(String deviceId) => '$keyPrefix${_encode(deviceId)}';

  static String _normalize(String value) => value.trim();

  static String _encode(String value) => base64UrlEncode(utf8.encode(value));
}
