import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:taiwan_brawl/services/auth_remote_source.dart';
import 'package:taiwan_brawl/services/auth_service.dart';
import 'package:taiwan_brawl/services/couples_remote_source.dart';
import 'package:taiwan_brawl/services/couples_service.dart';
import 'package:taiwan_brawl/services/remote_source_exception.dart';
import 'package:taiwan_brawl/pages/social/couple_widget_gate_page.dart';
import 'package:taiwan_brawl/widgets/couple_widget_open_listener.dart';

class NavigationAuth implements AuthRemoteSource {
  int account = 1;
  Object? error;
  @override
  Future<Map<String, dynamic>> loadCurrentUser() async {
    if (error != null) throw error!;
    return {
      'user': {
        'id': account,
        'name': 'Current',
        'email': 'current@example.test',
      },
    };
  }

  @override
  Future<Map<String, dynamic>> verifyGoogleToken(String token) =>
      loadCurrentUser();
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class NavigationCouples implements CouplesRemoteSource {
  final accounts = <int>[];
  @override
  Future<Map<String, dynamic>> overview({required int accountId}) async {
    accounts.add(accountId);
    return {
      'ok': true,
      'serverNow': '2026-11-05T00:00:00Z',
      'data': {
        'relationship': accountId == 1
            ? {
                'id': 'old',
                'partnerUserId': 3,
                'startedOn': '2026-11-01',
                'status': 'active',
                'version': 1,
                'updatedAt': '2026-11-05T00:00:00Z',
              }
            : null,
        'incomingRequests': [],
        'outgoingRequests': [],
        'dateProposal': null,
      },
    };
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  testWidgets(
    'widget click cannot expose cached days when identity verification is offline',
    (tester) async {
      final source = NavigationAuth();
      final auth = AuthService(remoteSource: source);
      final remote = NavigationCouples();
      final couples = CouplesService(remote)..setAccount(1);
      await couples.refresh();
      source.error = const RemoteSourceException('offline');
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: auth),
            ChangeNotifierProvider.value(value: couples),
          ],
          child: const MaterialApp(home: CoupleWidgetGatePage()),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('無法確認目前關係'), findsOneWidget);
      expect(find.textContaining('交往第'), findsNothing);
      expect(remote.accounts, [1]);
      await tester.pumpWidget(const SizedBox());
      couples.dispose();
      auth.dispose();
    },
  );
  testWidgets(
    'widget opens only the newly verified account and current relationship',
    (tester) async {
      final source = NavigationAuth()..account = 2;
      final auth = AuthService(remoteSource: source);
      final remote = NavigationCouples();
      final couples = CouplesService(remote)..setAccount(1);
      await couples.refresh();
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: auth),
            ChangeNotifierProvider.value(value: couples),
          ],
          child: const MaterialApp(home: CoupleWidgetGatePage()),
        ),
      );
      await tester.pumpAndSettle();
      expect(remote.accounts, [1, 2]);
      expect(find.textContaining('交往第'), findsNothing);
      expect(find.textContaining('從好友中邀請情侶'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      couples.dispose();
      auth.dispose();
    },
  );
  testWidgets(
    'native open waits for bootstrap and resumes after login exactly once',
    (tester) async {
      const channel = MethodChannel('taiwan_brawl/couple_widget_open');
      var requested = true;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (_) async {
            final result = requested;
            requested = false;
            return result;
          });
      addTearDown(
        () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, null),
      );
      final source = NavigationAuth()
        ..error = const RemoteSourceException('expired', statusCode: 401);
      final auth = AuthService(remoteSource: source);
      final key = GlobalKey<NavigatorState>();
      var opens = 0;
      await tester.pumpWidget(
        ChangeNotifierProvider.value(
          value: auth,
          child: MaterialApp(
            navigatorKey: key,
            builder: (_, child) =>
                CoupleWidgetOpenListener(navigatorKey: key, child: child!),
            home: const Scaffold(body: Text('Boot')),
            routes: {
              '/login': (_) => const Scaffold(body: Text('Login required')),
              '/couple-widget': (_) {
                opens++;
                return const Scaffold(body: Text('Verified route'));
              },
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Boot'), findsOneWidget);
      expect(opens, 0);
      await auth.init();
      await tester.pumpAndSettle();
      expect(find.text('Login required'), findsOneWidget);
      expect(opens, 0);
      source.error = null;
      await auth.verifyGoogleToken('test');
      await tester.pumpAndSettle();
      expect(find.text('Verified route'), findsOneWidget);
      expect(opens, 1);
      await auth.refreshMe();
      await tester.pumpAndSettle();
      expect(opens, 1);
      await tester.pumpWidget(const SizedBox());
      auth.dispose();
    },
  );
}
