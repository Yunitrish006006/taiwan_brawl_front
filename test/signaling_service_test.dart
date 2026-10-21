import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:taiwan_brawl/services/api_client.dart';
import 'package:taiwan_brawl/services/signaling_service.dart';
import 'package:taiwan_brawl_messaging/taiwan_brawl_messaging.dart';

void main() {
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
