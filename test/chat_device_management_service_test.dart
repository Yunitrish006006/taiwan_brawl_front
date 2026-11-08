import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:taiwan_brawl/services/api_client.dart';
import 'package:taiwan_brawl/services/chat_device_management_service.dart';
import 'package:taiwan_brawl_messaging/taiwan_brawl_messaging.dart';

void main() {
  test(
    'registers, lists and revokes chat devices through owned API routes',
    () async {
      final requests = <http.Request>[];
      final client = MockClient((request) async {
        requests.add(request);
        if (request.method == 'GET') {
          return http.Response(
            jsonEncode({
              'devices': [
                {
                  'device_id': 'device-phone',
                  'created_at': '2026-10-28T00:00:00.000Z',
                  'last_seen_at': '2026-10-28T01:00:00.000Z',
                },
              ],
            }),
            200,
          );
        }
        return http.Response('{}', 200);
      });
      final service = ServerChatDeviceManagementService(
        ApiClient(client: client, credentials: _MemoryCredentials()),
      );

      await service.registerCurrentDevice('device-phone');
      final devices = await service.loadActiveDevices();
      await service.revokeDevice('device-tablet');

      expect(
        requests.map((request) => '${request.method} ${request.url.path}'),
        [
          'POST /api/chat/dm/device-register',
          'GET /api/chat/dm/devices',
          'POST /api/chat/dm/device-revoke',
        ],
      );
      expect(jsonDecode(requests[0].body), {'deviceId': 'device-phone'});
      expect(jsonDecode(requests[2].body), {'deviceId': 'device-tablet'});
      expect(devices, hasLength(1));
      expect(devices.single.deviceId, 'device-phone');
      expect(devices.single.createdAt, DateTime.utc(2026, 10, 28));
      expect(devices.single.lastSeenAt, DateTime.utc(2026, 10, 28, 1));
    },
  );

  test('rejects malformed device list entries', () {
    expect(
      () => ChatDeviceInfo.fromJson({'created_at': '2026-10-28'}),
      throwsFormatException,
    );
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
