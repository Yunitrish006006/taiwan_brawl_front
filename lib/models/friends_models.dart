class SocialUser {
  const SocialUser({
    required this.userId,
    required this.name,
    required this.bio,
    required this.avatarUrl,
    required this.lastActiveAt,
    required this.isOnline,
  });

  final int userId;
  final String name;
  final String bio;
  final String? avatarUrl;
  final String? lastActiveAt;
  final bool isOnline;

  factory SocialUser.fromJson(Map<String, dynamic> json) {
    return SocialUser(
      userId: (json['userId'] as num).toInt(),
      name: json['name'] as String? ?? 'Unknown',
      bio: json['bio'] as String? ?? '',
      avatarUrl: json['avatarUrl'] as String?,
      lastActiveAt: json['lastActiveAt'] as String?,
      isOnline: json['isOnline'] as bool? ?? false,
    );
  }
}

class FriendRequestItem {
  const FriendRequestItem({
    required this.id,
    required this.createdAt,
    required this.user,
  });

  final int id;
  final String createdAt;
  final SocialUser user;

  factory FriendRequestItem.fromJson(Map<String, dynamic> json) {
    return FriendRequestItem(
      id: (json['id'] as num).toInt(),
      createdAt: json['createdAt'] as String? ?? '',
      user: SocialUser.fromJson(json['user'] as Map<String, dynamic>),
    );
  }
}

class RoomInviteItem {
  const RoomInviteItem({
    required this.id,
    required this.roomCode,
    required this.createdAt,
    required this.inviter,
  });

  final int id;
  final String roomCode;
  final String createdAt;
  final SocialUser inviter;

  factory RoomInviteItem.fromJson(Map<String, dynamic> json) {
    return RoomInviteItem(
      id: (json['id'] as num).toInt(),
      roomCode: json['roomCode'] as String? ?? '',
      createdAt: json['createdAt'] as String? ?? '',
      inviter: SocialUser.fromJson(json['inviter'] as Map<String, dynamic>),
    );
  }
}

class FriendsOverview {
  const FriendsOverview({
    required this.friends,
    required this.incomingRequests,
    required this.outgoingRequests,
    required this.blockedUsers,
    required this.roomInvites,
  });

  final List<SocialUser> friends;
  final List<FriendRequestItem> incomingRequests;
  final List<FriendRequestItem> outgoingRequests;
  final List<SocialUser> blockedUsers;
  final List<RoomInviteItem> roomInvites;

  factory FriendsOverview.fromJson(Map<String, dynamic> json) {
    return FriendsOverview(
      friends: (json['friends'] as List<dynamic>? ?? const [])
          .map((item) => SocialUser.fromJson(item as Map<String, dynamic>))
          .toList(),
      incomingRequests: (json['incomingRequests'] as List<dynamic>? ?? const [])
          .map(
            (item) => FriendRequestItem.fromJson(item as Map<String, dynamic>),
          )
          .toList(),
      outgoingRequests: (json['outgoingRequests'] as List<dynamic>? ?? const [])
          .map(
            (item) => FriendRequestItem.fromJson(item as Map<String, dynamic>),
          )
          .toList(),
      blockedUsers: (json['blockedUsers'] as List<dynamic>? ?? const [])
          .map((item) => SocialUser.fromJson(item as Map<String, dynamic>))
          .toList(),
      roomInvites: (json['roomInvites'] as List<dynamic>? ?? const [])
          .map((item) => RoomInviteItem.fromJson(item as Map<String, dynamic>))
          .toList(),
    );
  }
}

class FriendSearchResult {
  const FriendSearchResult({
    required this.user,
    required this.relationshipStatus,
  });

  final SocialUser user;
  final String relationshipStatus;

  factory FriendSearchResult.fromJson(Map<String, dynamic> json) {
    return FriendSearchResult(
      user: SocialUser.fromJson(json['user'] as Map<String, dynamic>),
      relationshipStatus: json['relationshipStatus'] as String? ?? 'none',
    );
  }
}

class RoomInviteActionResult {
  const RoomInviteActionResult({required this.status, required this.roomCode});

  final String status;
  final String roomCode;

  factory RoomInviteActionResult.fromJson(Map<String, dynamic> json) {
    return RoomInviteActionResult(
      status: json['status'] as String? ?? '',
      roomCode: json['roomCode'] as String? ?? '',
    );
  }
}
