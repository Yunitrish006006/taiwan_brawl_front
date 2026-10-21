import 'package:flutter/foundation.dart';
import 'package:taiwan_brawl_messaging/taiwan_brawl_messaging.dart';

import 'hive_messaging_store.dart';
import 'messaging_core_service.dart';
import 'secure_device_identity.dart';
import 'secure_messaging_key_provider.dart';

/// The restored messaging dependencies owned by the application bootstrap.
///
/// The composition root may use [core] even when durable restoration is
/// degraded; [storageStatus] remains visible to the UI through the core
/// service instead of silently pretending the fallback is durable.
class MessagingRuntime {
  const MessagingRuntime({
    required this.core,
    this.deviceIdentity,
    this.syncCursorStore,
  });

  final MessagingCoreService core;
  final DeviceIdentity? deviceIdentity;
  final MessageSyncCursorStore? syncCursorStore;
}

/// Restores encrypted messaging state and device identity for a composition
/// root. A platform-storage failure keeps startup available through an
/// explicit degraded in-memory core so the legacy migration path can still
/// render and report the persistence problem.
Future<MessagingRuntime> restoreMessagingRuntime(
  CredentialStore credentials,
) async {
  SecureDeviceIdentity? deviceIdentity;
  try {
    deviceIdentity = await SecureDeviceIdentity.restore(
      credentials: credentials,
    );
    final keyProvider = SecureMessagingKeyProvider(credentials: credentials);
    final key = await keyProvider.loadOrCreate('message-events');
    final store = HiveMessageEventStore(encryptionKey: key);
    final authenticator = DeviceEventAuthenticator(
      localIdentity: deviceIdentity,
    );
    return MessagingRuntime(
      core: await MessagingCoreService.restore(
        store,
        authenticator: authenticator,
      ),
      deviceIdentity: deviceIdentity,
      syncCursorStore: store,
    );
  } catch (error, stackTrace) {
    debugPrint('Messaging core restore unavailable: $error');
    debugPrintStack(stackTrace: stackTrace);
    return MessagingRuntime(
      core: MessagingCoreService(
        storageStatus: MessagingStorageStatus.degraded(error),
      ),
      deviceIdentity: deviceIdentity,
    );
  }
}
