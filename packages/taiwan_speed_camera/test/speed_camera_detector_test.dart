import 'package:flutter_test/flutter_test.dart';
import 'package:taiwan_speed_camera/taiwan_speed_camera.dart';

void main() {
  const camera = SpeedCameraPoint(
    id: 'npa7320:sample', latitude: 25.025, longitude: 121.535,
    address: '測試路一段', directionRaw: '往東', speedLimitKmh: 60,
  );

  test('filters ahead by heading, location accuracy and distance', () {
    final east = SpeedCameraDetector.findAhead(
      [camera], latitude: 25.025, longitude: 121.532,
      accuracyMeters: 8, headingDegrees: 90,
    );
    expect(east.length, 1);
    expect(east.first.distanceMeters, greaterThan(200));
    expect(SpeedCameraDetector.findAhead(
      [camera], latitude: 25.025, longitude: 121.532,
      accuracyMeters: 8, headingDegrees: 270,
    ), isEmpty);
    expect(SpeedCameraDetector.findAhead(
      [camera], latitude: 25.025, longitude: 121.532,
      accuracyMeters: 160, headingDegrees: 90,
    ), isEmpty);
  });

  test('rejects malformed snapshots instead of showing fake results', () {
    final snapshot = {
      'schemaVersion': 1, 'source': 'NPA-7320',
      'generatedAt': '2026-11-19T00:00:00Z',
      'recordCount': 1, 'points': [
        {
          'id': 'npa7320:sample', 'latitude': 25.025,
          'longitude': 121.535, 'address': '測試路',
          'directionRaw': '往東', 'speedLimitKmh': 60,
        }
      ],
    };
    expect(SpeedCameraCatalog.fromJson(snapshot).points.length, 1);
    expect(() => SpeedCameraCatalog.fromJson({...snapshot, 'recordCount': 2}),
        throwsFormatException);
  });
}
