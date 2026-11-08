import 'package:flutter_test/flutter_test.dart';
import 'package:taiwan_brawl/services/direct_message_session.dart';
import 'package:taiwan_brawl/services/direct_message_sync_service.dart';
import 'package:taiwan_brawl/services/manual_p2p_dm_service.dart';
import 'package:taiwan_brawl/services/retryable_dm_service.dart';

void main() {
  test(
    'a session can be created without optional retry or P2P capabilities',
    () {
      final session = _SessionWithoutOptionalCapabilities();
      final factory = _SessionFactory(session);

      final created = factory.create();
      expect(created, same(session));
      expect(created.retryCapability, isNull);
      expect(created.manualP2pCapability, isNull);
      expect(created.syncCapability, isNull);
    },
  );

  test('optional capabilities are exposed only when implemented', () {
    final session = _SessionWithOptionalCapabilities();
    final factory = _SessionFactory(session);

    final created = factory.create();
    expect(created.retryCapability, same(session));
    expect(created.manualP2pCapability, same(session));
    expect(created.syncCapability, same(session));
  });
}

class _SessionFactory implements DirectMessageSessionFactory {
  _SessionFactory(this.session);

  final DirectMessageSession session;

  @override
  DirectMessageSession create() => session;
}

class _SessionWithoutOptionalCapabilities implements DirectMessageSession {
  @override
  void dispose() {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _SessionWithOptionalCapabilities
    implements
        DirectMessageSession,
        DirectMessageSyncService,
        RetryableDmService,
        ManualP2pDmService {
  @override
  void dispose() {}

  @override
  Future<void> uploadSyncData(int selfId, int friendId) async {}

  @override
  Future<void> downloadAndMergeSyncData(int friendId) async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
