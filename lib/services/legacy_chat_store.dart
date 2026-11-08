import '../models/legacy_chat_record.dart';

/// Read and migration-manifest capability used by history promotion.
abstract interface class LegacyChatHistoryStore {
  Future<LegacyChatHistorySnapshot> getHistorySnapshot(
    int selfId,
    int friendId,
  );

  Future<Set<String>?> migratedEventMessageIds(int selfId, int friendId);

  Future<bool> markEventMessagesMigrated(
    int selfId,
    int friendId,
    Set<String> messageIds, {
    required String expectedSourceRevision,
  });
}

/// A decoded legacy history read paired with the exact source revision read.
/// Implementations must reject the completion marker if the source changed.
class LegacyChatHistorySnapshot {
  const LegacyChatHistorySnapshot({
    required this.messages,
    required this.sourceRevision,
    this.invalidRowKeys = const [],
  });

  final List<LegacyChatRecord> messages;
  final String sourceRevision;

  /// Legacy Hive rows that could not be decoded or failed identity checks.
  /// They remain in the source box and prevent a complete migration marker.
  final List<String> invalidRowKeys;
}

/// Write capability used while consuming legacy pending rows.
abstract interface class LegacyPendingMessageStore {
  Future<void> saveMessage(int selfId, LegacyChatRecord message);

  Future<void> markRecalled(int selfId, int friendId, String messageKey);
}

/// Minimal write capability needed by the legacy HTTP delivery fallback.
abstract interface class LegacyChatDeliveryStore {
  Future<void> saveMessage(int selfId, LegacyChatRecord message);
}

/// Snapshot import/export capability used by legacy history synchronization.
abstract interface class LegacyChatSnapshotStore {
  Future<Map<String, Map<String, String>>> exportAll(
    int selfId,
    List<int> friendIds,
  );

  Future<void> importAll(Map<String, dynamic> data);
}
