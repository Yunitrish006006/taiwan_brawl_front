import 'dart:math' as math;

class SpeedCameraPoint {
  const SpeedCameraPoint({
    required this.id,
    required this.latitude,
    required this.longitude,
    required this.address,
    required this.directionRaw,
    required this.speedLimitKmh,
  });

  final String id;
  final double latitude;
  final double longitude;
  final String address;
  final String directionRaw;
  final int? speedLimitKmh;

  static SpeedCameraPoint fromJson(Map<String, dynamic> map) {
    final lat = (map['latitude'] as num?)?.toDouble();
    final lng = (map['longitude'] as num?)?.toDouble();
    final id = map['id'];
    final address = map['address'];
    if (id is! String || !id.startsWith('npa7320:') ||
        address is! String || address.trim().isEmpty ||
        lat == null || lng == null ||
        !lat.isFinite || !lng.isFinite ||
        lat < 18 || lat > 27 || lng < 115 || lng > 124) {
      throw const FormatException('測速點資料有誤');
    }
    final rawLimit = map['speedLimitKmh'];
    return SpeedCameraPoint(
      id: id,
      latitude: lat,
      longitude: lng,
      address: address,
      directionRaw: map['directionRaw'] is String
          ? map['directionRaw'] as String : '',
      speedLimitKmh: rawLimit is num ? rawLimit.toInt() : null,
    );
  }
}

class SpeedCameraCatalog {
  const SpeedCameraCatalog({
    required this.version,
    required this.generatedAt,
    required this.points,
  });

  final String version;
  final String generatedAt;
  final List<SpeedCameraPoint> points;

  factory SpeedCameraCatalog.fromJson(Map<String, dynamic> json) {
    if (json['schemaVersion'] != 1 || json['source'] != 'NPA-7320' ||
        json['points'] is! List || json['recordCount'] !=
        (json['points'] as List).length) {
      throw const FormatException('測速資料版本或內容格式錯誤');
    }
    final points = (json['points'] as List).map((entry) {
      if (entry is! Map) throw const FormatException('測速點格式錯誤');
      return SpeedCameraPoint.fromJson(Map<String, dynamic>.from(entry));
    }).toList(growable: false);
    if (points.isEmpty || points.length > 30000) {
      throw const FormatException('測速資料筆數不合理');
    }
    final generatedAt = json['generatedAt'];
    final version = json['contentSha256'] ?? generatedAt;
    if (version is! String || version.isEmpty ||
        generatedAt is! String || generatedAt.isEmpty) {
      throw const FormatException('缺少測速資料版本');
    }
    return SpeedCameraCatalog(
      version: version,
      generatedAt: generatedAt,
      points: points,
    );
  }
}

class SpeedCameraCandidate {
  const SpeedCameraCandidate(this.point, this.distanceMeters);
  final SpeedCameraPoint point;
  final double distanceMeters;
}

/// Spatial/heading candidate search only. Never claim road-level accuracy:
/// nearby parallel roads, elevated roads and source directions need map matching.
class SpeedCameraDetector {
  static const double earthRadiusMeters = 6371008.8;

  static double _rad(double degrees) => degrees * math.pi / 180;

  static double distanceMeters(
    double lat1, double lng1, double lat2, double lng2,
  ) {
    final dLat = _rad(lat2 - lat1);
    final dLng = _rad(lng2 - lng1);
    final a = math.pow(math.sin(dLat / 2), 2) +
        math.cos(_rad(lat1)) * math.cos(_rad(lat2)) *
            math.pow(math.sin(dLng / 2), 2);
    final h = (a as num).toDouble().clamp(0.0, 1.0);
    return 2 * earthRadiusMeters *
        math.atan2(math.sqrt(h), math.sqrt(1 - h));
  }

  static double bearingDegrees(
    double lat1, double lng1, double lat2, double lng2,
  ) {
    final y = math.sin(_rad(lng2 - lng1)) * math.cos(_rad(lat2));
    final x = math.cos(_rad(lat1)) * math.sin(_rad(lat2)) -
        math.sin(_rad(lat1)) * math.cos(_rad(lat2)) *
            math.cos(_rad(lng2 - lng1));
    return (math.atan2(y, x) * 180 / math.pi + 360) % 360;
  }

  static List<SpeedCameraCandidate> findAhead(
    List<SpeedCameraPoint> points, {
    required double latitude,
    required double longitude,
    required double accuracyMeters,
    required double headingDegrees,
    double radiusMeters = 600,
    double maxHeadingDeviation = 60,
  }) {
    if (!latitude.isFinite || !longitude.isFinite ||
        !accuracyMeters.isFinite || accuracyMeters < 0 ||
        accuracyMeters > 100 || !headingDegrees.isFinite) {
      return const [];
    }
    final heading = (headingDegrees % 360 + 360) % 360;
    final found = <SpeedCameraCandidate>[];
    for (final point in points) {
      final distance = distanceMeters(
        latitude, longitude, point.latitude, point.longitude,
      );
      if (distance < 5 || distance > radiusMeters) continue;
      final bearing = bearingDegrees(
        latitude, longitude, point.latitude, point.longitude,
      );
      final deviation = ((bearing - heading + 540) % 360 - 180).abs();
      if (deviation <= maxHeadingDeviation) {
        found.add(SpeedCameraCandidate(point, distance));
      }
    }
    found.sort((a, b) => a.distanceMeters.compareTo(b.distanceMeters));
    return found;
  }
}
