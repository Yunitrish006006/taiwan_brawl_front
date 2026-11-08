import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/couples_overview.dart';
import 'couple_widget_bridge.dart';

Future<String> persistentCoupleWidgetScope(int account) async {
  final box = await Hive.openBox<String>('couple_widget_scopes_v1');
  final key = 'account:$account';
  final existing = box.get(key);
  if (existing != null) return existing;
  final random = Random.secure();
  final value = List.generate(
    32,
    (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'),
  ).join();
  await box.put(key, value);
  return value;
}

/// Serializes account reservations and snapshots; native code independently
/// rejects old generations and sequences. Unknown offline identity preserves disk state.
class CoupleWidgetController extends ChangeNotifier {
  CoupleWidgetController(
    this.bridge, {
    required this.scopeForAccount,
    this.enabled = true,
  });
  final CoupleWidgetBridge bridge;
  final Future<String> Function(int) scopeForAccount;
  final bool enabled;
  Future<void> _pending = Future.value();
  int? _account;
  bool _selected = false, _disposed = false;
  int _epoch = 0, _sequence = 0;
  int? _nativeGeneration;
  String? _scope;
  CouplesOverview? _snapshot;
  bool get failed => _failed;
  bool _failed = false;

  void sync({
    required bool identityResolved,
    required int? account,
    required CouplesOverview? snapshot,
  }) {
    if (_disposed || !enabled || !identityResolved) return;
    final changed = !_selected || account != _account;
    if (!changed && identical(snapshot, _snapshot) && !_failed) return;
    _selected = true;
    _account = account;
    _snapshot = snapshot;
    if (changed) {
      _epoch++;
      _nativeGeneration = null;
      _sequence = 0;
    }
    final epoch = _epoch, sequence = ++_sequence;
    _pending = _pending.then((_) async {
      if (_disposed || epoch != _epoch || sequence != _sequence) return;
      try {
        // Clear first, before a potentially failing scope lookup. Never leave the
        // previous account's active data on disk while selecting another account.
        if (_nativeGeneration == null) {
          await bridge.beginSession(null);
          if (_disposed || epoch != _epoch || sequence != _sequence) return;
          final scope = account == null ? null : await scopeForAccount(account);
          if (_disposed || epoch != _epoch || sequence != _sequence) return;
          final generation = await bridge.beginSession(scope);
          if (_disposed || epoch != _epoch) return;
          _nativeGeneration = generation;
          _scope = scope;
        }
        if (_disposed || epoch != _epoch || sequence != _sequence) return;
        final relation = account == null ? null : snapshot?.relationship;
        await bridge.replace({
          'schemaVersion': 1,
          'accountScope': _scope,
          'sessionGeneration': _nativeGeneration,
          'requestSequence': sequence,
          'relationshipId': relation?.id,
          'relationshipVersion': relation?.version,
          'startedOn': relation?.startedOn,
          'partnerName': relation?.partnerName,
          'status': account == null
              ? 'signedOut'
              : relation == null
              ? 'unbound'
              : 'active',
          'lastSyncedAt': relation == null
              ? null
              : snapshot!.serverNow.toUtc().toIso8601String(),
        });
        if (!_disposed && epoch == _epoch) {
          _failed = false;
          notifyListeners();
        }
      } catch (_) {
        if (!_disposed && epoch == _epoch) {
          _failed = true;
          notifyListeners();
        }
      }
    });
  }

  Future<void> flush() => _pending;
  @override
  void dispose() {
    _disposed = true;
    _epoch++;
    super.dispose();
  }
}
