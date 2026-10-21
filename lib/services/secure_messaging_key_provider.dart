import 'dart:convert';
import 'dart:math';

import 'package:taiwan_brawl_messaging/taiwan_brawl_messaging.dart';

import 'platform_credential_store.dart';

/// Backward-compatible name for the platform credential adapter.
///
/// New composition roots should construct [PlatformCredentialStore] directly;
/// this alias remains so older callers do not create a second credential
/// implementation while migrating.
@Deprecated('Use PlatformCredentialStore directly.')
typedef FlutterSecureCredentialStore = PlatformCredentialStore;

/// Loads or creates a 256-bit key without exposing key persistence to feature
/// code. The returned key can be injected into [HiveMessageEventStore].
class SecureMessagingKeyProvider implements EncryptionKeyProvider {
  SecureMessagingKeyProvider({
    required CredentialStore credentials,
    this.keyPrefix = 'taiwan_brawl.messaging.key.',
  }) : _credentials = credentials;

  final CredentialStore _credentials;
  final String keyPrefix;

  @override
  Future<List<int>> loadOrCreate(String purpose) async {
    final storageKey = '$keyPrefix$purpose';
    final encoded = await _credentials.read(storageKey);
    if (encoded != null) {
      try {
        final decoded = base64Url.decode(encoded);
        if (decoded.length == 32) return decoded;
      } on FormatException {
        // Replace malformed legacy/corrupt material below.
      }
      await _credentials.delete(storageKey);
    }

    final key = List<int>.generate(32, (_) => Random.secure().nextInt(256));
    await _credentials.write(storageKey, base64UrlEncode(key));
    return key;
  }
}
