import 'api_client.dart';
import 'service_utils.dart';

abstract interface class FriendsRemoteSource {
  Future<Map<String, dynamic>> fetchOverview();

  Future<Map<String, dynamic>> searchByName(String query);

  Future<void> sendFriendRequest(int targetUserId);

  Future<void> acceptFriendRequest(int requestId);

  Future<void> rejectFriendRequest(int requestId);

  Future<void> cancelFriendRequest(int requestId);

  Future<void> removeFriend(int targetUserId);

  Future<void> blockUser(int targetUserId);

  Future<void> unblockUser(int targetUserId);

  Future<void> sendRoomInvite({
    required String gameId,
    required String roomCode,
    required int inviteeUserId,
  });

  Future<Map<String, dynamic>> acceptRoomInvite(int inviteId);

  Future<void> rejectRoomInvite(int inviteId);
}

class ServerFriendsRemoteSource implements FriendsRemoteSource {
  const ServerFriendsRemoteSource(this._apiClient);

  final ApiClient _apiClient;

  @override
  Future<Map<String, dynamic>> fetchOverview() {
    return _apiClient.getJson('/api/friends/overview');
  }

  @override
  Future<Map<String, dynamic>> searchByName(String query) {
    return _apiClient.getJson(
      buildApiPath('/api/friends/search', queryParameters: {'query': query}),
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

  @override
  Future<void> sendRoomInvite({
    required String gameId,
    required String roomCode,
    required int inviteeUserId,
  }) async {
    final moduleSlug = gameId.startsWith('game.')
        ? gameId.substring('game.'.length)
        : '';
    if (!RegExp(r'^[a-z0-9]+(?:-[a-z0-9]+)*$').hasMatch(moduleSlug)) {
      throw ArgumentError.value(gameId, 'gameId', 'Invalid game API identity');
    }
    await _apiClient.postJson(
      '/api/games/$moduleSlug/v1/rooms/$roomCode/invite',
      {'inviteeUserId': inviteeUserId},
    );
  }

  @override
  Future<Map<String, dynamic>> acceptRoomInvite(int inviteId) {
    return _apiClient.postJson('/api/room-invites/$inviteId/accept', {});
  }

  @override
  Future<void> rejectRoomInvite(int inviteId) async {
    await _apiClient.postJson('/api/room-invites/$inviteId/reject', {});
  }
}
