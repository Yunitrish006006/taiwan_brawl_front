import 'package:flutter/material.dart';

import '../../models/friends_models.dart';
import '../../models/royale_models.dart';
import '../../services/api_client.dart';
import '../../services/friends_service.dart';
import '../../services/royale_service.dart';
import '../game/royale_arena_page.dart';
import '../game/royale_lobby_page.dart';

class FriendsPage extends StatefulWidget {
  const FriendsPage({super.key});

  @override
  State<FriendsPage> createState() => _FriendsPageState();
}

class _FriendsPageState extends State<FriendsPage> {
  late final FriendsService _friendsService;
  late final RoyaleService _royaleService;
  final TextEditingController _searchController = TextEditingController();

  FriendsOverview? _overview;
  FriendSearchResult? _searchResult;
  bool _isLoading = true;
  String? _busyKey;

  @override
  void initState() {
    super.initState();
    final apiClient = ApiClient();
    _friendsService = FriendsService(apiClient);
    _royaleService = RoyaleService(apiClient);
    _loadOverview();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadOverview() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final overview = await _friendsService.fetchOverview();
      if (!mounted) {
        return;
      }
      setState(() {
        _overview = overview;
      });
    } on ApiException catch (e) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _runAction(
    String busyKey,
    Future<void> Function() action, {
    String? successMessage,
  }) async {
    setState(() {
      _busyKey = busyKey;
    });

    try {
      await action();
      await _loadOverview();
      if (!mounted) {
        return;
      }
      if (successMessage != null) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(successMessage)));
      }
    } on ApiException catch (e) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) {
        setState(() {
          _busyKey = null;
        });
      }
    }
  }

  Future<void> _searchById() async {
    final input = _searchController.text.trim();
    if (input.isEmpty) {
      setState(() {
        _searchResult = null;
      });
      return;
    }

    await _runAction('search', () async {
      final result = await _friendsService.searchById(input);
      if (!mounted) {
        return;
      }
      setState(() {
        _searchResult = result;
      });
    });
  }

  Future<RoyaleDeck?> _pickDeck() async {
    final decks = await _royaleService.fetchDecks();
    if (decks.isEmpty) {
      throw ApiException('請先建立一組 Mini Royale 牌組');
    }
    if (decks.length == 1) {
      return decks.first;
    }

    RoyaleDeck selected = decks.first;
    if (!mounted) {
      return null;
    }
    return showDialog<RoyaleDeck>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('選擇要出戰的牌組'),
          content: StatefulBuilder(
            builder: (context, setState) {
              return DropdownButtonFormField<RoyaleDeck>(
                initialValue: selected,
                items: decks
                    .map(
                      (deck) => DropdownMenuItem<RoyaleDeck>(
                        value: deck,
                        child: Text(deck.name),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  if (value == null) {
                    return;
                  }
                  setState(() {
                    selected = value;
                  });
                },
              );
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(selected),
              child: const Text('確認'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _inviteFriendToBattle(SocialUser friend) async {
    await _runAction('invite-${friend.userId}', () async {
      final deck = await _pickDeck();
      if (deck == null) {
        return;
      }
      final room = await _royaleService.createRoom(deckId: deck.id);
      await _friendsService.sendRoomInvite(
        roomCode: room.code,
        inviteeUserId: friend.userId,
      );
      if (!mounted) {
        return;
      }
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => RoyaleArenaPage(roomCode: room.code)),
      );
    }, successMessage: '已送出對戰邀請');
  }

  Future<void> _acceptRoomInvite(RoomInviteItem invite) async {
    await _runAction('room-accept-${invite.id}', () async {
      final result = await _friendsService.acceptRoomInvite(invite.id);
      if (!mounted) {
        return;
      }
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => RoyaleLobbyPage(initialRoomCode: result.roomCode),
        ),
      );
    });
  }

  String _relationshipLabel(String status) {
    switch (status) {
      case 'friend':
        return '已是好友';
      case 'outgoing_pending':
        return '已送出邀請';
      case 'incoming_pending':
        return '對方已邀請你';
      case 'blocked':
        return '你已封鎖';
      case 'blocked_by_them':
        return '無法加入';
      case 'self':
        return '這是你自己';
      default:
        return '尚未成為好友';
    }
  }

  Widget _buildUserAvatar(SocialUser user) {
    if (user.avatarUrl != null && user.avatarUrl!.isNotEmpty) {
      return CircleAvatar(backgroundImage: NetworkImage(user.avatarUrl!));
    }

    return CircleAvatar(
      child: Text(user.name.isEmpty ? '?' : user.name.characters.first),
    );
  }

  Widget _buildUserTile({
    required SocialUser user,
    required List<Widget> actions,
    String? subtitle,
  }) {
    final statusText = user.isOnline
        ? '在線中'
        : user.lastActiveAt == null || user.lastActiveAt!.isEmpty
        ? '離線'
        : '最後上線 ${user.lastActiveAt}';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Row(
              children: [
                _buildUserAvatar(user),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        user.name,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text('ID ${user.userId}'),
                      const SizedBox(height: 2),
                      Text(
                        subtitle ?? statusText,
                        style: TextStyle(
                          color: user.isOnline
                              ? const Color(0xFF0F8B6D)
                              : Colors.grey.shade700,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (user.bio.isNotEmpty) ...[
              const SizedBox(height: 10),
              Align(alignment: Alignment.centerLeft, child: Text(user.bio)),
            ],
            if (actions.isNotEmpty) ...[
              const SizedBox(height: 12),
              Wrap(spacing: 8, runSpacing: 8, children: actions),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSection(String title, Widget child) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 10),
        child,
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final overview = _overview;
    return Scaffold(
      appBar: AppBar(title: const Text('好友系統')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : overview == null
          ? const Center(child: Text('載入好友資料失敗'))
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          '搜尋玩家 ID',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _searchController,
                                keyboardType: TextInputType.number,
                                decoration: const InputDecoration(
                                  labelText: '輸入玩家 ID',
                                  border: OutlineInputBorder(),
                                ),
                                onSubmitted: (_) => _searchById(),
                              ),
                            ),
                            const SizedBox(width: 10),
                            FilledButton(
                              onPressed: _busyKey == 'search'
                                  ? null
                                  : _searchById,
                              child: Text(
                                _busyKey == 'search' ? '搜尋中...' : '搜尋',
                              ),
                            ),
                          ],
                        ),
                        if (_searchResult != null) ...[
                          const SizedBox(height: 16),
                          _buildUserTile(
                            user: _searchResult!.user,
                            subtitle:
                                '關係狀態: ${_relationshipLabel(_searchResult!.relationshipStatus)}',
                            actions: [
                              if (_searchResult!.relationshipStatus == 'none')
                                FilledButton.icon(
                                  onPressed:
                                      _busyKey ==
                                          'send-${_searchResult!.user.userId}'
                                      ? null
                                      : () => _runAction(
                                          'send-${_searchResult!.user.userId}',
                                          () =>
                                              _friendsService.sendFriendRequest(
                                                _searchResult!.user.userId,
                                              ),
                                          successMessage: '好友邀請已送出',
                                        ),
                                  icon: const Icon(Icons.person_add_alt_1),
                                  label: const Text('加好友'),
                                ),
                              if (_searchResult!.relationshipStatus == 'friend')
                                OutlinedButton.icon(
                                  onPressed:
                                      _busyKey ==
                                          'invite-${_searchResult!.user.userId}'
                                      ? null
                                      : () => _inviteFriendToBattle(
                                          _searchResult!.user,
                                        ),
                                  icon: const Icon(
                                    Icons.sports_esports_outlined,
                                  ),
                                  label: const Text('邀請對戰'),
                                ),
                              if (_searchResult!.relationshipStatus !=
                                  'blocked')
                                OutlinedButton.icon(
                                  onPressed:
                                      _busyKey ==
                                          'block-${_searchResult!.user.userId}'
                                      ? null
                                      : () => _runAction(
                                          'block-${_searchResult!.user.userId}',
                                          () => _friendsService.blockUser(
                                            _searchResult!.user.userId,
                                          ),
                                          successMessage: '已封鎖玩家',
                                        ),
                                  icon: const Icon(Icons.block),
                                  label: const Text('封鎖'),
                                ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                _buildSection(
                  '房間邀請',
                  overview.roomInvites.isEmpty
                      ? const Text('目前沒有新的房間邀請')
                      : Column(
                          children: overview.roomInvites
                              .map(
                                (invite) => _buildUserTile(
                                  user: invite.inviter,
                                  subtitle: '邀你加入房間 ${invite.roomCode}',
                                  actions: [
                                    FilledButton(
                                      onPressed:
                                          _busyKey == 'room-accept-${invite.id}'
                                          ? null
                                          : () => _acceptRoomInvite(invite),
                                      child: const Text('前往房間'),
                                    ),
                                    OutlinedButton(
                                      onPressed:
                                          _busyKey == 'room-reject-${invite.id}'
                                          ? null
                                          : () => _runAction(
                                              'room-reject-${invite.id}',
                                              () => _friendsService
                                                  .rejectRoomInvite(invite.id),
                                            ),
                                      child: const Text('拒絕'),
                                    ),
                                  ],
                                ),
                              )
                              .toList(),
                        ),
                ),
                const SizedBox(height: 20),
                _buildSection(
                  '好友邀請',
                  overview.incomingRequests.isEmpty
                      ? const Text('目前沒有新的好友邀請')
                      : Column(
                          children: overview.incomingRequests
                              .map(
                                (item) => _buildUserTile(
                                  user: item.user,
                                  actions: [
                                    FilledButton(
                                      onPressed: _busyKey == 'accept-${item.id}'
                                          ? null
                                          : () => _runAction(
                                              'accept-${item.id}',
                                              () => _friendsService
                                                  .acceptFriendRequest(item.id),
                                              successMessage: '已成為好友',
                                            ),
                                      child: const Text('接受'),
                                    ),
                                    OutlinedButton(
                                      onPressed: _busyKey == 'reject-${item.id}'
                                          ? null
                                          : () => _runAction(
                                              'reject-${item.id}',
                                              () => _friendsService
                                                  .rejectFriendRequest(item.id),
                                            ),
                                      child: const Text('拒絕'),
                                    ),
                                    OutlinedButton(
                                      onPressed:
                                          _busyKey ==
                                              'block-${item.user.userId}'
                                          ? null
                                          : () => _runAction(
                                              'block-${item.user.userId}',
                                              () => _friendsService.blockUser(
                                                item.user.userId,
                                              ),
                                              successMessage: '已封鎖玩家',
                                            ),
                                      child: const Text('封鎖'),
                                    ),
                                  ],
                                ),
                              )
                              .toList(),
                        ),
                ),
                const SizedBox(height: 20),
                _buildSection(
                  '已送出的邀請',
                  overview.outgoingRequests.isEmpty
                      ? const Text('目前沒有待確認的邀請')
                      : Column(
                          children: overview.outgoingRequests
                              .map(
                                (item) => _buildUserTile(
                                  user: item.user,
                                  subtitle: '等待對方確認中',
                                  actions: [
                                    OutlinedButton(
                                      onPressed: _busyKey == 'cancel-${item.id}'
                                          ? null
                                          : () => _runAction(
                                              'cancel-${item.id}',
                                              () => _friendsService
                                                  .cancelFriendRequest(item.id),
                                            ),
                                      child: const Text('取消邀請'),
                                    ),
                                  ],
                                ),
                              )
                              .toList(),
                        ),
                ),
                const SizedBox(height: 20),
                _buildSection(
                  '好友列表',
                  overview.friends.isEmpty
                      ? const Text('你還沒有好友，先去加幾位吧')
                      : Column(
                          children: overview.friends
                              .map(
                                (friend) => _buildUserTile(
                                  user: friend,
                                  actions: [
                                    FilledButton.icon(
                                      onPressed:
                                          _busyKey == 'invite-${friend.userId}'
                                          ? null
                                          : () => _inviteFriendToBattle(friend),
                                      icon: const Icon(
                                        Icons.sports_esports_outlined,
                                      ),
                                      label: const Text('邀請對戰'),
                                    ),
                                    OutlinedButton.icon(
                                      onPressed:
                                          _busyKey == 'remove-${friend.userId}'
                                          ? null
                                          : () => _runAction(
                                              'remove-${friend.userId}',
                                              () => _friendsService
                                                  .removeFriend(friend.userId),
                                              successMessage: '已移除好友',
                                            ),
                                      icon: const Icon(
                                        Icons.person_remove_outlined,
                                      ),
                                      label: const Text('移除好友'),
                                    ),
                                    OutlinedButton.icon(
                                      onPressed:
                                          _busyKey == 'block-${friend.userId}'
                                          ? null
                                          : () => _runAction(
                                              'block-${friend.userId}',
                                              () => _friendsService.blockUser(
                                                friend.userId,
                                              ),
                                              successMessage: '已封鎖玩家',
                                            ),
                                      icon: const Icon(Icons.block),
                                      label: const Text('封鎖'),
                                    ),
                                  ],
                                ),
                              )
                              .toList(),
                        ),
                ),
                const SizedBox(height: 20),
                _buildSection(
                  '封鎖名單',
                  overview.blockedUsers.isEmpty
                      ? const Text('目前沒有封鎖任何玩家')
                      : Column(
                          children: overview.blockedUsers
                              .map(
                                (user) => _buildUserTile(
                                  user: user,
                                  subtitle: '已封鎖',
                                  actions: [
                                    OutlinedButton(
                                      onPressed:
                                          _busyKey == 'unblock-${user.userId}'
                                          ? null
                                          : () => _runAction(
                                              'unblock-${user.userId}',
                                              () => _friendsService.unblockUser(
                                                user.userId,
                                              ),
                                              successMessage: '已解除封鎖',
                                            ),
                                      child: const Text('解除封鎖'),
                                    ),
                                  ],
                                ),
                              )
                              .toList(),
                        ),
                ),
              ],
            ),
    );
  }
}
