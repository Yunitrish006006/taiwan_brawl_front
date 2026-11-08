@TestOn('vm')
library;

import 'dart:io';
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:taiwan_brawl/config/app_configuration.dart';
import 'package:taiwan_brawl/services/api_client.dart';
import 'package:taiwan_brawl/services/couples_remote_source.dart';
import 'package:taiwan_brawl/services/couples_service.dart';
import 'package:taiwan_brawl/services/couples_cache.dart';
import 'package:taiwan_brawl/services/couple_widget_bridge.dart';
import 'package:taiwan_brawl/services/couple_widget_controller.dart';
import 'package:taiwan_brawl/services/offline_couple_counter_service.dart';
import 'package:taiwan_brawl/services/auth_service.dart';
import 'package:taiwan_brawl/services/auth_remote_source.dart';
import 'package:taiwan_brawl_messaging/taiwan_brawl_messaging.dart';

class LocalCredentials implements CredentialStore {
  LocalCredentials(this.token);
  String token;
  @override
  Future<String?> read(String key) async => token;
  @override
  Future<void> write(String key, String value) async => token = value;
  @override
  Future<void> delete(String key) async => token = '';
}

class LocalHttpBinding extends AutomatedTestWidgetsFlutterBinding {
  @override
  bool get overrideHttpClient => false;
}

