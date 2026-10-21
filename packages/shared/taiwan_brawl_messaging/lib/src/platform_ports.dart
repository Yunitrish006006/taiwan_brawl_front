import 'message_conflict.dart';
import 'message_event.dart';

/// Boundary for credentials such as session tokens, refresh tokens, and
/// device keys. Product features must not decide where secrets are stored.
abstract interface class CredentialStore {
  Future<String?> read(String key);

  Future<void> write(String key, String value);

  Future<void> delete(String key);
}

/// Supplies a key from platform-secure storage for an encrypted local store.
/// Implementations must not derive this key from a username or hard-code it in
/// application source.
abstract interface class EncryptionKeyProvider {
  Future<List<int>> loadOrCreate(String purpose);
}

/// Stable identity for one installation/device, independent of a server
/// account. The concrete implementation owns key generation and secure key
/// storage; this package only exposes the required operations.
abstract interface class DeviceIdentity {
  String get deviceId;

  Future<String> sign(String payload);

  Future<bool> verify(String payload, String signature, String deviceId);
}

/// Resolves a peer device identity for event signature verification.
abstract interface class DeviceIdentityDirectory {
  Future<DeviceIdentity?> resolve(String deviceId);
}

/// Durable event storage boundary. A Flutter adapter may implement this with
/// an encrypted SQLite/Hive store; a server adapter may implement it with D1,
/// Postgres, or another database. The domain package does not choose one.
abstract interface class MessageEventStore {
  Future<List<MessageEvent>> loadAll();

  Future<List<MessageEvent>> loadPendingOutbox();

  Future<void> append(MessageEvent event, {required bool pendingOutbox});

  Future<void> acknowledgeOutbox(String eventId);
}

/// Durable cursor state for a transport-specific synchronization scope.
///
/// Cursors are intentionally opaque to the shared package. A server relay may
/// use a database row id while another adapter may use a token or revision;
/// the local store only guarantees that the latest committed value survives
/// process restart.
abstract interface class MessageSyncCursorStore {
  Future<String?> loadSyncCursor(String scope);

  Future<void> saveSyncCursor(String scope, String cursor);
}

/// Optional durable inbox for remote events between transport receipt and
/// successful verification/projection. Implementations may use this to make a
/// receive-and-restart boundary recoverable without coupling transports to a
/// particular database.
abstract interface class MessageInboxStore {
  Future<List<MessageEvent>> loadInbox();

  Future<void> appendInbox(MessageEvent event);

  Future<void> removeInbox(String eventId);
}

/// Optional durable boundary for conflicts discovered while restoring or
/// receiving events. Existing event stores remain source-compatible when they
/// do not implement this capability.
abstract interface class MessageConflictStore {
  Future<List<MessageConflict>> loadConflicts();

  Future<void> appendConflict(MessageConflict conflict);
}
