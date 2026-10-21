import 'package:flutter/material.dart';
import 'package:taiwan_brawl_game_mini_royale/taiwan_brawl_game_mini_royale.dart';

import '../../models/friends_models.dart';
import '../../services/api_client.dart';
import '../../services/auth_service.dart';
import '../../services/friends_overview_sync_service.dart';
import '../../services/friends_service.dart';
import '../../widgets/friend_search_dialog.dart';

/// App adapter for Mini Royale's package-owned social capability port.
class GameMiniRoyaleArenaSocialAdapter extends MiniRoyaleArenaSocialPort {
  GameMiniRoyaleArenaSocialAdapter({
    required FriendsService friendsService,
    required FriendsOverviewSyncService overviewSync,
    required AuthService authService,
  }) : _friendsService = friendsService,
       _overviewSync = overviewSync,
       _authService = authService {
    _overviewSync.addListener(_notifyChanged);
  }

  final FriendsService _friendsService;
  final FriendsOverviewSyncService _overviewSync;
  final AuthService _authService;

  @override
  bool get isLoading => _overviewSync.isLoading;

  @override
  List<MiniRoyaleArenaFriend> get friends =>
      _overviewSync.overview?.friends.map(_mapFriend).toList(growable: false) ??
      const [];

  @override
  bool isFriend(int userId) =>
      _overviewSync.overview?.friends.any(
        (friend) => friend.userId == userId,
      ) ??
      false;

  @override
  bool hasOutgoingFriendRequest(int userId) =>
      _overviewSync.overview?.outgoingRequests.any(
        (request) => request.user.userId == userId,
      ) ??
      false;

  @override
  Future<void> refresh() => _overviewSync.refreshFor(_authService);

  @override
  Future<void> sendRoomInvite({
    required String roomCode,
    required int userId,
  }) async {
    try {
      await _friendsService.sendRoomInvite(
        gameId: miniRoyaleModuleId,
        roomCode: roomCode,
        inviteeUserId: userId,
      );
    } on ApiException catch (error) {
      throw MiniRoyaleArenaSocialException(error.message);
    }
  }

  @override
  Future<void> sendFriendRequest(int userId) async {
    try {
      await _friendsService.sendFriendRequest(userId);
    } on ApiException catch (error) {
      throw MiniRoyaleArenaSocialException(error.message);
    }
  }

  @override
  Future<void> openSearch({
    required BuildContext context,
    required void Function(String message) onMessage,
  }) => showFriendSearchDialog(
    context: context,
    friendsService: _friendsService,
    onRefreshFriends: refresh,
    onMessage: onMessage,
  );

  void _notifyChanged() => notifyListeners();

  MiniRoyaleArenaFriend _mapFriend(SocialUser friend) => MiniRoyaleArenaFriend(
    userId: friend.userId,
    name: friend.name,
    avatarUrl: friend.avatarUrl,
    lastActiveAt: friend.lastActiveAt,
    isOnline: friend.isOnline,
  );

  @override
  void dispose() {
    _overviewSync.removeListener(_notifyChanged);
    super.dispose();
  }
}
