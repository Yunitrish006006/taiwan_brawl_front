import 'package:hive_flutter/hive_flutter.dart';

/// Read-only compatibility port for installation metadata created before the
/// shared [CredentialStore] boundary existed.
abstract interface class LegacyInstallationStore {
  Future<String?> readInstallationId();
}

/// Hive adapter for the old `app_meta` installation-id entry.
class HiveLegacyInstallationStore implements LegacyInstallationStore {
  static const _boxName = 'app_meta';
  static const _installationIdKey = 'push.installation_id';

  @override
  Future<String?> readInstallationId() async {
    final box = await Hive.openBox(_boxName);
    return (box.get(_installationIdKey) as String?)?.trim();
  }
}
