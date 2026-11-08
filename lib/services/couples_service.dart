import 'dart:async';
import 'package:flutter/widgets.dart';
import '../models/couples_overview.dart';
import '../models/couple_relationship.dart';
import 'remote_source_exception.dart';
import 'couples_cache.dart';
import 'couples_remote_source.dart';

/// One account's last confirmed state; persisted snapshots are account-keyed.
class CouplesService extends ChangeNotifier with WidgetsBindingObserver {
  CouplesService(
    this._remote, {
    CouplesCache? cache,
    bool autoSync = false,
    DateTime Function()? clock,
    Stream<bool>? networkChanges,
  }) : _cache = cache,
       _autoSync = autoSync,
       _clock = clock ?? DateTime.now {
    if (_autoSync) WidgetsBinding.instance.addObserver(this);
    _networkSubscription = networkChanges?.listen((available) {
      final restored = _networkAvailable == false && available;
      _networkAvailable = available;
      if (restored) networkRestored();
    }, onError: (Object _) {});
  }
  final CouplesRemoteSource _remote;
  final CouplesCache? _cache;
  final bool _autoSync;
  final DateTime Function() _clock;
  int? _accountId;
  int _generation = 0, _requestSequence = 0, _snapshotEpoch = 0, _failures = 0;
  CouplesOverview? _snapshot;
  Future<CouplesOverview?>? _inFlight;
  Future<void>? _automaticInFlight;
  Future<void> _writes = Future.value();
  Timer? _timer, _clockTimer, _midnightTimer;
  String? _calendarStamp;
  StreamSubscription<bool>? _networkSubscription;
  bool? _networkAvailable;
  DateTime? _lastNetworkRecovery;
  bool _foreground = true, _disposed = false;
  int? get accountId => _accountId;
  CouplesOverview? get snapshot => _snapshot;
  bool get isStale => _isStale;
  bool get lastRefreshFailed => _lastRefreshFailed;
  bool get cacheWriteFailed => _cacheWriteFailed;
  bool get sessionExpired => _sessionExpired;
  bool _isStale = false;
  bool _lastRefreshFailed = false, _cacheWriteFailed = false;
  bool _sessionExpired = false;

  void setAccount(int? accountId) {
    if (accountId == _accountId) return;
    _accountId = accountId;
    final generation = ++_generation;
    _requestSequence++;
    _snapshotEpoch++;
    _snapshot = null;
    _isStale = false;
    _inFlight = null;
    _automaticInFlight = null;
    _timer?.cancel();
    _clockTimer?.cancel();
    _midnightTimer?.cancel();
    _failures = 0;
    _lastRefreshFailed = false;
    _cacheWriteFailed = false;
    _sessionExpired = false;
    _lastNetworkRecovery = null;
    scheduleMicrotask(() {
      if (!_disposed && _generation == generation) notifyListeners();
    });
    if (accountId != null && _autoSync) {
      _calendarStamp = _stamp(_clock());
      if (_foreground) _startClock();
      unawaited(_activate(accountId, generation));
    }
  }

  Future<void> _activate(int account, int generation) async {
    await restore();
    if (_disposed || _generation != generation || _accountId != account) return;
    await _automaticRefresh();
  }

  Future<void> restore() async {
    final account = _accountId,
        generation = _generation,
        epoch = _snapshotEpoch;
    if (account == null || _cache == null) return;
    try {
      // Wait for earlier writes before loading the same account again.
      await _writes;
      final raw = await _cache.read(account);
      if (raw == null ||
          _disposed ||
          _generation != generation ||
          _snapshotEpoch != epoch) {
        return;
      }
      _snapshot = CouplesOverview.fromJson(raw);
      _snapshotEpoch++;
      _isStale = true;
      notifyListeners();
    } catch (_) {
      // Broken or unavailable cache must not fabricate a relationship.
    }
  }

  void _enqueueWrite(
    int account,
    int generation,
    int sequence,
    Map<String, dynamic>? data,
  ) {
    if (_cache == null) return;
    _writes = _writes.catchError((Object _) {}).then((_) async {
      if (_disposed ||
          _generation != generation ||
          _requestSequence != sequence ||
          _accountId != account) {
        return;
      }
      try {
        if (data == null) {
          await _cache.remove(account);
        } else {
          await _cache.write(account, data);
        }
        if (!_disposed && _generation == generation && _cacheWriteFailed) {
          _cacheWriteFailed = false;
          notifyListeners();
        }
      } catch (_) {
        if (!_disposed && _generation == generation) {
          _cacheWriteFailed = true;
          notifyListeners();
        }
      }
    });
  }

  /// Exposed for lifecycle and deterministic testing; cache errors do not fail a successful request.
  Future<void> flushCache() async {
    try {
      await _writes;
    } catch (_) {}
  }

