import 'dart:async';

import 'package:flutter/foundation.dart';
// ignore: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:geolocator/geolocator.dart';

import 'speed_camera_data.dart';
import 'speed_camera_repository.dart';

/// Foreground-only driving helper. Background tracking is deliberately disabled
/// until platform service permissions and physical road-matching are verified.
class SpeedCameraPage extends StatefulWidget {
  const SpeedCameraPage({super.key, required this.apiBaseUrl});
  final String apiBaseUrl;

  @override
  State<SpeedCameraPage> createState() => _SpeedCameraPageState();
}

class _SpeedCameraPageState extends State<SpeedCameraPage> {
  late final SpeedCameraRepository _repository;
  final FlutterTts _tts = FlutterTts();
  final Set<String> _spokenIds = <String>{};
  StreamSubscription<Position>? _positionSubscription;
  SpeedCameraCatalog? _catalog;
  Position? _position;
  SpeedCameraCandidate? _nearest;
  bool _loading = true;
  bool _tracking = false;
  String? _message;

  @override
  void initState() {
    super.initState();
    _repository = SpeedCameraRepository(baseUrl: widget.apiBaseUrl);
    _loadCatalog();
  }

  Future<void> _loadCatalog({bool forceRefresh = false}) async {
    if (!mounted) return;
    setState(() { _loading = true; _message = null; });
    try {
      final catalog = forceRefresh
          ? await _repository.refresh() : await _repository.load();
      if (!mounted) return;
      setState(() { _catalog = catalog; _loading = false; });
    } catch (error) {
      if (!mounted) return;
      final backup = await _repository.readCached();
      if (!mounted) return;
      setState(() {
        _catalog = backup;
        _loading = false;
        _message = backup == null
            ? '目前沒有可用的官方測速資料，請稍後再試。'
            : '連線失敗，繼續使用已下載的離線資料。';
      });
    }
  }

