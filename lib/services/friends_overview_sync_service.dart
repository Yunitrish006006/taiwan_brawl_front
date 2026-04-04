import 'dart:async';

import 'package:flutter/widgets.dart';

import '../models/friends_models.dart';
import 'api_client.dart';
import 'auth_service.dart';
import 'friends_service.dart';

const Duration _friendsOverviewPollInterval = Duration(seconds: 3);

class FriendsOverviewSyncService extends ChangeNotifier
    with WidgetsBindingObserver {
  FriendsOverviewSyncService(ApiClient apiClient)
    : _friendsService = FriendsService(apiClient) {
    WidgetsBinding.instance.addObserver(this);
  }

  final FriendsService _friendsService;

  FriendsOverview? _overview;
  Timer? _pollTimer;
  Completer<void>? _refreshCompleter;
  int? _refreshingUserId;
  int? _userId;
  bool _isLoading = false;
  bool _isForeground = true;
  String _overviewSignature = '';

  FriendsOverview? get overview => _overview;
  bool get isLoading => _isLoading;

  void syncAuth(AuthService auth) {
    final nextUserId = auth.user?.id;
    if (nextUserId == _userId) {
      if (nextUserId != null && _isForeground && _pollTimer == null) {
        _startPolling();
      }
      if (nextUserId != null && _overview == null && !_isLoading) {
        unawaited(refreshNow(silent: false));
      }
      return;
    }

    _userId = nextUserId;

    if (nextUserId == null) {
      _stopPolling();
      _setOverview(null, isLoading: false);
      return;
    }

    _startPolling();
    unawaited(refreshNow(silent: false));
  }

  Future<void> refreshFor(
    AuthService auth, {
    bool silent = true,
  }) async {
    syncAuth(auth);
    if (auth.user == null) {
      return;
    }
    await refreshNow(silent: silent);
  }

  Future<void> refreshNow({bool silent = true}) async {
    if (_userId == null) {
      return;
    }

    final pendingRefresh = _refreshCompleter;
    if (pendingRefresh != null && _refreshingUserId == _userId) {
      return pendingRefresh.future;
    }

    final completer = Completer<void>();
    final refreshUserId = _userId;
    _refreshCompleter = completer;
    _refreshingUserId = refreshUserId;

    if (!silent && !_isLoading) {
      _isLoading = true;
      notifyListeners();
    }

    try {
      final overview = await _friendsService.fetchOverview();
      if (_userId == refreshUserId) {
        _setOverview(overview, isLoading: false);
      }
    } on ApiException {
      if (_userId == refreshUserId && _isLoading) {
        _isLoading = false;
        notifyListeners();
      }
    } finally {
      if (_refreshCompleter == completer) {
        _refreshCompleter = null;
      }
      if (_refreshingUserId == refreshUserId) {
        _refreshingUserId = null;
      }
      completer.complete();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:
        _isForeground = true;
        if (_userId != null) {
          _startPolling();
          unawaited(refreshNow());
        }
        break;
      case AppLifecycleState.inactive:
      case AppLifecycleState.hidden:
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
        _isForeground = false;
        _stopPolling();
        break;
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _stopPolling();
    super.dispose();
  }

  void _startPolling() {
    _stopPolling();
    if (_userId == null || !_isForeground) {
      return;
    }
    _pollTimer = Timer.periodic(_friendsOverviewPollInterval, (_) {
      unawaited(refreshNow());
    });
  }

  void _stopPolling() {
    _pollTimer?.cancel();
    _pollTimer = null;
  }

  void _setOverview(FriendsOverview? overview, {required bool isLoading}) {
    final nextSignature = _signatureFor(overview);
    final didOverviewChange = nextSignature != _overviewSignature;
    final didLoadingChange = _isLoading != isLoading;

    _overview = overview;
    _overviewSignature = nextSignature;
    _isLoading = isLoading;

    if (didOverviewChange || didLoadingChange) {
      notifyListeners();
    }
  }

  String _signatureFor(FriendsOverview? overview) {
    if (overview == null) {
      return '';
    }

    final parts = <String>[
      _serializeUsers('friends', overview.friends),
      _serializeRequests('incoming', overview.incomingRequests),
      _serializeRequests('outgoing', overview.outgoingRequests),
      _serializeUsers('blocked', overview.blockedUsers),
      _serializeRoomInvites(overview.roomInvites),
    ];
    return parts.join('|');
  }

  String _serializeUsers(String prefix, List<SocialUser> users) {
    return '$prefix:${users.map((user) {
      final onlineFlag = user.isOnline ? 1 : 0;
      final lastActiveAt = user.lastActiveAt ?? '';
      final avatarUrl = user.avatarUrl ?? '';
      return '${user.userId},$onlineFlag,$lastActiveAt,$avatarUrl';
    }).join(';')}';
  }

  String _serializeRequests(String prefix, List<FriendRequestItem> requests) {
    return '$prefix:${requests.map((request) {
      return '${request.id},${request.user.userId},${request.createdAt}';
    }).join(';')}';
  }

  String _serializeRoomInvites(List<RoomInviteItem> invites) {
    return 'room:${invites.map((invite) {
      return '${invite.id},${invite.inviter.userId},${invite.roomCode},${invite.createdAt}';
    }).join(';')}';
  }
}
