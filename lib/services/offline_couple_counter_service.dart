import 'dart:async';
import 'package:flutter/widgets.dart';
import '../models/offline_couple_counter.dart';
import 'auth_service.dart';
import 'couple_widget_bridge.dart';

abstract interface class OfflineCoupleCounterSource {
  Future<Map<String, dynamic>?> readCounter();
}

class NativeOfflineCoupleCounterSource implements OfflineCoupleCounterSource {
  @override
  Future<Map<String, dynamic>?> readCounter() async {
    if (!NativeCoupleWidgetBridge.supported) return null;
    final result = await NativeCoupleWidgetBridge.channel
        .invokeMapMethod<String, dynamic>('readCounter');
    return result == null ? null : Map<String, dynamic>.from(result);
  }
}

/// A read-only window for unverified identity, never authentication or mutation.
/// Sign-in attempts, explicit logout and authoritative expiry close it for the
/// process; successful identity restoration only suspends it while online.
class OfflineCoupleCounterService extends ChangeNotifier
    with WidgetsBindingObserver {
  OfflineCoupleCounterService(this.source, {DateTime Function()? clock})
    : _clock = clock ?? DateTime.now {
    WidgetsBinding.instance.addObserver(this);
  }
  final OfflineCoupleCounterSource source;
  final DateTime Function() _clock;
  OfflineCoupleCounter? _counter;
  OfflineCoupleCounter? get counter => _counter;
  int? get days => _counter?.dayCount(_clock());
  bool get allowed => _allowed;
  bool get failed => _failed;
  bool _coldWindow = true, _allowed = false, _failed = false, _disposed = false;
  bool _visible = false, _foreground = true;
  int _generation = 0;
  Timer? _timer;
  void syncAuth(AuthService auth) {
    if (_disposed || !_coldWindow) return;
    if (auth.identityState != AuthIdentityState.unresolved ||
        auth.isSigningIn) {
      if (auth.identityState == AuthIdentityState.signedOut ||
          auth.isSigningIn) {
        _coldWindow = false;
      }
      if (!_allowed && _counter == null) return;
      _allowed = false;
      _counter = null;
      _generation++;
      _timer?.cancel();
      scheduleMicrotask(() {
        if (!_disposed) notifyListeners();
      });
      return;
    }
    if (!_allowed) {
      _allowed = true;
      unawaited(refresh());
    }
  }

  Future<void> refresh() async {
    if (!_allowed || _disposed) return;
    final generation = ++_generation;
    try {
      final raw = await source.readCounter();
      final value = raw == null ? null : OfflineCoupleCounter.fromJson(raw);
      if (_disposed || !_allowed || generation != _generation) return;
      _counter = value;
      _failed = false;
    } catch (_) {
      if (_disposed || generation != _generation) return;
      _counter = null;
      _failed = true;
    }
    if (!_disposed) notifyListeners();
  }

  void setVisible(bool value) {
    _visible = value;
    _startClock();
  }

  void _startClock() {
    _timer?.cancel();
    if (_disposed || !_visible || !_foreground || !_allowed) return;
    _timer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (!_disposed) notifyListeners();
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    _startClock();
    if (_foreground && _visible) unawaited(refresh());
  }

  @override
  void dispose() {
    _disposed = true;
    _generation++;
    _timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }
}