class UnverifiedIdentity implements AuthRemoteSource {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class ObservedWidgetBridge
    implements CoupleWidgetBridge, OfflineCoupleCounterSource {
  int generation = 0;
  Map<String, dynamic>? snapshot;
  @override
  Future<int> beginSession(String? scope) async {
    snapshot = null;
    return ++generation;
  }

  @override
  Future<void> replace(Map<String, dynamic> value) async {
    expect(value['sessionGeneration'], generation);
    snapshot = value;
  }

  @override
  Future<Map<String, dynamic>?> readCounter() async =>
      snapshot?['status'] == 'active'
      ? {
          'schemaVersion': 1,
          'startedOn': snapshot!['startedOn'],
          'lastSyncedAt': snapshot!['lastSyncedAt'],
        }
      : null;
}

void main() {
  const base = String.fromEnvironment('COUPLES_LOCAL_API');
  const nonce = String.fromEnvironment('COUPLES_LOCAL_NONCE');
  if (base.isNotEmpty) LocalHttpBinding();
  test(
    'isolated local D1 HTTP flow reaches Flutter cache and widget adapter',
    () async {
      final uri = Uri.parse(base);
      // Never allow this mutation test to target a deployed service.
      expect(uri.scheme, 'http');
      expect(uri.host, '127.0.0.1');
      expect(uri.port, 8795);
      expect(nonce, matches(RegExp(r'^[a-f0-9-]{36}$')));
      final probe = HttpClient();
      try {
        final request = await probe.getUrl(uri.resolve('/.couple-cd10/$nonce'));
        final response = await request.close();
        expect(response.statusCode, 200);
        expect(await response.transform(utf8.decoder).join(), nonce);
      } finally {
        probe.close(force: true);
      }
      final directory = await Directory.systemTemp.createTemp(
        'couple-local-http-',
      );
      Hive.init(directory.path);
      final configuration = AppConfiguration(
        apiBaseUrl: base,
        googleWebClientId: '',
        googleServerClientId: '',
        p2pChatEnabled: false,
      );
      final credentials = LocalCredentials('cd10-one');
      ApiClient client(LocalCredentials store) => ApiClient(
        configuration: configuration,
        credentials: store,
        cacheSession: false,
        clearSessionOnUnauthorized: false,
      );
      final oneClient = client(credentials);
      final oneSource = ServerCouplesRemoteSource(oneClient);
      final one = CouplesService(oneSource, cache: HiveCouplesCache())
        ..setAccount(910101);
      final two = CouplesService(
        ServerCouplesRemoteSource(client(LocalCredentials('cd10-two'))),
      )..setAccount(910102);
      final third = ServerCouplesRemoteSource(
        client(LocalCredentials('cd10-third')),
      );
      final bridge = ObservedWidgetBridge();
      final controller = CoupleWidgetController(
        bridge,
        scopeForAccount: (_) async => 'a' * 64,
      );
      void publish() => controller.sync(
        identityResolved: true,
        account: one.accountId,
        snapshot: one.snapshot,
      );
      one.addListener(publish);
      var operation = 0;
      String op() =>
          '10000000-0000-4000-8000-${(++operation).toString().padLeft(12, '0')}';
      String date(DateTime value) =>
          '${value.year.toString().padLeft(4, '0')}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';
      final start = DateTime.now().toUtc().subtract(const Duration(days: 2));
      try {
        await one.refresh();
        await two.refresh();
        final invite = await one.sendRequest(
          targetUserId: 910102,
          startedOn: date(start),
          timeZone: 'Asia/Taipei',
          operationId: op(),
        );
        await two.refresh();
        expect(one.snapshot!.relationship, isNull);
        expect(two.snapshot!.incomingRequests.single.id, invite.id);
        await two.acceptRequest(
          invite.id,
          timeZone: 'America/New_York',
          operationId: op(),
        );
        await one.refresh();
        await controller.flush();
        final relation = one.snapshot!.relationship!;
        expect(two.snapshot!.relationship!.startedOn, relation.startedOn);
        expect(bridge.snapshot!['startedOn'], relation.startedOn);
        expect(bridge.snapshot!['status'], 'active');
        final outsider = await third.overview(accountId: 910103);
        expect(outsider['data']['relationship'], isNull);
        await expectLater(
          third.mutate('/api/couples/${relation.id}/end', {
            'operationId': op(),
          }, accountId: 910103),
          throwsA(
            isA<ApiException>().having((e) => e.statusCode, 'status', 404),
          ),
        );
        await expectLater(
          third.overview(accountId: 910101),
          throwsA(
            isA<ApiException>().having((e) => e.statusCode, 'status', 409),
          ),
        );
        final proposed = date(start.subtract(const Duration(days: 5)));
        final proposal = await one.proposeDate(
          relation.id,
          startedOn: proposed,
          timeZone: 'Asia/Taipei',
          expectedVersion: relation.version,
          operationId: op(),
        );
        expect(one.snapshot!.relationship!.startedOn, relation.startedOn);
        await two.acceptDate(
          proposal.id,
          timeZone: 'America/New_York',
          operationId: op(),
        );
        await one.refresh();
        await one.flushCache();
        await controller.flush();
        expect(one.snapshot!.relationship!.startedOn, proposed);
        expect(one.snapshot!.relationship!.version, relation.version + 1);
        expect(bridge.snapshot!['startedOn'], proposed);
        final previousGeneration = bridge.generation;
        one.setAccount(null);
        await Future<void>.delayed(Duration.zero);
        await controller.flush();
        expect(bridge.snapshot!['status'], 'signedOut');
        expect(bridge.snapshot!['startedOn'], isNull);
        await oneClient.postJson('/api/logout', {});
        await expectLater(
          oneSource.overview(accountId: 910101),
          throwsA(
            isA<ApiException>().having(
              (error) => error.statusCode,
              'revoked session',
              401,
            ),
          ),
        );
        await Hive.close();
        credentials.token = 'cd10-one-relogin';
        one.setAccount(910101);
        await one.restore();
        await controller.flush();
        expect(one.isStale, isTrue);
        expect(
          one.snapshot!.relationship!.dayCount(
            DateTime.parse(proposed).add(const Duration(days: 31)),
          ),
          32,
        );
        expect(bridge.generation, greaterThan(previousGeneration));
        final unverified = AuthService(remoteSource: UnverifiedIdentity());
        final offline = OfflineCoupleCounterService(
          bridge,
          clock: () => DateTime.parse(proposed).add(const Duration(days: 31)),
        );
        try {
          offline.syncAuth(unverified);
          await offline.refresh();
          expect(offline.days, 32);
          expect(unverified.isLoggedIn, isFalse);
        } finally {
          offline.dispose();
          unverified.dispose();
        }
        await one.refresh();
        await one.endRelationship(relation.id, operationId: op());
        await two.refresh();
        await controller.flush();
        expect(one.snapshot!.relationship, isNull);
        expect(two.snapshot!.relationship, isNull);
        expect(bridge.snapshot!['status'], 'unbound');
        expect(bridge.snapshot!['startedOn'], isNull);
      } finally {
        await one.flushCache();
        await controller.flush();
        one.removeListener(publish);
        one.dispose();
        two.dispose();
        controller.dispose();
        await Hive.close();
        await directory.delete(recursive: true);
      }
    },
    skip: base.isEmpty
        ? 'Run scripts/verify-couple-days-local.mjs with an isolated Worker'
        : false,
  );
}
