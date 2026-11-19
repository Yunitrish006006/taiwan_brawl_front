import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:taiwan_speed_camera/taiwan_speed_camera.dart';

void main() {
  final validSnapshot = <String, dynamic>{
    'schemaVersion': 1,
    'source': 'NPA-7320',
    'sourceUrl': 'https://data.gov.tw/dataset/7320',
    'generatedAt': '2026-11-19T00:00:00.000Z',
    'contentSha256': 'snapshot-version-1',
    'recordCount': 1,
    'points': [
      {
        'id': 'npa7320:sample',
        'latitude': 25.025,
        'longitude': 121.535,
        'address': '測試路',
        'directionRaw': '往東',
        'speedLimitKmh': 60,
      }
    ],
  };

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('downloads validated snapshot then loads it offline when network fails', () async {
    final online = SpeedCameraRepository(
      baseUrl: 'https://example.com',
      client: MockClient((request) async {
        if (request.url.path.endsWith('/manifest')) {
          return http.Response(jsonEncode({
            'version': 'snapshot-version-1', 'recordCount': 1,
          }), 200);
        }
        return http.Response(jsonEncode(validSnapshot), 200);
      }),
    );
    expect((await online.refresh()).points.length, 1);
    online.dispose();

    final offline = SpeedCameraRepository(
      baseUrl: 'https://example.com',
      client: MockClient((request) async => http.Response('offline', 503)),
    );
    final recovered = await offline.load();
    expect(recovered.version, 'snapshot-version-1');
    expect(recovered.points.single.address, '測試路');
    offline.dispose();
  });

  test('rejects mismatched data version without poisoning cached snapshot', () async {
    final initial = SpeedCameraRepository(
      baseUrl: 'https://example.com',
      client: MockClient((request) async {
        if (request.url.path.endsWith('/manifest')) {
          return http.Response(jsonEncode({
            'version': 'snapshot-version-1', 'recordCount': 1,
          }), 200);
        }
        return http.Response(jsonEncode(validSnapshot), 200);
      }),
    );
    await initial.refresh();
    initial.dispose();

    final invalid = SpeedCameraRepository(
      baseUrl: 'https://example.com',
      client: MockClient((request) async {
        if (request.url.path.endsWith('/manifest')) {
          return http.Response(jsonEncode({
            'version': 'snapshot-version-2', 'recordCount': 1,
          }), 200);
        }
        return http.Response(jsonEncode(validSnapshot), 200);
      }),
    );
    await expectLater(invalid.refresh(), throwsFormatException);
    expect((await invalid.readCached())?.version, 'snapshot-version-1');
    invalid.dispose();
  });
}
