import 'dart:async';
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/widgets.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:taiwan_brawl/models/couple_relationship.dart';
import 'package:taiwan_brawl/services/api_client.dart';
import 'package:taiwan_brawl/services/auth_remote_source.dart';
import 'package:taiwan_brawl/services/auth_service.dart';
import 'package:taiwan_brawl/services/couples_remote_source.dart';
import 'package:taiwan_brawl/services/couples_service.dart';
import 'package:taiwan_brawl/services/couples_cache.dart';
import 'package:taiwan_brawl/services/remote_source_exception.dart';
import 'package:taiwan_brawl_messaging/taiwan_brawl_messaging.dart';

Map<String, dynamic> overview({int? partner}) => {
  'ok': true,
  'serverNow': '2026-11-04T04:00:00Z',
  'data': {
    'relationship': partner == null
        ? null
        : {
            'id': 'r',
            'partnerUserId': partner,
            'startedOn': '2026-11-01',
            'status': 'active',
            'version': 1,
            'updatedAt': '2026-11-04T04:00:00Z',
            'endedAt': null,
          },
    'incomingRequests': <Object>[],
    'outgoingRequests': <Object>[],
    'dateProposal': null,
  },
};

class FakeRemote implements CouplesRemoteSource {
  final List<Completer<Map<String, dynamic>>> pending = [];
  @override
  Future<Map<String, dynamic>> overview({required int accountId}) {
    final c = Completer<Map<String, dynamic>>();
    pending.add(c);
    return c.future;
  }

  @override
  Future<Map<String, dynamic>> mutate(
    String path,
    Map<String, dynamic> body, {
    required int accountId,
  }) async => {'ok': true, 'replayed': true};
}