  Future<CouplesOverview?> refresh() {
    final account = _accountId;
    if (account == null || _disposed) return Future.value(null);
    final existing = _inFlight;
    if (existing != null) return existing;
    final generation = _generation, sequence = ++_requestSequence;
    late final Future<CouplesOverview?> future;
    future = Future.sync(() => _remote.overview(accountId: account))
        .then((raw) {
          final data = CouplesOverview.fromJson(raw);
          if (_disposed ||
              generation != _generation ||
              sequence != _requestSequence) {
            return null;
          }
          _snapshot = data;
          _snapshotEpoch++;
          _isStale = false;
          _lastRefreshFailed = false;
          _enqueueWrite(account, generation, sequence, raw);
          notifyListeners();
          return data;
        })
        .catchError((Object error, StackTrace stack) {
          _invalidateOnUnauthorized(error, generation);
          if (!_disposed && generation == _generation) {
            _lastRefreshFailed = true;
            _isStale = _snapshot != null;
            notifyListeners();
          }
          Error.throwWithStackTrace(error, stack);
        })
        .whenComplete(() {
          if (identical(_inFlight, future)) _inFlight = null;
        });
    _inFlight = future;
    return future;
  }

  Future<Map<String, dynamic>> mutate(
    String path,
    Map<String, dynamic> body,
  ) async {
    final account = _accountId, generation = _generation;
    if (account == null || _disposed) throw StateError('No signed-in account');
    late final Map<String, dynamic> result;
    try {
      result = await _remote.mutate(path, body, accountId: account);
    } catch (error) {
      _invalidateOnUnauthorized(error, generation);
      rethrow;
    }
    if (_disposed || generation != _generation) {
      throw StateError('Account changed during operation');
    }
    final sequence = ++_requestSequence;
    _inFlight = null;
    _snapshot = null;
    _snapshotEpoch++;
    _isStale = false;
    _enqueueWrite(account, generation, sequence, null);
    // Invalidate durable old state before attempting a potentially failing refresh.
    await flushCache();
    if (_disposed || generation != _generation) {
      throw StateError('Account changed during operation');
    }
    notifyListeners();
    try {
      await refresh();
    } catch (_) {
      if (!_disposed && generation == _generation) {
        _lastRefreshFailed = true;
        notifyListeners();
      }
    }
    if (_disposed ||
        (generation != _generation &&
            !(_sessionExpired && _accountId == null))) {
      throw StateError('Account changed during operation');
    }
    return result;
  }

  void _invalidateOnUnauthorized(Object error, int generation) {
    if (!_disposed &&
        generation == _generation &&
        error is RemoteSourceException &&
        error.statusCode == 401) {
      setAccount(null);
      _sessionExpired = true;
    }
  }

  /// The friendship API atomically ends couples on the server. Discard the
  /// previous snapshot before refreshing so a failed read cannot revive it.
  Future<void> invalidateAfterFriendChange(int account) async {
    if (_disposed || _accountId != account) return;
    final generation = _generation, sequence = ++_requestSequence;
    _inFlight = null;
    _snapshot = null;
    _snapshotEpoch++;
    _enqueueWrite(account, generation, sequence, null);
    notifyListeners();
    await flushCache();
    if (!_disposed && _accountId == account && generation == _generation) {
      try {
        await refresh();
      } catch (_) {
        /* Removed state stays removed. */
      }
    }
  }

  Map<String, dynamic> _data(Map<String, dynamic> response) {
    if (response['ok'] != true || response['data'] is! Map<String, dynamic>) {
      throw const FormatException('Invalid couples mutation response');
    }
    return response['data'] as Map<String, dynamic>;
  }

  Future<CoupleRequest> sendRequest({
    required int targetUserId,
    required String startedOn,
    required String timeZone,
    required String operationId,
  }) async {
    final data = _data(
      await mutate('/api/couples/requests', {
        'targetUserId': targetUserId,
        'startedOn': startedOn,
        'timeZone': timeZone,
        'operationId': operationId,
      }),
    );
    return CoupleRequest.fromJson(data['request'] as Map<String, dynamic>);
  }

  Future<CoupleRelationship> acceptRequest(
    String id, {
    required String timeZone,
    required String operationId,
  }) async {
    final data = _data(
      await mutate('/api/couples/requests/$id/accept', {
        'timeZone': timeZone,
        'operationId': operationId,
      }),
    );
    return CoupleRelationship.fromJson(
      data['relationship'] as Map<String, dynamic>,
    );
  }

  Future<CoupleRequest> rejectRequest(
    String id, {
    required String operationId,
  }) => _requestAction(id, 'reject', operationId);
  Future<CoupleRequest> cancelRequest(
    String id, {
    required String operationId,
  }) => _requestAction(id, 'cancel', operationId);
  Future<CoupleRequest> _requestAction(
    String id,
    String action,
    String operationId,
  ) async {
    final data = _data(
      await mutate('/api/couples/requests/$id/$action', {
        'operationId': operationId,
      }),
    );
    return CoupleRequest.fromJson(data['request'] as Map<String, dynamic>);
  }

