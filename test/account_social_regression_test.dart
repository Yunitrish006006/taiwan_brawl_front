import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:taiwan_brawl/services/api_client.dart';
import 'package:taiwan_brawl/services/auth_service.dart';
import 'package:taiwan_brawl/services/chat_service.dart';
import 'package:taiwan_brawl/services/friends_service.dart';
import 'package:taiwan_brawl/services/notification_service.dart';
import 'package:taiwan_brawl/services/royale_service.dart';
import 'package:taiwan_brawl/services/taiwan_brawl_profile_service.dart';
import 'package:user_account_core/user_account_core.dart';
import 'package:user_social_system/user_social_system.dart';

const _signedInUser = {
  'id': 1,
  'name': 'QA Player',
  'email': 'qa@example.test',
};
const _testToken = 'fixture-google-token';
const _testSession = 'fixture-session';
const _timeout = Duration(seconds: 5);

http.Response _json(Map<String, Object?> payload, [int status = 200]) =>
    http.Response(
      jsonEncode(payload),
      status,
      headers: {'content-type': 'application/json; charset=utf-8'},
    );

Map<String, dynamic> _body(http.Request request) =>
    jsonDecode(request.body) as Map<String, dynamic>;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    ApiClient.clearMobileSession();
    final directory = await Directory.systemTemp.createTemp('twb-regression-');
    Hive.init(directory.path);
    addTearDown(() async {
      ApiClient.clearMobileSession();
      await Hive.close();
      await directory.delete(recursive: true);
    });
  });

  test(
    'Google sessions preserve profile, friend requests and Royale room actions',
    () async {
      const guest = {
        'id': 2,
        'name': 'QA friend',
        'email': 'friend@example.test',
      };
      const guestToken = 'fixture-guest-token';
      const guestSession = 'fixture-guest-session';
      var owner = _signedInUser;
      int? accountId;
      var requested = false;
      var accepted = false;
      var joined = false;
      final client = MockClient((request) async {
        final path = request.url.path;
        final authorization = request.headers['authorization'];
        if (path == '/api/google-login') {
          expect(request.method, 'POST');
          expect(authorization, isNull);
          final token = _body(request)['id_token'];
          expect(token, anyOf(_testToken, guestToken));
          accountId = token == _testToken ? 1 : 2;
          return _json({
            'session_id': accountId == 1 ? _testSession : guestSession,
            'user': accountId == 1 ? owner : guest,
          });
        }
        if (accountId == null) {
          expect(authorization, isNull);
          return _json({'error': 'unauthorized'}, 401);
        }
        expect(
          authorization,
          'Bearer ${accountId == 1 ? _testSession : guestSession}',
        );
        switch ((request.method, path)) {
          case ('GET', '/api/me'):
            return _json({'user': accountId == 1 ? owner : guest});
          case ('PUT', '/api/users/me'):
            expect(accountId, 1);
            owner = {...owner, 'name': _body(request)['name'] as String};
            return _json({});
          case ('GET', '/api/friends/search'):
            expect(request.url.queryParameters['query'], 'QA friend');
            return _json({
              'results': [
                {
                  'user': {'userId': 2, 'name': 'QA friend'},
                },
              ],
            });
          case ('POST', '/api/friends/requests'):
            expect(accountId, 1);
            expect(_body(request), {'targetUserId': 2});
            requested = true;
            return _json({});
          case ('POST', '/api/friends/requests/41/accept'):
            expect(accountId, 2);
            expect(requested, isTrue);
            accepted = true;
            return _json({});
          case ('GET', '/api/friends/overview'):
            return _json({
              'friends': [
                if (accepted) {'userId': 1, 'name': owner['name']},
              ],
            });
          case ('POST', '/api/rooms'):
            expect(accountId, 1);
            expect(_body(request)['deckId'], 7);
            return _json({
              'room': {'code': 'QA01', 'status': 'waiting'},
            });
          case ('POST', '/api/rooms/QA01/join'):
            expect(accountId, 2);
            expect(_body(request)['deckId'], 8);
            joined = true;
            return _json({
              'room': {'code': 'QA01', 'status': 'waiting'},
            });
          case ('POST', '/api/rooms/QA01/ready'):
            expect(joined, isTrue);
            return _json({
              'room': {'code': 'QA01', 'status': 'playing'},
            });
          case ('POST', '/api/logout'):
            accountId = null;
            return _json({});
          default:
            fail('Unexpected request: ${request.method} $path');
        }
      });
      final api = ApiClient(client: client);
      final auth = AuthService(api);
      final profile = TaiwanBrawlProfileService(auth);
      final FriendsDirectory friends = FriendsService(api);
      final royale = RoyaleService(api);
      addTearDown(client.close);
      addTearDown(auth.dispose);
      addTearDown(profile.dispose);

      await auth.init();
      expect(auth.isLoggedIn, isFalse);
      await auth.verifyGoogleToken(_testToken);
      expect(profile.profile?.name, 'QA Player');
      await (profile as ProfileService).updateProfile(
        name: 'Updated QA Player',
        bio: '',
        avatarSource: 'google',
        customAvatarUrl: '',
      );
      expect(profile.profile?.name, 'Updated QA Player');
      final target = (await friends.searchByName(
        'QA friend',
      )).single.user.userId;
      await friends.sendFriendRequest(target);
      final room = await royale.createRoom(deckId: 7);
      await auth.logout();
      expect(profile.profile, isNull);
      await auth.verifyGoogleToken(guestToken);
      expect(profile.profile?.id, target);
      await friends.acceptFriendRequest(41);
      expect((await friends.fetchOverview()).friends.single.userId, 1);
      await royale.joinRoom(roomCode: room.code, deckId: 8);
      expect((await royale.readyRoom(room.code)).status, 'playing');
      await auth.logout();
      expect(profile.profile, isNull);
      await auth.refreshMe();
      expect(auth.isLoggedIn, isFalse);
    },
  );

  test(
    'DM receives, acknowledges, sends and persists extracted message types',
    () async {
      const timestamp = '2026-11-19T13:00:00.000Z';
      final client = MockClient((request) async {
        switch ((request.method, request.url.path)) {
          case ('GET', '/api/chat/dm/pending'):
            return _json({
              'messages': [
                {
                  'id': 21,
                  'sender_id': 2,
                  'receiver_id': 1,
                  'text': '收到訊息',
                  'created_at': timestamp,
                },
              ],
            });
          case ('POST', '/api/chat/dm/ack'):
            expect(_body(request), {
              'ids': [21],
            });
            return _json({});
          case ('POST', '/api/chat/dm/2/send'):
            expect(_body(request), {'text': '測試回覆'});
            return _json({'createdAt': '2026-11-19T13:01:00.000Z'});
          default:
            fail('Unexpected request: ${request.method} ${request.url.path}');
        }
      });
      final chat = ChatService(ApiClient(client: client));
      final DmService dm = chat;
      addTearDown(client.close);
      addTearDown(chat.dispose);
      final messages = dm.messageStream.take(3).toList();
      await dm.connectToDm(1, 2);
      await dm.sendMessage(2, '測試回覆');
      final events = await messages.timeout(_timeout);
      expect(events.map((m) => m.text), ['收到訊息', '測試回覆', '測試回覆']);
      expect(events.map((m) => m.isPending), [false, true, false]);
      dm.disconnect();
      final history = await dm.fetchHistory(1, 2);
      expect(history.map((m) => m.text), ['收到訊息', '測試回覆']);
    },
  );

  test(
    'notification registration and push-tap routing survive a fresh login',
    () async {
      setupFirebaseCoreMocks();
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      const messaging = MethodChannel('plugins.flutter.io/firebase_messaging');
      messenger.setMockMethodCallHandler(messaging, (call) async {
        switch (call.method) {
          case 'Messaging#setAutoInitEnabled':
            return {'isAutoInitEnabled': true};
          case 'Messaging#getInitialMessage':
            return {
              'data': {'sender_id': '2'},
            };
          case 'Messaging#requestPermission':
            return {'authorizationStatus': 1};
          case 'Messaging#getToken':
            return {'token': 'fixture-fcm-token'};
          default:
            fail('Unexpected platform method: ${call.method}');
        }
      });
      addTearDown(() => messenger.setMockMethodCallHandler(messaging, null));
      final registered = Completer<void>();
      final ack = Completer<void>();
      final client = MockClient((request) async {
        switch ((request.method, request.url.path)) {
          case ('POST', '/api/google-login'):
            return _json({'session_id': _testSession, 'user': _signedInUser});
          case ('GET', '/api/notifications/config'):
            return _json({
              'config': {
                'enabledPlatforms': ['android'],
                'deliveryEnabled': true,
                'fcm': {
                  'enabled': true,
                  'projectId': '123',
                  'apiKey': '123',
                  'appId': '123',
                  'messagingSenderId': '123',
                },
              },
            });
          case ('POST', '/api/notifications/register'):
            expect(request.headers['authorization'], 'Bearer $_testSession');
            expect(_body(request), containsPair('provider', 'fcm'));
            expect(_body(request), containsPair('token', 'fixture-fcm-token'));
            expect(_body(request), containsPair('platform', 'android'));
            expect(_body(request)['installationId'], isNotEmpty);
            registered.complete();
            return _json({});
          case ('GET', '/api/chat/dm/pending'):
            return _json({
              'messages': [
                if (!ack.isCompleted)
                  {
                    'id': 51,
                    'sender_id': 3,
                    'receiver_id': 1,
                    'text': 'Other conversation',
                    'created_at': '2026-11-19T13:00:00.000Z',
                  },
              ],
            });
          case ('POST', '/api/chat/dm/ack'):
            expect(_body(request), {
              'ids': [51],
            });
            ack.complete();
            return _json({});
          default:
            fail('Unexpected request: ${request.method} ${request.url.path}');
        }
      });
      final api = ApiClient(client: client);
      final auth = AuthService(api);
      final notifications = NotificationService(api);
      addTearDown(client.close);
      addTearDown(auth.dispose);
      addTearDown(notifications.dispose);

      await auth.verifyGoogleToken(_testToken);
      notifications.syncAuth(auth);
      await registered.future.timeout(_timeout);
      await ack.future.timeout(_timeout);
      await Future<void>.delayed(Duration.zero);
      expect(notifications.pendingConversationUserId, 2);

      Future<void> tapPush(int senderId) async {
        await messenger.handlePlatformMessage(
          messaging.name,
          const StandardMethodCodec().encodeMethodCall(
            MethodCall('Messaging#onMessageOpenedApp', {
              'data': {'conversation_user_id': '$senderId'},
            }),
          ),
          null,
        );
        await Future<void>.delayed(Duration.zero);
      }

      notifications.setActiveConversation(2);
      expect(notifications.pendingConversationUserId, isNull);
      await tapPush(2);
      expect(notifications.pendingConversationUserId, isNull);
      await tapPush(3);
      expect(notifications.pendingConversationUserId, 3);
    },
  );
}
