import 'package:user_social_system/user_social_system.dart';

import '../utils/remote_image_url.dart';
import 'api_client.dart';
import 'service_utils.dart';

class FriendsService implements FriendsDirectory {
  FriendsService(this._apiClient);

  final ApiClient _apiClient;

  @override
  Future<FriendsOverview> fetchOverview() async {
    final res = await _apiClient.getJson('/api/friends/overview');
    return FriendsOverview.fromJson(res, resolveAvatar: resolveRemoteImageUrl);
  }

  @override
  Future<List<FriendSearchResult>> searchByName(String query) async {
    final res = await _apiClient.getJson(
      buildApiPath('/api/friends/search', queryParameters: {'query': query}),
    );
    return jsonModelList(
      res,
      'results',
      (json) => FriendSearchResult.fromJson(
        json,
        resolveAvatar: resolveRemoteImageUrl,
      ),
    );
  }

  @override
  Future<void> sendFriendRequest(int targetUserId) async {
    await _apiClient.postJson('/api/friends/requests', {
      'targetUserId': targetUserId,
    });
  }

  @override
  Future<void> acceptFriendRequest(int requestId) async {
    await _apiClient.postJson('/api/friends/requests/$requestId/accept', {});
  }

  @override
  Future<void> rejectFriendRequest(int requestId) async {
    await _apiClient.postJson('/api/friends/requests/$requestId/reject', {});
  }

  @override
  Future<void> cancelFriendRequest(int requestId) async {
    await _apiClient.postJson('/api/friends/requests/$requestId/cancel', {});
  }

  @override
  Future<void> removeFriend(int targetUserId) async {
    await _apiClient.deleteJson('/api/friends/$targetUserId');
  }

  @override
  Future<void> blockUser(int targetUserId) async {
    await _apiClient.postJson('/api/friends/block', {
      'targetUserId': targetUserId,
    });
  }

  @override
  Future<void> unblockUser(int targetUserId) async {
    await _apiClient.deleteJson('/api/friends/block/$targetUserId');
  }

  Future<void> sendRoomInvite({
    required String roomCode,
    required int inviteeUserId,
  }) async {
    await _apiClient.postJson('/api/rooms/$roomCode/invite', {
      'inviteeUserId': inviteeUserId,
    });
  }

  Future<RoomInviteActionResult> acceptRoomInvite(int inviteId) async {
    final res = await _apiClient.postJson(
      '/api/room-invites/$inviteId/accept',
      {},
    );
    return RoomInviteActionResult.fromJson(res);
  }

  Future<void> rejectRoomInvite(int inviteId) async {
    await _apiClient.postJson('/api/room-invites/$inviteId/reject', {});
  }
}
