import 'dart:convert';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:taiwan_brawl/services/api_client.dart';
import 'package:taiwan_brawl/config/app_configuration.dart';
import 'package:taiwan_brawl/services/signaling_service.dart';
import 'package:taiwan_brawl_messaging/taiwan_brawl_messaging.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

void main() {
  test(
    'hosted signaling builds the peer URL and carries native session auth',
    () async {
      final credentials = _MemoryCredentials()
        ..values['taiwan_brawl.session_id'] = 'session-secret';
      final channel = _RecordingChannel();
      Uri? connectedUri;
      Map<String, dynamic>? connectedHeaders;
      final api = ApiClient(
        client: MockClient((_) async => http.Response('{}', 200)),
        credentials: credentials,
        configuration: const AppConfiguration(
          apiBaseUrl: 'https://chat.example.test/api',
          googleWebClientId: 'web-client',
          googleServerClientId: 'server-client',
          p2pChatEnabled: true,
        ),
      );
      final signaling = SignalingService(
        api,
        channelFactory: (uri, {headers}) {
          connectedUri = uri;
          connectedHeaders = headers;
          return channel;
        },
      );

      await signaling.connect(42);

      expect(connectedUri?.scheme, 'wss');
      expect(connectedUri?.host, 'chat.example.test');
      expect(connectedUri?.path, '/api/chat/signal/42');
      if (kIsWeb) {
        expect(connectedHeaders, isNull);
      } else {
        expect(connectedHeaders, {'Authorization': 'Bearer session-secret'});
      }
      signaling.dispose();
    },
  );

  test('clears connection state when the channel factory fails', () async {
    final api = ApiClient(
      client: MockClient((_) async => http.Response('{}', 200)),
      credentials: _MemoryCredentials(),
    );
    final signaling = SignalingService(
      api,
      channelFactory: (uri, {headers}) {
        throw StateError('websocket unavailable');
      },
    );

    await expectLater(signaling.connect(2), throwsStateError);
    expect(signaling.isConnected, isFalse);
    signaling.dispose();
  });

  test(
    'server signaling emits only the existing SDP and ICE wire shapes',
    () async {
      final api = ApiClient(
        client: MockClient((_) async => http.Response('{}', 200)),
        credentials: _MemoryCredentials(),
      );
      final channel = _RecordingChannel();
      final signaling = SignalingService(
        api,
        channelFactory: (_, {headers}) => channel,
      );
      await signaling.connect(2);

      signaling.send(2, {'type': 'offer', 'sdp': 'offer-sdp'});
      signaling.send(2, {
        'type': 'ice_candidate',
        'candidate': {
          'candidate': 'candidate-1',
          'sdpMid': '0',
          'sdpMLineIndex': 0,
        },
      });

      expect(
        channel.recordingSink.values.map(
          (value) => jsonDecode(value as String),
        ),
        [
          {'type': 'offer', 'sdp': 'offer-sdp', 'targetUserId': 2},
          {
            'type': 'ice_candidate',
            'candidate': {
              'candidate': 'candidate-1',
              'sdpMid': '0',
              'sdpMLineIndex': 0,
            },
            'targetUserId': 2,
          },
        ],
      );
      signaling.dispose();
    },
  );
}

class _RecordingChannel implements WebSocketChannel {
  final recordingSink = _RecordingSink();

  @override
  Stream<dynamic> get stream => const Stream.empty();

  @override
  WebSocketSink get sink => recordingSink;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _RecordingSink implements WebSocketSink {
  final values = <dynamic>[];

  @override
  void add(dynamic event) {
    values.add(event);
  }

  @override
  Future<void> close([int? closeCode, String? closeReason]) async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
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