class OfflineAuth implements AuthRemoteSource {
  @override
  Future<Map<String, dynamic>> loadCurrentUser() async =>
      throw const RemoteSourceException('offline');
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class MemoryCache implements CouplesCache {
  final values = <int, Map<String, dynamic>>{};
  @override
  Future<Map<String, dynamic>?> read(int accountId) async => values[accountId];
  @override
  Future<void> write(int accountId, Map<String, dynamic> value) async {
    values[accountId] = value;
  }

  @override
  Future<void> remove(int accountId) async {
    values.remove(accountId);
  }
}

class DelayedCache extends MemoryCache {
  final started = Completer<void>();
  final release = Completer<void>();
  bool first = true;
  @override
  Future<void> write(int accountId, Map<String, dynamic> value) async {
    if (first) {
      first = false;
      started.complete();
      await release.future;
    }
    await super.write(accountId, value);
  }
}

class DelayedReadCache extends MemoryCache {
  final release = Completer<void>();
  @override
  Future<Map<String, dynamic>?> read(int accountId) async {
    await release.future;
    return super.read(accountId);
  }
}

class FailingCache extends MemoryCache {
  @override
  Future<void> write(int accountId, Map<String, dynamic> value) async =>
      throw StateError('storage failed');
  @override
  Future<void> remove(int accountId) async =>
      throw StateError('storage failed');
}

class RecoveringCache extends MemoryCache {
  bool failing = true;
  final started = Completer<void>();
  final release = Completer<void>();
  @override
  Future<void> write(int accountId, Map<String, dynamic> value) async {
    if (failing) throw StateError('storage unavailable');
    started.complete();
    await release.future;
    await super.write(accountId, value);
  }
}

class Credentials implements CredentialStore {
  @override
  Future<String?> read(String key) async => null;
  @override
  Future<void> write(String key, String value) async {}
  @override
  Future<void> delete(String key) async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'cache recovery clears the failure flag and notifies observers',
    () async {
      final remote = FakeRemote(),
          cache = RecoveringCache(),
          service = CouplesService(remote, cache: cache)..setAccount(1);
      var notifications = 0;
      service.addListener(() => notifications++);
      final first = service.refresh();
      remote.pending.last.complete(overview(partner: 2));
      await first;
      await service.flushCache();
      expect(service.cacheWriteFailed, isTrue);
      cache.failing = false;
      final second = service.refresh();
      remote.pending.last.complete(overview(partner: 2));
      await second;
      await cache.started.future;
      final before = notifications;
      cache.release.complete();
      await service.flushCache();
      expect(service.cacheWriteFailed, isFalse);
      expect(notifications, greaterThan(before));
      service.dispose();
    },
  );
  test(
    'offline cold start does not expose any account cache without an authenticated identity',
    () async {
      final auth = AuthService(remoteSource: OfflineAuth());
      await auth.init();
      final cache = MemoryCache()..values[1] = overview(partner: 2);
      final service = CouplesService(FakeRemote(), cache: cache)
        ..setAccount(auth.user?.id);
      await service.restore();
      expect(auth.user, isNull);
      expect(service.accountId, isNull);
      expect(service.snapshot, isNull);
      service.dispose();
      auth.dispose();
    },
  );
  test(
    'storage failures are exposed without claiming a successful snapshot persisted',
    () async {
      final remote = FakeRemote(),
          service = CouplesService(remote, cache: FailingCache())
            ..setAccount(1);
      final fetch = service.refresh();
      remote.pending.single.complete(overview(partner: 2));
      await fetch;
      await service.flushCache();
      expect(service.snapshot!.relationship!.partnerUserId, 2);
      expect(service.cacheWriteFailed, isTrue);
      service.dispose();
    },
  );
  test('manual network failures mark a cached snapshot stale', () async {
    final remote = FakeRemote(),
        service = CouplesService(remote)..setAccount(1);
    final first = service.refresh();
    remote.pending.last.complete(overview(partner: 2));
    await first;
    final failed = service.refresh();
    remote.pending.last.completeError(StateError('offline'));
    await expectLater(failed, throwsStateError);
    expect(service.isStale, isTrue);
    expect(service.lastRefreshFailed, isTrue);
    service.dispose();
  });
  test(
    '401 for the current account clears visible state without logging out a later account',
    () async {
      final remote = FakeRemote(),
          service = CouplesService(remote)..setAccount(1);
      final request = service.refresh();
      remote.pending.single.completeError(
        ApiException('expired', statusCode: 401),
      );
      await expectLater(request, throwsA(isA<ApiException>()));
      expect(service.accountId, isNull);
      expect(service.sessionExpired, isTrue);
      expect(service.snapshot, isNull);
      service.setAccount(2);
      expect(service.sessionExpired, isFalse);
      service.dispose();
    },
  );
  test('old account 401 cannot clear the new account state', () async {
    final remote = FakeRemote(),
        service = CouplesService(remote)..setAccount(1);
    final old = service.refresh();
    service.setAccount(2);
    final current = service.refresh();
    remote.pending[1].complete(overview(partner: 3));
    await current;
    remote.pending[0].completeError(ApiException('expired', statusCode: 401));
    await expectLater(old, throwsA(isA<ApiException>()));
    expect(service.accountId, 2);
    expect(service.snapshot!.relationship!.partnerUserId, 3);
    service.dispose();
  });
  test(
    'cache can restore while network is in flight but never replaces a newer response',
    () async {
      final cache = DelayedReadCache()..values[1] = overview(partner: 2);
      final remote = FakeRemote(),
          service = CouplesService(remote, cache: cache)..setAccount(1);
      final load = service.restore();
      final request = service.refresh();
      cache.release.complete();
      await load;
      expect(service.snapshot!.relationship!.partnerUserId, 2);
      remote.pending.single.complete(overview(partner: 3));
      await request;
      expect(service.snapshot!.relationship!.partnerUserId, 3);
      service.dispose();
    },
  );
  test(
    'cache read completing after a fresh response cannot replace it',
    () async {
      final cache = DelayedReadCache()..values[1] = overview(partner: 2);
      final remote = FakeRemote(),
          service = CouplesService(remote, cache: cache)..setAccount(1);
      final load = service.restore();
      final request = service.refresh();
      remote.pending.single.complete(overview(partner: 3));
      await request;
      cache.release.complete();
      await load;
      expect(service.snapshot!.relationship!.partnerUserId, 3);
      service.dispose();
    },
  );
  test(
    'late durable writes cannot overwrite a newer session of the same account',
    () async {
      final cache = DelayedCache(),
          remote = FakeRemote(),
          service = CouplesService(remote, cache: cache)..setAccount(1);
      final old = service.refresh();
      remote.pending[0].complete(overview(partner: 2));
      await old;
      await cache.started.future;
      service.setAccount(3);
      service.setAccount(1);
      final fresh = service.refresh();
      remote.pending[1].complete(overview(partner: 4));
      await fresh;
      cache.release.complete();
      await service.flushCache();
      expect(cache.values[1]!['data']['relationship']['partnerUserId'], 4);
      service.dispose();
    },
  );
  testWidgets(
    'foreground, recovery, midnight and disposal drive only scoped refreshes',
    (tester) async {
      final network = StreamController<bool>();
      final remote = FakeRemote();
      var clock = DateTime(2026, 11, 4, 23, 59, 30), notifications = 0;
      final service = CouplesService(
        remote,
        autoSync: true,
        clock: () => clock,
        networkChanges: network.stream,
      );
      service.addListener(() => notifications++);
      service.setAccount(1);
      await tester.pump();
      expect(remote.pending.length, 1);
      remote.pending.last.complete(overview(partner: 2));
      await tester.pump();
      network.add(false);
      await tester.pump();
      network.add(true);
      await tester.pump();
      expect(remote.pending.length, 2);
      remote.pending.last.complete(overview(partner: 2));
      await tester.pump();
      final before = notifications;
      clock = DateTime(2026, 11, 5, 0, 0, 1);
      await tester.pump(const Duration(seconds: 31));
      expect(notifications, greaterThan(before));
      service.didChangeAppLifecycleState(AppLifecycleState.paused);
      final count = remote.pending.length;
      await tester.pump(const Duration(minutes: 2));
      expect(remote.pending.length, count);
      service.didChangeAppLifecycleState(AppLifecycleState.resumed);
      await tester.pump();
      expect(remote.pending.length, count + 1);
      remote.pending.last.complete(overview(partner: 2));
      await tester.pump();
      service.dispose();
      unawaited(network.close());
      await tester.pump();
    },
  );
  test(
    'confirmed state survives service restart and is isolated by account',
    () async {
      final cache = MemoryCache(), remote = FakeRemote();
      final first = CouplesService(remote, cache: cache)..setAccount(1);
      final fetch = first.refresh();
      remote.pending.last.complete(overview(partner: 2));
      await fetch;
      await first.flushCache();
      first.dispose();
      final second = CouplesService(remote, cache: cache)..setAccount(1);
      await second.restore();
      expect(second.snapshot!.relationship!.partnerUserId, 2);
      expect(second.isStale, isTrue);
      second.setAccount(3);
      await second.restore();
      expect(second.snapshot, isNull);
      second.dispose();
    },
  );
  test(
    'successful mutation invalidates durable old state before failed refresh',
    () async {
      final cache = MemoryCache(), remote = FakeRemote();
      final service = CouplesService(remote, cache: cache)..setAccount(1);
      final initial = service.refresh();
      remote.pending.last.complete(overview(partner: 2));
      await initial;
      await service.flushCache();
      final operation = service.mutate('/api/couples/r/end', {
        'operationId': 'same',
      });
      await Future<void>.delayed(Duration.zero);
      expect(cache.values[1], isNull);
      remote.pending.last.completeError(StateError('offline'));
      expect((await operation)['ok'], isTrue);
      expect(service.lastRefreshFailed, isTrue);
      expect(service.snapshot, isNull);
      service.dispose();
    },
  );
  test(
    'old account delayed response cannot overwrite persisted current account',
    () async {
      final cache = MemoryCache(),
          remote = FakeRemote(),
          service = CouplesService(remote, cache: cache)..setAccount(1);
      final old = service.refresh();
      service.setAccount(2);
      final current = service.refresh();
      remote.pending[1].complete(overview(partner: 3));
      await current;
      await service.flushCache();
      remote.pending[0].complete(overview(partner: 9));
      await old;
      await service.flushCache();
      expect(cache.values.containsKey(1), isFalse);
      expect(cache.values[2]!['data']['relationship']['partnerUserId'], 3);
      service.dispose();
    },
  );
  test('local calendar days handle leap years and clamp across date line', () {
    final j =
        overview(partner: 2)['data']['relationship'] as Map<String, dynamic>;
    final r = CoupleRelationship.fromJson({...j, 'startedOn': '2024-02-28'});
    expect(r.dayCount(DateTime(2024, 3, 1)), 3);
    expect(r.dayCount(DateTime(2024, 2, 27)), 1);
    expect(
      () => CoupleRelationship.fromJson({...j, 'startedOn': '2024-02-30'}),
      throwsFormatException,
    );
  });
  test('logout and switching account discard old in-flight results', () async {
    final remote = FakeRemote(),
        service = CouplesService(remote)..setAccount(1);
    final old = service.refresh();
    service.setAccount(2);
    final current = service.refresh();
    remote.pending[1].complete(overview(partner: 3));
    await current;
    remote.pending[0].complete(overview(partner: 9));
    expect(await old, isNull);
    expect(service.snapshot!.relationship!.partnerUserId, 3);
    service.setAccount(null);
    expect(service.snapshot, isNull);
  });
  test(
    'refresh is single flight and mutation replaces stale response with overview',
    () async {
      final remote = FakeRemote(),
          service = CouplesService(remote)..setAccount(1);
      final first = service.refresh();
      expect(identical(first, service.refresh()), isTrue);
      final mutation = service.mutate('/api/couples/requests', {
        'operationId': 'a',
      });
      await Future<void>.delayed(Duration.zero);
      expect(remote.pending.length, 2);
      remote.pending[1].complete(overview(partner: 2));
      await mutation;
      remote.pending[0].complete(overview(partner: 9));
      expect(await first, isNull);
      expect(service.snapshot!.relationship!.partnerUserId, 2);
    },
  );
  test(
    'remote adapter sends specified operation and preserves typed error body',
    () async {
      final requests = <http.Request>[];
      final source = ServerCouplesRemoteSource(
        ApiClient(
          credentials: Credentials(),
          client: MockClient((r) async {
            requests.add(r);
            return http.Response(
              jsonEncode({
                'ok': false,
                'error': {
                  'code': 'VERSION_CONFLICT',
                  'message': 'Refresh relationship',
                },
                'requestId': 'x',
              }),
              409,
              headers: {'content-type': 'application/json'},
            );
          }),
        ),
      );
      await expectLater(
        source.mutate('/api/couples/requests', {
          'operationId': 'id',
        }, accountId: 101),
        throwsA(
          isA<ApiException>().having(
            (e) => e.responseBody!['error']['code'],
            'code',
            'VERSION_CONFLICT',
          ),
        ),
      );
      expect(requests.single.url.path, '/api/couples/requests');
      expect(requests.single.headers['X-Expected-Account-ID'], '101');
      expect(jsonDecode(requests.single.body)['operationId'], 'id');
      expect(
        () => source.mutate('/api/couples/../users', {}, accountId: 101),
        throwsArgumentError,
      );
    },
  );
}
