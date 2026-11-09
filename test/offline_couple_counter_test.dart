import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:taiwan_brawl/models/offline_couple_counter.dart';
import 'package:taiwan_brawl/services/auth_service.dart';
import 'package:taiwan_brawl/services/auth_remote_source.dart';
import 'package:taiwan_brawl/services/remote_source_exception.dart';
import 'package:taiwan_brawl/services/offline_couple_counter_service.dart';
import 'package:taiwan_brawl/pages/social/offline_couple_counter_page.dart';

Map<String, dynamic> projection() => {
  'schemaVersion': 1,
  'startedOn': '2026-11-01',
  'lastSyncedAt': '2026-11-04T00:00:00Z',
};

class CounterSource implements OfflineCoupleCounterSource {
  Completer<Map<String, dynamic>?>? pending;
  Object? error;
  @override
  Future<Map<String, dynamic>?> readCounter() async {
    if (error != null) throw error!;
    return pending?.future ?? projection();
  }
}

class CounterAuth implements AuthRemoteSource {
  Object? error = const RemoteSourceException('offline');
  final login = Completer<Map<String, dynamic>>();
  @override
  Future<Map<String, dynamic>> loadCurrentUser() async {
    if (error != null) throw error!;
    return {
      'user': {'id': 1, 'name': 'Verified', 'email': 'verified@example.test'},
    };
  }

