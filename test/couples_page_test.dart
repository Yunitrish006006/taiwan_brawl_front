import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:taiwan_brawl/pages/social/couples_page.dart';
import 'package:taiwan_brawl/services/couples_remote_source.dart';
import 'package:taiwan_brawl/services/couples_service.dart';
import 'package:taiwan_brawl/services/device_time_zone.dart';
import 'package:taiwan_brawl/pages/social/friend_detail_page.dart';
import 'package:taiwan_brawl/models/friends_models.dart';
import 'package:taiwan_brawl/services/locale_provider.dart';
import 'package:taiwan_brawl/constants/generated/locale_catalog.g.dart';

class PageRemote implements CouplesRemoteSource {
  bool offline = false;
  bool invitation = false;
  bool paired = true;
  bool succeed = false;
  int? proposalActor;
  final writes = <Map<String, dynamic>>[];
  @override
  Future<Map<String, dynamic>> overview({required int accountId}) async {
    if (offline) throw StateError('offline');
    return {
      'ok': true,
      'serverNow': '2026-11-05T00:00:00Z',
      'data': {
        'relationship': paired
            ? {
                'id': 'r',
                'partnerUserId': 2,
                'startedOn': '2026-11-01',
                'status': 'active',
                'version': 1,
                'updatedAt': '2026-11-05T00:00:00Z',
              }
            : null,
        'incomingRequests': invitation
            ? [
                {
                  'id': 'request-id',
                  'requesterUserId': 2,
                  'recipientUserId': 1,
                  'startedOn': '2026-11-01',
                  'status': 'pending',
                  'createdAt': '2026-11-05T00:00:00Z',
                  'expiresAt': '2026-11-12T00:00:00Z',
                },
              ]
            : [],
        'outgoingRequests': [],
        'dateProposal': proposalActor == null
            ? null
            : {
                'id': 'proposal-id',
                'relationshipId': 'r',
                'requesterUserId': proposalActor,
                'startedOn': '2026-10-01',
                'baseVersion': 1,
                'status': 'pending',
                'createdAt': '2026-11-05T00:00:00Z',
                'expiresAt': '2026-11-12T00:00:00Z',
              },
      },
    };
  }

