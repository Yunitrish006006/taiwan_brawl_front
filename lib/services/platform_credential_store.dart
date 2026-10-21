import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:taiwan_brawl_messaging/taiwan_brawl_messaging.dart';

/// Platform credential adapter shared by authentication and messaging.
class PlatformCredentialStore implements CredentialStore {
  PlatformCredentialStore({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  @override
  Future<String?> read(String key) => _storage.read(key: key);

  @override
  Future<void> write(String key, String value) =>
      _storage.write(key: key, value: value);

  @override
  Future<void> delete(String key) => _storage.delete(key: key);
}
