import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'speed_camera_data.dart';

/// Stores the latest validated dataset for offline use; no location history.
/// A SQLite spatial index is planned once road-matching is implemented.
class SpeedCameraRepository {
  SpeedCameraRepository({required this.baseUrl, http.Client? client})
      : _client = client ?? http.Client();

  static const String _cacheKey = 'speed_camera_npa7320_snapshot_v1';
  final String baseUrl;
  final http.Client _client;

  Uri _uri(String path) =>
      Uri.parse('${baseUrl.replaceFirst(RegExp(r"/+$"), "")}$path');

  Future<SpeedCameraCatalog?> readCached() async {
    final preferences = await SharedPreferences.getInstance();
    final raw = preferences.getString(_cacheKey);
    if (raw == null) return null;
    try {
      final data = jsonDecode(raw);
      if (data is! Map<String, dynamic>) return null;
      return SpeedCameraCatalog.fromJson(data);
    } on FormatException {
      return null;
    } catch (_) {
      return null;
    }
  }

  Future<SpeedCameraCatalog> refresh() async {
    final manifest = await _client
        .get(_uri('/api/speed-cameras/manifest'))
        .timeout(const Duration(seconds: 15));
    if (manifest.statusCode != 200) {
      throw StateError('測速資料服務暫時無法取得（HTTP ${manifest.statusCode}）');
    }
    final metadata = jsonDecode(utf8.decode(manifest.bodyBytes));
    if (metadata is! Map<String, dynamic> ||
        metadata['version'] is! String) {
      throw const FormatException('測速資料版本資訊錯誤');
    }
    final expectedVersion = metadata['version'] as String;
    final cached = await readCached();
    if (cached != null && cached.version == expectedVersion) {
      return cached;
    }

    final response = await _client
        .get(_uri('/api/speed-cameras/snapshot'))
        .timeout(const Duration(seconds: 25));
    if (response.statusCode != 200) {
      throw StateError('測速資料下載失敗（HTTP ${response.statusCode}）');
    }
    final data = jsonDecode(utf8.decode(response.bodyBytes));
    if (data is! Map<String, dynamic>) {
      throw const FormatException('測速資料回應格式錯誤');
    }
    final catalog = SpeedCameraCatalog.fromJson(data);
    if (catalog.version != expectedVersion ||
        catalog.points.length != metadata['recordCount']) {
      throw const FormatException('測速資料版本或筆數不一致');
    }
    // Save only after the full snapshot validates, retaining the previous version.
    final preferences = await SharedPreferences.getInstance();
    if (!await preferences.setString(_cacheKey, jsonEncode(data))) {
      throw StateError('無法儲存離線測速資料');
    }
    return catalog;
  }

  Future<SpeedCameraCatalog> load() async {
    try {
      return await refresh();
    } catch (_) {
      final cached = await readCached();
      if (cached != null) return cached;
      rethrow;
    }
  }

  void dispose() => _client.close();
}