  @override
  Future<Map<String, dynamic>> mutate(
    String path,
    Map<String, dynamic> body, {
    required int accountId,
  }) async {
    writes.add({...body, 'path': path, 'accountId': accountId});
    if (succeed && path.endsWith('/end')) {
      final before = await overview(accountId: accountId);
      final relationship = Map<String, dynamic>.from(
        before['data']['relationship'] as Map,
      );
      relationship['status'] = 'ended';
      paired = false;
      return {
        'ok': true,
        'data': {'relationship': relationship},
      };
    }
    throw StateError('response lost');
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  for (final invite in [true, false]) {
    testWidgets(
      '${invite ? "invite" : "date proposal"} picks today or a past date with the current timezone',
      (tester) async {
        const channel = MethodChannel('taiwan_brawl/device_time_zone');
        final messenger =
            TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
        messenger.setMockMethodCallHandler(channel, (_) async => 'Asia/Taipei');
        addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
        final remote = PageRemote()..paired = !invite;
        final service = CouplesService(remote)..setAccount(1);
        await service.refresh();
        await tester.pumpWidget(
          ChangeNotifierProvider.value(
            value: service,
            child: const MaterialApp(
              home: CouplesPage(
                friends: [
                  SocialUser(
                    userId: 2,
                    name: 'Partner',
                    bio: '',
                    avatarUrl: null,
                    lastActiveAt: null,
                    isOnline: false,
                  ),
                ],
              ),
            ),
          ),
        );
        await tester.tap(find.text(invite ? '邀請' : '提出修改日期'));
        await tester.pumpAndSettle();
        final picker = tester.widget<DatePickerDialog>(
          find.byType(DatePickerDialog),
        );
        final now = DateTime.now();
        expect(DateUtils.isSameDay(picker.lastDate, now), isTrue);
        await tester.tap(find.text('OK'));
        await tester.pumpAndSettle();
        expect(remote.writes.single['timeZone'], 'Asia/Taipei');
        expect(
          remote.writes.single['path'],
          invite ? '/api/couples/requests' : '/api/couples/r/date-proposals',
        );
        if (invite) {
          expect(remote.writes.single['targetUserId'], 2);
        } else {
          expect(remote.writes.single['expectedVersion'], 1);
        }
        expect(
          DateTime.parse(
            remote.writes.single['startedOn'] as String,
          ).isAfter(now),
          isFalse,
        );
        await tester.pumpWidget(const SizedBox());
        service.dispose();
      },
    );
  }
  testWidgets(
    'switching accounts while selecting a date prevents the old operation',
    (tester) async {
      final remote = PageRemote();
      final service = CouplesService(remote)..setAccount(1);
      await service.refresh();
      await tester.pumpWidget(
        ChangeNotifierProvider.value(
          value: service,
          child: const MaterialApp(home: CouplesPage(friends: [])),
        ),
      );
      await tester.tap(find.text('提出修改日期'));
      await tester.pumpAndSettle();
      service.setAccount(3);
      await tester.pumpAndSettle();
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      expect(remote.writes, isEmpty);
      expect(find.textContaining('帳號已變更'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      service.dispose();
    },
  );
  testWidgets(
    'locale changes translate relationship text and an existing error',
    (tester) async {
      final remote = PageRemote()..invitation = true;
      final service = CouplesService(remote)..setAccount(1);
      final locale = LocaleProvider(
        defaultLocale: 'en',
        translationResolver: (code) => generatedLocaleCatalog[code]!,
      );
      await service.refresh();
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: service),
            ChangeNotifierProvider.value(value: locale),
          ],
          child: const MaterialApp(home: CouplesPage(friends: [])),
        ),
      );
      expect(find.text('Couple days'), findsOneWidget);
      expect(find.textContaining('Day '), findsOneWidget);
      await tester.ensureVisible(find.text('Decline'));
      await tester.tap(find.text('Decline'));
      await tester.pumpAndSettle();
      expect(find.text(locale.translation['couples.failed']!), findsOneWidget);
      locale.setLocale('ja');
      await tester.pumpAndSettle();
      expect(find.text('交際日数'), findsOneWidget);
      expect(find.text(locale.translation['couples.failed']!), findsOneWidget);
      expect(find.textContaining('交際 '), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      service.dispose();
      locale.dispose();
    },
  );
  testWidgets(
    'confirmed end clears the count after the server overview updates',
    (tester) async {
      final remote = PageRemote()..succeed = true;
      final service = CouplesService(remote)..setAccount(1);
      await service.refresh();
      await tester.pumpWidget(
        ChangeNotifierProvider.value(
          value: service,
          child: const MaterialApp(home: CouplesPage(friends: [])),
        ),
      );
      await tester.tap(find.text('解除情侶'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('確認'));
      await tester.pumpAndSettle();
      expect(find.textContaining('交往第'), findsNothing);
      expect(service.snapshot?.relationship, isNull);
      expect(remote.writes.single['path'], '/api/couples/r/end');
      await tester.pumpWidget(const SizedBox());
      service.dispose();
    },
  );
  testWidgets(
    'date acceptance uses the device zone and leaves old date after failure',
    (tester) async {
      const channel = MethodChannel('taiwan_brawl/device_time_zone');
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(
        channel,
        (_) async => 'America/New_York',
      );
      addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
      final remote = PageRemote()..proposalActor = 2;
      final service = CouplesService(remote)..setAccount(1);
      await service.refresh();
      await tester.pumpWidget(
        ChangeNotifierProvider.value(
          value: service,
          child: const MaterialApp(home: CouplesPage(friends: [])),
        ),
      );
      await tester.ensureVisible(find.text('同意日期'));
      await tester.tap(find.text('同意日期'));
      await tester.pumpAndSettle();
      expect(remote.writes.single['timeZone'], 'America/New_York');
      expect(
        remote.writes.single['path'],
        '/api/couples/date-proposals/proposal-id/accept',
      );
      expect(service.snapshot?.relationship?.startedOn, '2026-11-01');
      expect(find.textContaining('操作未完成'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      service.dispose();
    },
  );
  testWidgets(
    'accept reads device timezone and retries with the same operation ID',
    (tester) async {
      const channel = MethodChannel('taiwan_brawl/device_time_zone');
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(channel, (_) async => 'Asia/Taipei');
      addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
      final remote = PageRemote()..invitation = true;
      final service = CouplesService(remote)..setAccount(1);
      await service.refresh();
      await tester.pumpWidget(
        ChangeNotifierProvider.value(
          value: service,
          child: const MaterialApp(home: CouplesPage(friends: [])),
        ),
      );
      for (var i = 0; i < 2; i++) {
        await tester.ensureVisible(find.text('接受'));
        await tester.tap(find.text('接受'));
        await tester.pumpAndSettle();
      }
      expect(remote.writes, hasLength(2));
      expect(remote.writes.first['timeZone'], 'Asia/Taipei');
      expect(
        remote.writes.first['operationId'],
        remote.writes.last['operationId'],
      );
      expect(remote.writes.first['accountId'], 1);
      expect(
        remote.writes.first['path'],
        '/api/couples/requests/request-id/accept',
      );
      await tester.pumpWidget(const SizedBox());
      service.dispose();
    },
  );
  test(
    'timezone reads again after device setting changes and fails closed',
    () async {
      const channel = MethodChannel('taiwan_brawl/device_time_zone');
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      var zone = 'Asia/Taipei';
      messenger.setMockMethodCallHandler(channel, (_) async => zone);
      addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
      expect(await deviceTimeZone(), 'Asia/Taipei');
      zone = 'America/New_York';
      expect(await deviceTimeZone(), 'America/New_York');
      zone = '';
      await expectLater(deviceTimeZone(), throwsStateError);
    },
  );
  test(
    'friend removal cannot retain old couple after failed refresh',
    () async {
      final remote = PageRemote();
      final service = CouplesService(remote)..setAccount(1);
      await service.refresh();
      remote.offline = true;
      await service.invalidateAfterFriendChange(1);
      expect(service.snapshot, isNull);
      service.dispose();
    },
  );
  testWidgets(
    'friend block warns about ending couples and cancel performs no write',
    (tester) async {
      final service = CouplesService(PageRemote())..setAccount(1);
      await service.refresh();
      await tester.pumpWidget(
        ChangeNotifierProvider.value(
          value: service,
          child: const MaterialApp(
            home: FriendDetailPage(
              accountId: 1,
              friend: SocialUser(
                userId: 2,
                name: 'Partner',
                bio: '',
                avatarUrl: null,
                lastActiveAt: null,
                isOnline: false,
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('封鎖好友'));
      await tester.pumpAndSettle();
      expect(find.textContaining('同時解除情侶'), findsOneWidget);
      await tester.tap(find.text('取消'));
      await tester.pumpAndSettle();
      expect(service.snapshot?.relationship, isNotNull);
      service.setAccount(3);
      await tester.pumpAndSettle();
      expect(find.text('Partner'), findsNothing);
      expect(find.textContaining('帳號已變更'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      service.dispose();
    },
  );
  testWidgets(
    'large text renders confirmed relationship and cancellation does not write',
    (tester) async {
      final service = CouplesService(PageRemote())..setAccount(1);
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
            home: const CouplesPage(friends: []),
          ),
        ),
      );
      expect(find.textContaining('交往第'), findsOneWidget);
      await tester.ensureVisible(find.text('解除情侶'));
      await tester.tap(find.text('解除情侶'));
      await tester.pumpAndSettle();
      expect(find.textContaining('不需要對方同意'), findsOneWidget);
      await tester.tap(find.text('取消'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      service.dispose();
    },
  );
  testWidgets('offline confirmed data remains visible with writes disabled', (
    tester,
  ) async {
    final remote = PageRemote();
    final service = CouplesService(remote)..setAccount(1);
    await service.refresh();
    remote.offline = true;
    try {
      await service.refresh();
    } catch (_) {}
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: service,
        child: const MaterialApp(home: CouplesPage(friends: [])),
      ),
    );
    expect(find.textContaining('上次同步'), findsOneWidget);
    expect(
      tester
          .widget<TextButton>(find.widgetWithText(TextButton, '解除情侶'))
          .onPressed,
      isNull,
    );
    expect(find.textContaining('交往第'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    service.dispose();
  });
}
