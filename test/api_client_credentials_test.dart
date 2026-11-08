import 'dart:convert';
import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:taiwan_brawl/config/app_configuration.dart';
import 'package:taiwan_brawl/services/api_client.dart';
import 'package:taiwan_brawl/services/remote_source_exception.dart';
import 'package:taiwan_brawl_messaging/taiwan_brawl_messaging.dart';

void main() {
  test(
    'uncached read-only client cannot erase a new login after delayed 401',
    () async {
      final credentials = _MemoryCredentials()
        ..values['taiwan_brawl.session_id'] = 'old-session';
      final oldResponse = Completer<http.Response>();
      final sent = Completer<void>();
      final seen = <String?>[];
      final client = ApiClient(
        credentials: credentials,
        cacheSession: false,
        clearSessionOnUnauthorized: false,
        client: MockClient((request) {
          seen.add(request.headers['authorization']);
          if (seen.length == 1) {
            sent.complete();
            return oldResponse.future;
          }
          return Future.value(http.Response('{"ok":true}', 200));
        }),
      );
      final old = client.getJson('/api/couples/overview');
      await sent.future;
      credentials.values['taiwan_brawl.session_id'] = 'new-session';
      await client.getJson('/api/couples/overview');
      oldResponse.complete(http.Response('{"error":"unauthorized"}', 401));
      await expectLater(old, throwsA(isA<ApiException>()));
      expect(seen, ['Bearer old-session', 'Bearer new-session']);
      expect(credentials.values['taiwan_brawl.session_id'], 'new-session');
    },
  );
  test('ApiException implements the provider-neutral remote failure port', () {
    final error = ApiException(
      'unsupported event route',
      statusCode: 404,
      responseBody: const {'error': 'not found'},
    );

    expect(error, isA<RemoteSourceException>());
    expect(error.message, 'unsupported event route');
    expect(error.statusCode, 404);
    expect(error.responseBody, {'error': 'not found'});
  });

  test(
    'persists mobile session tokens through the shared credential port',
    () async {
      final credentials = _MemoryCredentials();
      final requests = <http.BaseRequest>[];
      final client = MockClient((request) async {
        requests.add(request);
        return http.Response(
          jsonEncode({'session_id': 'session-from-response', 'ok': true}),
          200,
        );
      });
      final api = ApiClient(client: client, credentials: credentials);

      await api.getJson('/api/me');
      expect(
        credentials.values['taiwan_brawl.session_id'],
        'session-from-response',
      );

      ApiClient.clearMobileSession();
      final second = ApiClient(client: client, credentials: credentials);
      await second.getJson('/api/me');

      expect(
        requests[1].headers['authorization'],
        'Bearer session-from-response',
      );
    },
  );

  test('clearSession removes both cache and durable credential', () async {
    final credentials = _MemoryCredentials()
      ..values['taiwan_brawl.session_id'] = 'session';
    final api = ApiClient(credentials: credentials);

    await api.clearSession();

    expect(credentials.values, isNot(contains('taiwan_brawl.session_id')));
  });

  test(
    'does not share an in-memory session between ApiClient instances',
    () async {
      final firstCredentials = _MemoryCredentials();
      final secondCredentials = _MemoryCredentials();
      final requests = <http.BaseRequest>[];
      final client = MockClient((request) async {
        requests.add(request);
        if (requests.length == 1) {
          return http.Response(
            jsonEncode({'session_id': 'first-session'}),
            200,
          );
        }
        return http.Response(jsonEncode({'ok': true}), 200);
      });

      final first = ApiClient(client: client, credentials: firstCredentials);
      await first.getJson('/api/me');

      final second = ApiClient(client: client, credentials: secondCredentials);
      await second.getJson('/api/me');

      expect(requests[0].headers['authorization'], isNull);
      expect(requests[1].headers['authorization'], isNull);
    },
  );

  test(
    'uses an injected application configuration for API endpoints',
    () async {
      Uri? requestedUri;
      final api = ApiClient(
        configuration: const AppConfiguration(
          apiBaseUrl: 'https://local.example.test',
          googleWebClientId: 'web-client',
          googleServerClientId: 'server-client',
          p2pChatEnabled: true,
        ),
        client: MockClient((request) async {
          requestedUri = request.url;
          return http.Response('{}', 200);
        }),
        credentials: _MemoryCredentials(),
      );

      await api.getJson('/api/me');

      expect(requestedUri, Uri.parse('https://local.example.test/api/me'));
      expect(api.configuration.p2pChatEnabled, isTrue);
    },
  );
}

class _MemoryCredentials implements CredentialStore {
  final values = <String, String>{};

  @override
  Future<String?> read(String key) async => values[key];

  @override
  Future<void> write(String key, String value) async => values[key] = value;

  @override
  Future<void> delete(String key) async => values.remove(key);
}
