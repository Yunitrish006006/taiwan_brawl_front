/// Optional whole-conversation snapshot import/export operations.
///
/// Core direct-message sessions do not need to implement legacy server
/// snapshots. A session may expose this capability when the current
/// composition supports the compatibility sync workflow.
abstract interface class DirectMessageSyncService {
  Future<void> uploadSyncData(int selfId, int friendId);

  Future<void> downloadAndMergeSyncData(int friendId);
}
