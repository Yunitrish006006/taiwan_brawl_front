import 'package:user_social_system/user_social_system.dart'
    show FriendsDirectory;

import '../models/friends_models.dart';
import '../config/app_configuration.dart';
import '../utils/remote_image_url.dart';
import 'friends_remote_source.dart';
import 'service_utils.dart';

class FriendsService implements FriendsDirectory {
  FriendsService({
    required FriendsRemoteSource remoteSource,
    AppConfiguration? configuration,
  }) : _remoteSource = remoteSource,
       _apiBaseUrl = (configuration ?? AppConfiguration.environment).apiBaseUrl;

  final FriendsRemoteSource _remoteSource;
  final String _apiBaseUrl;

  String? _resolveAvatar(String? value) =>
      resolveRemoteImageUrl(value, apiBaseUrl: _apiBaseUrl);

  @override
  Future<FriendsOverview> fetchOverview() async {
    final res = await _remoteSource.fetchOverview();
    return FriendsOverview.fromJson(res, resolveAvatar: _resolveAvatar);
  }

  @override
  Future<List<FriendSearchResult>> searchByName(String query) async {
    final res = await _remoteSource.searchByName(query);
    return jsonModelList(
      res,
      'results',
      (json) =>
          FriendSearchResult.fromJson(json, resolveAvatar: _resolveAvatar),
    );
  }

  @override
  Future<void> sendFriendRequest(int targetUserId) async {
    await _remoteSource.sendFriendRequest(targetUserId);
  }

  @override
  Future<void> acceptFriendRequest(int requestId) async {
    await _remoteSource.acceptFriendRequest(requestId);
  }

  @override
  Future<void> rejectFriendRequest(int requestId) async {
    await _remoteSource.rejectFriendRequest(requestId);
  }

  @override
  Future<void> cancelFriendRequest(int requestId) async {
    await _remoteSource.cancelFriendRequest(requestId);
  }

  @override
  Future<void> removeFriend(int targetUserId) async {
    await _remoteSource.removeFriend(targetUserId);
  }

  @override
  Future<void> blockUser(int targetUserId) async {
    await _remoteSource.blockUser(targetUserId);
  }

  @override
  Future<void> unblockUser(int targetUserId) async {
    await _remoteSource.unblockUser(targetUserId);
  }

  Future<void> sendRoomInvite({
    required String gameId,
    required String roomCode,
    required int inviteeUserId,
  }) async {
    await _remoteSource.sendRoomInvite(
      gameId: gameId,
      roomCode: roomCode,
      inviteeUserId: inviteeUserId,
    );
  }

  Future<RoomInviteActionResult> acceptRoomInvite(int inviteId) async {
    final res = await _remoteSource.acceptRoomInvite(inviteId);
    return RoomInviteActionResult.fromJson(res);
  }

  Future<void> rejectRoomInvite(int inviteId) async {
    await _remoteSource.rejectRoomInvite(inviteId);
  }
}
