import '../models/friends_models.dart';
import '../config/app_configuration.dart';
import 'api_client.dart';
import 'friends_remote_source.dart';
import 'service_utils.dart';

class FriendsService {
  FriendsService(
    ApiClient apiClient, {
    FriendsRemoteSource? remoteSource,
    AppConfiguration? configuration,
  }) : _remoteSource = remoteSource ?? ServerFriendsRemoteSource(apiClient),
       _apiBaseUrl = (configuration ?? AppConfiguration.environment).apiBaseUrl;

  final FriendsRemoteSource _remoteSource;
  final String _apiBaseUrl;

  Future<FriendsOverview> fetchOverview() async {
    final res = await _remoteSource.fetchOverview();
    return FriendsOverview.fromJson(res, apiBaseUrl: _apiBaseUrl);
  }

  Future<List<FriendSearchResult>> searchByName(String query) async {
    final res = await _remoteSource.searchByName(query);
    return jsonModelList(
      res,
      'results',
      (json) => FriendSearchResult.fromJson(json, apiBaseUrl: _apiBaseUrl),
    );
  }

  Future<void> sendFriendRequest(int targetUserId) async {
    await _remoteSource.sendFriendRequest(targetUserId);
  }

  Future<void> acceptFriendRequest(int requestId) async {
    await _remoteSource.acceptFriendRequest(requestId);
  }

  Future<void> rejectFriendRequest(int requestId) async {
    await _remoteSource.rejectFriendRequest(requestId);
  }

  Future<void> cancelFriendRequest(int requestId) async {
    await _remoteSource.cancelFriendRequest(requestId);
  }

  Future<void> removeFriend(int targetUserId) async {
    await _remoteSource.removeFriend(targetUserId);
  }

  Future<void> blockUser(int targetUserId) async {
    await _remoteSource.blockUser(targetUserId);
  }

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