  Future<CoupleDateProposal> proposeDate(
    String relationshipId, {
    required String startedOn,
    required String timeZone,
    required int expectedVersion,
    required String operationId,
  }) async {
    final data = _data(
      await mutate('/api/couples/$relationshipId/date-proposals', {
        'startedOn': startedOn,
        'timeZone': timeZone,
        'expectedVersion': expectedVersion,
        'operationId': operationId,
      }),
    );
    return CoupleDateProposal.fromJson(
      data['proposal'] as Map<String, dynamic>,
    );
  }

  Future<CoupleRelationship> acceptDate(
    String id, {
    required String timeZone,
    required String operationId,
  }) async {
    final data = _data(
      await mutate('/api/couples/date-proposals/$id/accept', {
        'timeZone': timeZone,
        'operationId': operationId,
      }),
    );
    return CoupleRelationship.fromJson(
      data['relationship'] as Map<String, dynamic>,
    );
  }

  Future<CoupleDateProposal> rejectDate(
    String id, {
    required String operationId,
  }) => _dateAction(id, 'reject', operationId);
  Future<CoupleDateProposal> cancelDate(
    String id, {
    required String operationId,
  }) => _dateAction(id, 'cancel', operationId);
  Future<CoupleDateProposal> _dateAction(
    String id,
    String action,
    String operationId,
  ) async {
    final data = _data(
      await mutate('/api/couples/date-proposals/$id/$action', {
        'operationId': operationId,
      }),
    );
    return CoupleDateProposal.fromJson(
      data['proposal'] as Map<String, dynamic>,
    );
  }

  Future<CoupleRelationship> endRelationship(
    String relationshipId, {
    required String operationId,
  }) async {
    final data = _data(
      await mutate('/api/couples/$relationshipId/end', {
        'operationId': operationId,
      }),
    );
    return CoupleRelationship.fromJson(
      data['relationship'] as Map<String, dynamic>,
    );
  }

  Future<void> _automaticRefresh() {
    final existing = _automaticInFlight;
    if (existing != null) return existing;
    late final Future<void> future;
    future = _runAutomaticRefresh().whenComplete(() {
      if (identical(_automaticInFlight, future)) _automaticInFlight = null;
    });
    _automaticInFlight = future;
    return future;
  }

  Future<void> _runAutomaticRefresh() async {
    if (_disposed || !_foreground || _accountId == null) return;
    final generation = _generation;
    try {
      await refresh();
      if (_disposed || generation != _generation) return;
      _failures = 0;
    } catch (_) {
      if (_disposed || generation != _generation) return;
      _failures++;
      _isStale = _snapshot != null;
      _lastRefreshFailed = true;
      if (!_disposed && generation == _generation) notifyListeners();
    }
    if (_disposed ||
        generation != _generation ||
        !_foreground ||
        _accountId == null) {
      return;
    }
    final minutes = _failures == 0
        ? 1
        : (1 << (_failures - 1).clamp(0, 3)).clamp(1, 5);
    _timer?.cancel();
    _timer = Timer(Duration(minutes: minutes), _automaticRefresh);
  }

  /// Call when a platform connectivity observer reports restored networking.
  void networkRestored() {
    final now = _clock();
    final elapsed = _lastNetworkRecovery == null
        ? null
        : now.difference(_lastNetworkRecovery!);
    if (elapsed != null &&
        !elapsed.isNegative &&
        elapsed < const Duration(seconds: 5)) {
      return;
    }
    _lastNetworkRecovery = now;
    if (_autoSync) unawaited(_automaticRefresh());
  }

  String _stamp(DateTime value) =>
      '${value.year}-${value.month}-${value.day}-${value.timeZoneName}-${value.timeZoneOffset.inMinutes}';

  void _checkCalendar() {
    if (_disposed || !_foreground || _accountId == null) return;
    final stamp = _stamp(_clock());
    if (stamp != _calendarStamp) {
      _calendarStamp = stamp;
      notifyListeners();
      _scheduleMidnight();
    }
  }

  void _scheduleMidnight() {
    _midnightTimer?.cancel();
    final now = _clock();
    final midnight = DateTime(now.year, now.month, now.day + 1);
    _midnightTimer = Timer(midnight.difference(now), () {
      _checkCalendar();
      if (!_disposed && _foreground && _accountId != null) _scheduleMidnight();
    });
  }

  void _startClock() {
    _clockTimer?.cancel();
    _clockTimer = Timer.periodic(
      const Duration(minutes: 1),
      (_) => _checkCalendar(),
    );
    _checkCalendar();
    _scheduleMidnight();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    if (!_foreground) {
      _timer?.cancel();
      _clockTimer?.cancel();
      _midnightTimer?.cancel();
      return;
    }
    if (_autoSync && _accountId != null) {
      _startClock();
      unawaited(_automaticRefresh());
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _generation++;
    _timer?.cancel();
    _clockTimer?.cancel();
    _midnightTimer?.cancel();
    unawaited(_networkSubscription?.cancel());
    if (_autoSync) WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }
}
