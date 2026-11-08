@TestOn('vm')
library;

import 'dart:async';
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:taiwan_brawl/services/api_client.dart';
import 'package:taiwan_brawl/services/auth_remote_source.dart';
import 'package:taiwan_brawl/services/auth_service.dart';
import 'package:taiwan_brawl_messaging/taiwan_brawl_messaging.dart';

class SessionCredentials implements CredentialStore {
  String? token = 'old';
  @override
  Future<String?> read(String key) async => token;
  @override
  Future<void> write(String key, String value) async {
    token = value;
  }

  @override
  Future<void> delete(String key) async {
    token = null;
  }
}

void main() {
  for (final status in [200, 401]) {
    test(
      'late logout $status cannot erase the following login or its identity refresh',
      () async {
        final credentials = SessionCredentials();
        final response = Completer<http.Response>(), sent = Completer<void>();
        final paths = <String>[];
        final api = ApiClient(
          credentials: credentials,
          client: MockClient((request) async {
            paths.add(request.url.path);
            if (request.url.path == '/api/logout') {
              sent.complete();
              return response.future;
            }
            final user = {'id': 2, 'name': 'New', 'email': 'new@example.test'};
            if (request.url.path == '/api/google-login') {
              return http.Response(
                jsonEncode({'session_id': 'new', 'user': user}),
                200,
              );
            }
            expect(request.headers['Authorization'], 'Bearer new');
            return http.Response(jsonEncode({'user': user}), 200);
          }),
        );
        final auth = AuthService(remoteSource: ServerAuthRemoteSource(api));
        final logout = auth.logout();
        await sent.future;
        final login = auth.verifyGoogleToken('synthetic-token');
        final refresh = auth.refreshMe();
        await Future<void>.delayed(Duration.zero);
        expect(paths, ['/api/logout']);
        expect(auth.identityState, AuthIdentityState.signedOut);
        response.complete(
          http.Response(
            status == 200 ? '{"ok":true}' : '{"error":"expired"}',
            status,
          ),
        );
        await Future.wait([logout, login, refresh]);
        expect(paths, ['/api/logout', '/api/google-login', '/api/me']);
        expect(auth.user?.id, 2);
        expect(auth.identityState, AuthIdentityState.authenticated);
        expect(credentials.token, 'new');
        auth.dispose();
      },
    );
  }
}
