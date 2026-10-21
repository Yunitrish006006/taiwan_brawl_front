import 'package:flutter/widgets.dart';

/// Host social capabilities used by the optional Mini Royale arena UI.
/// Identity, authentication, and friend persistence remain host-owned.
abstract class MiniRoyaleArenaSocialPort extends ChangeNotifier {
  bool get isLoading;
  List<MiniRoyaleArenaFriend> get friends;

  bool isFriend(int userId);
  bool hasOutgoingFriendRequest(int userId);
  Future<void> refresh();
  Future<void> sendRoomInvite({required String roomCode, required int userId});
  Future<void> sendFriendRequest(int userId);
  Future<void> openSearch({
    required BuildContext context,
    required void Function(String message) onMessage,
  });
}

class MiniRoyaleArenaFriend {
  const MiniRoyaleArenaFriend({
    required this.userId,
    required this.name,
    required this.avatarUrl,
    required this.lastActiveAt,
    required this.isOnline,
  });

  final int userId;
  final String name;
  final String? avatarUrl;
  final String? lastActiveAt;
  final bool isOnline;
}

class MiniRoyaleArenaSocialException implements Exception {
  const MiniRoyaleArenaSocialException(this.message);

  final String message;

  @override
  String toString() => message;
}
