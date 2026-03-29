import '../models/friends_models.dart';
import 'api_client.dart';

class FriendsService {
  FriendsService(this._apiClient);

  final ApiClient _apiClient;

  Future<FriendsOverview> fetchOverview() async {
    final res = await _apiClient.getJson('/api/friends/overview');
    return FriendsOverview.fromJson(res);
  }

  Future<FriendSearchResult?> searchById(String playerId) async {
    final res = await _apiClient.getJson('/api/friends/search?id=$playerId');
    final result = res['result'] as Map<String, dynamic>?;
    if (result == null) {
      return null;
    }
    return FriendSearchResult.fromJson(result);
  }

  Future<void> sendFriendRequest(int targetUserId) async {
    await _apiClient.postJson('/api/friends/requests', {
      'targetUserId': targetUserId,
    });
  }

  Future<void> acceptFriendRequest(int requestId) async {
    await _apiClient.postJson('/api/friends/requests/$requestId/accept', {});
  }

  Future<void> rejectFriendRequest(int requestId) async {
    await _apiClient.postJson('/api/friends/requests/$requestId/reject', {});
  }

  Future<void> cancelFriendRequest(int requestId) async {
    await _apiClient.postJson('/api/friends/requests/$requestId/cancel', {});
  }

  Future<void> removeFriend(int targetUserId) async {
    await _apiClient.deleteJson('/api/friends/$targetUserId');
  }

  Future<void> blockUser(int targetUserId) async {
    await _apiClient.postJson('/api/friends/block', {
      'targetUserId': targetUserId,
    });
  }

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