  Future<void> _startTracking() async {
    if (_tracking || _catalog == null) return;
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        throw StateError('請先開啟手機定位服務。');
      }
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        throw StateError('需要定位權限才能提供行車提醒。');
      }
      _spokenIds.clear();
      _positionSubscription = Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high, distanceFilter: 10,
        ),
      ).listen(
        _handlePosition,
        onError: (Object error) {
          if (mounted) {
            setState(() {
              _message = '定位暫時中斷，請確認 GPS 狀態。';
              _tracking = false;
            });
          }
          _positionSubscription?.cancel();
          _positionSubscription = null;
        },
      );
      if (mounted) setState(() { _tracking = true; _message = null; });
    } catch (error) {
      if (mounted) setState(() { _message = error.toString().replaceFirst('Bad state: ', ''); });
    }
  }

  void _handlePosition(Position position) {
    final catalog = _catalog;
    if (!mounted || catalog == null || !_tracking) return;
    final candidates = position.speed >= 1.5
        ? SpeedCameraDetector.findAhead(
            catalog.points,
            latitude: position.latitude,
            longitude: position.longitude,
            accuracyMeters: position.accuracy,
            headingDegrees: position.heading,
          )
        : <SpeedCameraCandidate>[];
    final closest = candidates.isNotEmpty ? candidates.first : null;
    setState(() { _position = position; _nearest = closest; });
    if (!kIsWeb && closest != null && closest.distanceMeters <= 400 &&
        _spokenIds.add(closest.point.id)) {
      unawaited(_speak('附近有公告測速執法地點，請留意道路速限。'));
    }
  }

  Future<void> _speak(String message) async {
    try {
      await _tts.setLanguage('zh-TW');
      await _tts.setSpeechRate(0.47);
      await _tts.speak(message);
    } catch (_) {
      if (mounted) {
        setState(() { _message = '語音播放失敗，請檢查手機音量。'; });
      }
    }
  }

  Future<void> _stopTracking() async {
    final subscription = _positionSubscription;
    _positionSubscription = null;
    await subscription?.cancel();
    await _tts.stop();
    if (mounted) setState(() {
      _tracking = false;
      _nearest = null;
      _position = null;
    });
  }

  @override
  void dispose() {
    _positionSubscription?.cancel();
    _tts.stop();
    _repository.dispose();
    super.dispose();
  }

  Widget _statTile(String title, String value, {Color? color}) {
    return Expanded(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: const TextStyle(color: Color(0xFF98A9C2), fontSize: 13)),
        const SizedBox(height: 7),
        Text(value, style: TextStyle(
          color: color ?? Colors.white, fontSize: 24, fontWeight: FontWeight.w700,
        )),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    const accent = Color(0xFF64E2C4);
    final speed = _position == null ? '--'
        : (_position!.speed * 3.6).clamp(0, 250).round().toString();
    final nearest = _nearest;
    final catalog = _catalog;
    return Scaffold(
      backgroundColor: const Color(0xFF0D1422),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0D1422),
        foregroundColor: Colors.white,
        title: const Text('行車測速提醒'),
        actions: [
          IconButton(
            onPressed: _loading ? null : () => _loadCatalog(forceRefresh: true),
            icon: const Icon(Icons.sync_rounded), tooltip: '檢查資料更新',
          ),
        ],
      ),
      body: SafeArea(child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 36),
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF1A3440), Color(0xFF142338)],
                begin: Alignment.topLeft, end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: const Color(0xFF345669)),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(_tracking ? 'GPS 行車模式執行中' : 'GPS 行車模式已停止',
                style: const TextStyle(color: accent, fontSize: 14)),
              const SizedBox(height: 22),
              Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Text(speed, style: const TextStyle(color: Colors.white,
                  fontSize: 80, height: 1, fontWeight: FontWeight.w300)),
                const Padding(padding: EdgeInsets.only(left: 10, bottom: 8),
                  child: Text('km/h', style: TextStyle(color: Color(0xFFB7C7D8),
                    fontSize: 19))),
              ]),
              const SizedBox(height: 20),
              const Divider(color: Color(0xFF416071)),
              const SizedBox(height: 16),
              Row(children: [
                _statTile('附近候選測速點',
                  nearest == null ? '無' : '${nearest.distanceMeters.round()} m',
                  color: nearest == null ? null : accent),
                _statTile('公告速限',
                  nearest?.point.speedLimitKmh == null
                      ? '--' : '${nearest!.point.speedLimitKmh} km/h'),
              ]),
            ]),
          ),
          const SizedBox(height: 18),
          if (nearest != null)
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(color: const Color(0xFF17263A),
                borderRadius: BorderRadius.circular(18)),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('附近測速執法點（尚未完成道路匹配）',
                    style: TextStyle(color: accent, fontWeight: FontWeight.bold)),
                const SizedBox(height: 10),
                Text(nearest.point.address, style: const TextStyle(
                    color: Colors.white, fontSize: 17)),
                const SizedBox(height: 6),
                Text('公告方向：${nearest.point.directionRaw.isEmpty ? "未提供" : nearest.point.directionRaw}',
                    style: const TextStyle(color: Color(0xFFBAC8DA))),
              ]),
            ),
          if (_message != null) Padding(
            padding: const EdgeInsets.only(top: 16),
            child: Text(_message!, style: const TextStyle(color: Color(0xFFFFC89A))),
          ),
          const SizedBox(height: 22),
          SizedBox(height: 56, child: FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: _tracking ? const Color(0xFFD97E77) : accent,
              foregroundColor: const Color(0xFF102132),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
            onPressed: _loading || (!_tracking && catalog == null)
                ? null : _tracking ? _stopTracking : _startTracking,
            icon: Icon(_tracking ? Icons.stop_rounded : Icons.navigation_rounded),
            label: Text(_tracking ? '結束行車模式' : '開始行車模式',
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 17)),
          )),
          const SizedBox(height: 18),
          Text(
            _loading ? '正在取得官方資料…'
                : catalog == null ? '尚無可用測速資料'
                : '警政署公開資料：${catalog.points.length} 處｜更新時間 ${catalog.generatedAt}',
            style: const TextStyle(color: Color(0xFF8FA2BA), fontSize: 12),
          ),
          const SizedBox(height: 12),
          const Text(
            '本功能使用警政署公開資料，僅供行車安全輔助。GPS 有誤差，'
            '距離與方向篩選無法排除高架、對向或平行道路。'
            '目前僅支援前景定位；手機鎖定或 APP 關閉後不可依賴提醒。'
            '行車請勿操作手機，請以現場標誌及法定速限為準。',
            style: TextStyle(color: Color(0xFF8293A8), height: 1.55, fontSize: 12),
          ),
        ],
      )),
    );
  }
}