  @override
  Future<Map<String, dynamic>> verifyGoogleToken(String token) => login.future;
  @override
  Future<Map<String, dynamic>> logout() async => {'ok': true};
  @override
  Future<void> clearSession() async {}
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'login entry opens only the counter and hides it as soon as sign-in starts',
    (tester) async {
      final remote = CounterAuth();
      final auth = AuthService(remoteSource: remote);
      final service = OfflineCoupleCounterService(
        CounterSource(),
        clock: () => DateTime(2026, 11, 4),
      );
      void sync() => service.syncAuth(auth);
      auth.addListener(sync);
      sync();
      await service.refresh();
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: service),
            ChangeNotifierProvider.value(value: auth),
          ],
          child: MaterialApp(
            home: const Scaffold(body: OfflineCoupleCounterEntry()),
            routes: {
              '/couple-offline': (_) => const OfflineCoupleCounterPage(),
            },
          ),
        ),
      );
      await tester.tap(find.text('離線交往天數'));
      await tester.pumpAndSettle();
      expect(find.text('交往第 4 天'), findsOneWidget);
      expect(find.textContaining('第一天'), findsNothing);
      expect(auth.isLoggedIn, isFalse);
      final login = auth.verifyGoogleToken('synthetic');
      final failure = expectLater(login, throwsA(isA<RemoteSourceException>()));
      await tester.pump();
      expect(find.text('交往第 4 天'), findsNothing);
      remote.login.completeError(const RemoteSourceException('offline'));
      await failure;
      await tester.pumpAndSettle();
      expect(service.counter, isNull);
      expect(auth.isLoggedIn, isFalse);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      auth.removeListener(sync);
      service.dispose();
      auth.dispose();
    },
  );
  test(
    'failed private storage read hides previous projection instead of reusing it',
    () async {
      final auth = AuthService(remoteSource: CounterAuth());
      final source = CounterSource();
      final service = OfflineCoupleCounterService(source);
      service.syncAuth(auth);
      await service.refresh();
      expect(service.counter, isNotNull);
      source.error = StateError('unavailable');
      await service.refresh();
      expect(service.failed, isTrue);
      expect(service.counter, isNull);
      service.dispose();
      auth.dispose();
    },
  );
  test(
    'cold offline projection supplies 31-day counting without authenticating an account',
    () async {
      final auth = AuthService(remoteSource: CounterAuth());
      final service = OfflineCoupleCounterService(CounterSource());
      await auth.init();
      service.syncAuth(auth);
      await service.refresh();
      expect(service.allowed, isTrue);
      expect(auth.isLoggedIn, isFalse);
      expect(service.counter!.dayCount(DateTime(2026, 12, 2)), 32);
      expect(service.counter!.dayCount(DateTime(2026, 10, 31)), 1);
      service.dispose();
      auth.dispose();
    },
  );
  test(
    'login start invalidates delayed reads and failed login cannot reopen the cold window',
    () async {
      final remote = CounterAuth();
      final auth = AuthService(remoteSource: remote);
      final pending = Completer<Map<String, dynamic>?>();
      final service = OfflineCoupleCounterService(
        CounterSource()..pending = pending,
      );
      service.syncAuth(auth);
      final login = auth.verifyGoogleToken('synthetic');
      expect(auth.isSigningIn, isTrue);
      service.syncAuth(auth);
      expect(service.allowed, isFalse);
      pending.complete(projection());
      await Future<void>.delayed(Duration.zero);
      expect(service.counter, isNull);
      remote.login.completeError(
        const RemoteSourceException('rejected', statusCode: 401),
      );
      await expectLater(login, throwsA(isA<RemoteSourceException>()));
      await auth.refreshMe();
      service.syncAuth(auth);
      await service.refresh();
      expect(auth.identityState, AuthIdentityState.unresolved);
      expect(service.counter, isNull);
      expect(service.allowed, isFalse);
      service.dispose();
      auth.dispose();
    },
  );
  for (final expired in [false, true]) {
    test(
      '${expired ? "401" : "explicit logout"} removes the projection and rejects late completion',
      () async {
        final remote = CounterAuth();
        final auth = AuthService(remoteSource: remote);
        final pending = Completer<Map<String, dynamic>?>();
        final service = OfflineCoupleCounterService(
          CounterSource()..pending = pending,
        );
        service.syncAuth(auth);
        if (expired) {
          remote.error = const RemoteSourceException(
            'expired',
            statusCode: 401,
          );
          await auth.init();
        } else {
          await auth.logout();
        }
        service.syncAuth(auth);
        pending.complete(projection());
        await Future<void>.delayed(Duration.zero);
        expect(service.counter, isNull);
        expect(service.allowed, isFalse);
        service.dispose();
        auth.dispose();
      },
    );
  }
  test(
    'online identity suspends read-only access; expiry closes it permanently',
    () async {
      final remote = CounterAuth()..error = null;
      final auth = AuthService(remoteSource: remote);
      final service = OfflineCoupleCounterService(CounterSource());
      service.syncAuth(auth);
      await service.refresh();
      expect(service.counter, isNotNull);
      await auth.init();
      service.syncAuth(auth);
      expect(service.counter, isNull);
      expect(service.allowed, isFalse);
      remote.error = const RemoteSourceException('offline');
      await auth.refreshMe();
      service.syncAuth(auth);
      await service.refresh();
      expect(auth.isLoggedIn, isFalse);
      expect(service.allowed, isTrue);
      expect(service.counter, isNotNull);
      remote.error = const RemoteSourceException('expired', statusCode: 401);
      await auth.refreshMe();
      service.syncAuth(auth);
      expect(service.allowed, isFalse);
      remote.error = const RemoteSourceException('offline');
      await auth.refreshMe();
      service.syncAuth(auth);
      await service.refresh();
      expect(service.allowed, isFalse);
      expect(service.counter, isNull);
      service.dispose();
      auth.dispose();
    },
  );
  test('counter rejects malformed dates and any identity fields', () {
    expect(
      () => OfflineCoupleCounter.fromJson({
        ...projection(),
        'startedOn': '2026-02-30',
      }),
      throwsFormatException,
    );
    expect(
      () => OfflineCoupleCounter.fromJson({
        ...projection(),
        'accountScope': 'unexpected',
      }),
      throwsFormatException,
    );
  });
  test('native reader requests only the display projection', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    const channel = MethodChannel('taiwan_brawl/couple_widget');
    final methods = <String>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          methods.add(call.method);
          return projection();
        });
    addTearDown(() {
      debugDefaultTargetPlatformOverride = null;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    });
    final value = await NativeOfflineCoupleCounterSource().readCounter();
    expect(value, projection());
    expect(methods, ['readCounter']);
  }, skip: kIsWeb);
  testWidgets(
    'read-only page updates across day and resume without relationship actions',
    (tester) async {
      var now = DateTime(2026, 11, 4, 23, 59);
      final auth = AuthService(remoteSource: CounterAuth());
      final service = OfflineCoupleCounterService(
        CounterSource(),
        clock: () => now,
      );
      service.syncAuth(auth);
      await service.refresh();
      await tester.pumpWidget(
        ChangeNotifierProvider.value(
          value: service,
          child: MaterialApp(
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: TextScaler.linear(2)),
              child: child!,
            ),
            home: const OfflineCoupleCounterPage(),
          ),
        ),
      );
      expect(find.text('交往第 4 天'), findsOneWidget);
      expect(find.text('解除情侶'), findsNothing);
      expect(find.text('邀請'), findsNothing);
      now = DateTime(2026, 11, 5);
      await tester.pump(const Duration(minutes: 1));
      expect(find.text('交往第 5 天'), findsOneWidget);
      service.didChangeAppLifecycleState(AppLifecycleState.paused);
      now = DateTime(2026, 11, 9);
      await tester.pump(const Duration(minutes: 2));
      expect(find.text('交往第 5 天'), findsOneWidget);
      service.didChangeAppLifecycleState(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
      expect(find.text('交往第 9 天'), findsOneWidget);
      expect(auth.isLoggedIn, isFalse);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      service.dispose();
      auth.dispose();
    },
  );
}
