import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:taiwan_speed_camera/taiwan_speed_camera.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final fixturePath = Platform.environment['SPEED_CAMERA_CONTRACT_FIXTURE'];
  test(
    'Flutter consumes the version-qualified Worker API without authentication',
    () async {
      final fixture =
          jsonDecode(await File(fixturePath!).readAsString())
              as Map<String, dynamic>;
      final manifest = fixture['manifest'] as Map<String, dynamic>;
      final requests = <http.Request>[];
      final repository = SpeedCameraRepository(
        baseUrl: 'https://example.test',
        client: MockClient((request) async {
          requests.add(request);
          expect(request.headers.containsKey('Authorization'), isFalse);
          final payload = request.url.path.endsWith('/manifest')
              ? manifest
              : fixture['snapshot'];
          return http.Response.bytes(utf8.encode(jsonEncode(payload)), 200);
        }),
      );
      addTearDown(repository.dispose);
      // Host dependencies deliberately do not import the preference plugin
      // directly; install mock platform channels used by the camera module.
      final store = <String, Object>{};
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            const MethodChannel('plugins.flutter.io/shared_preferences'),
            (call) async => switch (call.method) {
              'getAll' => store,
              'setString' => true,
              _ => throw UnsupportedError(call.method),
            },
          );
      final catalog = await repository.refresh();
      expect(catalog.version, manifest['version']);
      expect(catalog.points.length, manifest['recordCount']);
      expect(catalog.points.first.address, contains('測試路'));
      expect(requests, hasLength(2));
      expect(requests.last.url.queryParameters['version'], catalog.version);
    },
    skip: fixturePath == null
        ? 'Run with the backend fixture from the cross-repo CI job.'
        : false,
  );
}
