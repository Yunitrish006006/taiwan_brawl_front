import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:taiwan_brawl/models/couples_overview.dart';
import 'package:taiwan_brawl/services/couple_widget_bridge.dart';
import 'package:taiwan_brawl/services/couple_widget_controller.dart';

CouplesOverview confirmed({String? name}) => CouplesOverview.fromJson({
  'ok': true,
  'serverNow': '2026-11-01T00:00:00Z',
  'data': {
    'relationship': {
      'id': 'relationship',
      'partnerUserId': 2,
      'partnerName': name,
      'startedOn': '2026-11-01',
      'status': 'active',
      'version': 1,
      'updatedAt': '2026-11-01T00:00:00Z',
    },
    'incomingRequests': [],
    'outgoingRequests': [],
    'dateProposal': null,
  },
});

class FakeBridge implements CoupleWidgetBridge {
  int generation = 20;
  Map<String, dynamic>? stored;
  final records = <Map<String, dynamic>>[];
  Completer<void>? delay;
  bool fail = false;
  @override
  Future<int> beginSession(String? scope) async {
    stored = {
      'accountScope': scope,
      'sessionGeneration': ++generation,
      'status': scope == null ? 'signedOut' : 'unbound',
    };
    return generation;
  }

  @override
  Future<void> replace(Map<String, dynamic> snapshot) async {
    final wait = delay;
    delay = null;
    if (wait != null) await wait.future;
    if (fail) throw StateError('disk full');
    if (snapshot['sessionGeneration'] != generation) {
      throw StateError('old generation');
    }
    stored = snapshot;
    records.add(snapshot);
  }
}

void main() {
  test('confirmed partner name is cleared on logout', () async {
    final bridge = FakeBridge();
    final controller = CoupleWidgetController(
      bridge,
      scopeForAccount: (_) async => 'opaque',
    );
    controller.sync(
      identityResolved: true,
      account: 1,
      snapshot: confirmed(name: 'Partner'),
    );
    await controller.flush();
    expect(bridge.stored!['partnerName'], 'Partner');
    controller.sync(identityResolved: true, account: null, snapshot: null);
    await controller.flush();
    expect(bridge.stored!['partnerName'], isNull);
    controller.dispose();
  });
  test(
    'minimal confirmed snapshot survives long offline identity uncertainty',
    () async {
      final bridge = FakeBridge();
      final controller = CoupleWidgetController(
        bridge,
        scopeForAccount: (_) async => 'opaque',
      );
      final snapshot = confirmed();
      controller.sync(identityResolved: true, account: 1, snapshot: snapshot);
      await controller.flush();
      final stored = bridge.stored;
      controller.sync(identityResolved: false, account: null, snapshot: null);
      await controller.flush();
      expect(bridge.stored, same(stored));
      expect(stored!.keys.toSet(), {
        'schemaVersion',
        'accountScope',
        'sessionGeneration',
        'requestSequence',
        'relationshipId',
        'relationshipVersion',
        'startedOn',
        'status',
        'lastSyncedAt',
        'partnerName',
      });
      expect(stored['accountScope'], 'opaque');
      expect(snapshot.relationship!.dayCount(DateTime(2026, 11, 4)), 4);
      expect(snapshot.relationship!.dayCount(DateTime(2027, 1, 1)), 62);
      expect(snapshot.relationship!.dayCount(DateTime(2026, 10, 31)), 1);
      controller.dispose();
    },
  );
  test(
    'logout queued behind an old write ends with a clear and next login uses a newer generation',
    () async {
      final bridge = FakeBridge();
      final controller = CoupleWidgetController(
        bridge,
        scopeForAccount: (id) async => 'opaque-$id',
      );
      controller.sync(
        identityResolved: true,
        account: 1,
        snapshot: confirmed(),
      );
      await controller.flush();
      final oldGeneration = bridge.generation;
      final delay = Completer<void>();
      bridge.delay = delay;
      controller.sync(
        identityResolved: true,
        account: 1,
        snapshot: confirmed(),
      );
      await Future<void>.delayed(Duration.zero);
      controller.sync(identityResolved: true, account: null, snapshot: null);
      delay.complete();
      await controller.flush();
      expect(bridge.stored!['status'], 'signedOut');
      expect(bridge.stored!['startedOn'], isNull);
      controller.sync(
        identityResolved: true,
        account: 1,
        snapshot: confirmed(),
      );
      await controller.flush();
      expect(bridge.generation, greaterThan(oldGeneration));
      controller.dispose();
    },
  );
  test(
    'switch before scope lookup finishes cannot publish the old account',
    () async {
      final bridge = FakeBridge(), lookup = Completer<String>();
      final controller = CoupleWidgetController(
        bridge,
        scopeForAccount: (id) =>
            id == 1 ? lookup.future : Future.value('second'),
      );
      controller.sync(
        identityResolved: true,
        account: 1,
        snapshot: confirmed(),
      );
      await Future<void>.delayed(Duration.zero);
      controller.sync(identityResolved: true, account: 2, snapshot: null);
      lookup.complete('first');
      await controller.flush();
      expect(bridge.records.any((r) => r['accountScope'] == 'first'), isFalse);
      expect(bridge.stored!['accountScope'], 'second');
      expect(bridge.stored!['status'], 'unbound');
      controller.dispose();
    },
  );
  test(
    'native persistence failure is observable and retry does not require new data',
    () async {
      final bridge = FakeBridge()..fail = true;
      final controller = CoupleWidgetController(
        bridge,
        scopeForAccount: (_) async => 'opaque',
      );
      final snapshot = confirmed();
      controller.sync(identityResolved: true, account: 1, snapshot: snapshot);
      await controller.flush();
      expect(controller.failed, isTrue);
      bridge.fail = false;
      controller.sync(identityResolved: true, account: 1, snapshot: snapshot);
      await controller.flush();
      expect(controller.failed, isFalse);
      expect(bridge.stored!['status'], 'active');
      controller.dispose();
    },
  );
  test('unsupported platforms perform no native writes', () async {
    final bridge = FakeBridge();
    final controller = CoupleWidgetController(
      bridge,
      scopeForAccount: (_) async => 'opaque',
      enabled: false,
    );
    controller.sync(identityResolved: true, account: 1, snapshot: confirmed());
    await controller.flush();
    expect(bridge.generation, 20);
    controller.dispose();
  });
}
