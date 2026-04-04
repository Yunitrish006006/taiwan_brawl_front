import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/friends_models.dart';
import '../../models/royale_models.dart';
import '../../services/api_client.dart';
import '../../services/friends_service.dart';
import '../../services/locale_provider.dart';
import '../../services/royale_service.dart';
import '../game/royale_arena_page.dart';

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
  List<FriendSearchResult> _searchResults = const [];
  bool _isLoading = true;
  String? _busyKey;

  Map<String, String> get _t => context.read<LocaleProvider>().translation;

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
      _showSnackBar(e.message);
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
        _showSnackBar(successMessage);
      }
    } on ApiException catch (e) {
      _showSnackBar(e.message);
    } finally {
      if (mounted) {
        setState(() {
          _busyKey = null;
        });
      }
    }
  }

  Future<void> _searchByName() async {
    final input = _searchController.text.trim();
    if (input.isEmpty) {
      setState(() {
        _searchResults = const [];
      });
      return;
    }

    await _runAction('search', () async {
      final results = await _friendsService.searchByName(input);
      if (!mounted) {
        return;
      }
      setState(() {
        _searchResults = results;
      });
    });
  }

  Future<RoyaleDeck?> _pickDeck() async {
    final decks = await _royaleService.fetchDecks();
    if (decks.isEmpty) {
      throw ApiException(_t.text('Please create a deck first'));
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
        final t = context.watch<LocaleProvider>().translation;
        return AlertDialog(
          title: Text(t.text('Choose a deck to battle with')),
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
              child: Text(t.text('Cancel')),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(selected),
              child: Text(t.text('Confirm')),
            ),
          ],
        );
      },
    );
  }

  Future<void> _acceptRoomInvite(RoomInviteItem invite) async {
    await _runAction('room-accept-${invite.id}', () async {
      final deck = await _pickDeck();
      if (deck == null) {
        return;
      }
      final result = await _friendsService.acceptRoomInvite(invite.id);
      final room = await _royaleService.joinRoom(
        roomCode: result.roomCode,
        deckId: deck.id,
      );
      if (!mounted) {
        return;
      }
      await Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => RoyaleArenaPage(roomCode: room.code)),
      );
    });
  }

  String _relationshipLabel(String status) {
    switch (status) {
      case 'friend':
        return _t.text('Already friends');
      case 'outgoing_pending':
        return _t.text('Invitation already sent');
      case 'incoming_pending':
        return _t.text('They invited you');
      case 'blocked':
        return _t.text('You blocked them');
      case 'blocked_by_them':
        return _t.text('Unable to join');
      case 'self':
        return _t.text('This is you');
      default:
        return _t.text('Not friends yet');
    }
  }

  void _showSnackBar(String message) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  bool _isBusy(String key) => _busyKey == key;

  Widget _buildUserAvatar(SocialUser user) {
    if (user.avatarUrl != null && user.avatarUrl!.isNotEmpty) {
      return CircleAvatar(backgroundImage: NetworkImage(user.avatarUrl!));
    }

    return CircleAvatar(
      child: Text(user.name.isEmpty ? '?' : user.name.characters.first),
    );
  }

  Widget _buildAccentUserAvatar(
    SocialUser user, {
    Color backgroundColor = const Color(0xFF8A5A00),
  }) {
    if (user.avatarUrl != null && user.avatarUrl!.isNotEmpty) {
      return CircleAvatar(
        radius: 18,
        backgroundImage: NetworkImage(user.avatarUrl!),
      );
    }

    return CircleAvatar(
      radius: 18,
      backgroundColor: backgroundColor,
      child: Text(user.name.isEmpty ? '?' : user.name.characters.first),
    );
  }

  Widget _buildSectionBadge({
    required String label,
    required Color backgroundColor,
    required Color foregroundColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: foregroundColor,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _buildCompactActionButton({
    required IconData icon,
    required Color backgroundColor,
    required Color foregroundColor,
    required VoidCallback? onTap,
    bool isLoading = false,
  }) {
    final enabled = onTap != null && !isLoading;
    final effectiveForeground = enabled
        ? foregroundColor
        : foregroundColor.withValues(alpha: 0.45);

    return SizedBox(
      width: 36,
      height: 36,
      child: Material(
        color: enabled
            ? backgroundColor
            : backgroundColor.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          onTap: enabled ? onTap : null,
          borderRadius: BorderRadius.circular(10),
          child: Center(
            child: isLoading
                ? SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        effectiveForeground,
                      ),
                    ),
                  )
                : Icon(icon, size: 18, color: effectiveForeground),
          ),
        ),
      ),
    );
  }

  Widget _buildIncomingRequestCard(FriendRequestItem item) {
    final isAcceptBusy = _isBusy('accept-${item.id}');
    final isRejectBusy = _isBusy('reject-${item.id}');
    final isBlockBusy = _isBusy('block-${item.user.userId}');
    final isActionLocked =
        _busyKey != null && !isAcceptBusy && !isRejectBusy && !isBlockBusy;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF7E6),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFF2D28B)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          _buildAccentUserAvatar(item.user),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.user.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _t.text('They invited you'),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF8A5A00),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (item.user.bio.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    item.user.bio,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: 124,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                _buildCompactActionButton(
                  icon: Icons.block_rounded,
                  backgroundColor: const Color(0xFFF4E2E7),
                  foregroundColor: const Color(0xFF8C1D40),
                  onTap: isActionLocked
                      ? null
                      : () => _runAction(
                            'block-${item.user.userId}',
                            () => _friendsService.blockUser(item.user.userId),
                            successMessage: _t.text('Player blocked'),
                          ),
                  isLoading: isBlockBusy,
                ),
                const SizedBox(width: 8),
                _buildCompactActionButton(
                  icon: Icons.close_rounded,
                  backgroundColor: const Color(0xFFFFE1DE),
                  foregroundColor: const Color(0xFF9A2F22),
                  onTap: isActionLocked
                      ? null
                      : () => _runAction(
                            'reject-${item.id}',
                            () => _friendsService.rejectFriendRequest(item.id),
                          ),
                  isLoading: isRejectBusy,
                ),
                const SizedBox(width: 8),
                _buildCompactActionButton(
                  icon: Icons.check_rounded,
                  backgroundColor: const Color(0xFFDDF4E4),
                  foregroundColor: const Color(0xFF17663A),
                  onTap: isActionLocked
                      ? null
                      : () => _runAction(
                            'accept-${item.id}',
                            () => _friendsService.acceptFriendRequest(item.id),
                            successMessage: _t.text('You are now friends'),
                          ),
                  isLoading: isAcceptBusy,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFriendRoomInviteCard(SocialUser friend, RoomInviteItem invite) {
    final isAcceptBusy = _isBusy('room-accept-${invite.id}');
    final isRejectBusy = _isBusy('room-reject-${invite.id}');
    final isActionLocked = _busyKey != null && !isAcceptBusy && !isRejectBusy;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            _buildUserAvatar(friend),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    friend.name,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${_t.text('Room')} ${invite.roomCode}',
                    style: const TextStyle(
                      color: Color(0xFF184D8E),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            _buildCompactActionButton(
              icon: Icons.close_rounded,
              backgroundColor: const Color(0xFFFFE1DE),
              foregroundColor: const Color(0xFF9A2F22),
              onTap: isActionLocked
                  ? null
                  : () => _runAction(
                        'room-reject-${invite.id}',
                        () => _friendsService.rejectRoomInvite(invite.id),
                      ),
              isLoading: isRejectBusy,
            ),
            const SizedBox(width: 8),
            _buildCompactActionButton(
              icon: Icons.check_rounded,
              backgroundColor: const Color(0xFFDDF4E4),
              foregroundColor: const Color(0xFF17663A),
              onTap: isActionLocked ? null : () => _acceptRoomInvite(invite),
              isLoading: isAcceptBusy,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUserTile({
    required SocialUser user,
    required List<Widget> actions,
    String? subtitle,
  }) {
    final t = context.watch<LocaleProvider>().translation;
    final statusText = user.isOnline
        ? t.text('Online')
        : user.lastActiveAt == null || user.lastActiveAt!.isEmpty
        ? t.text('Offline')
        : '${t.text('Last online')} ${user.lastActiveAt}';

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

  Widget _buildTileColumn<T>(List<T> items, Widget Function(T item) builder) {
    return Column(
      children: items
          .map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: builder(item),
            ),
          )
          .toList(),
    );
  }

  Widget _buildSearchCard(Map<String, String> t) {
    final hasSearchInput = _searchController.text.trim().isNotEmpty;
    final showEmptySearchResult =
        hasSearchInput && _searchResults.isEmpty && _busyKey != 'search';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              t.text('Search Players by Name'),
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      labelText: t.text('Enter Player Name'),
                      border: const OutlineInputBorder(),
                    ),
                    onSubmitted: (_) => _searchByName(),
                  ),
                ),
                const SizedBox(width: 10),
                FilledButton(
                  onPressed: _busyKey == 'search' ? null : _searchByName,
                  child: Text(
                    _busyKey == 'search'
                        ? t.text('Searching...')
                        : t.text('Search'),
                  ),
                ),
              ],
            ),
            if (showEmptySearchResult) ...[
              const SizedBox(height: 16),
              Text(t.text('No matching players found')),
            ],
            if (_searchResults.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text(
                '${_searchResults.length} ${t.text('people')}',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 12),
              _buildTileColumn<FriendSearchResult>(
                _searchResults,
                (result) => _buildUserTile(
                  user: result.user,
                  subtitle:
                      '${t.text('Relationship Status')}: ${_relationshipLabel(result.relationshipStatus)}',
                  actions: _buildSearchActions(result),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildIncomingRequestSection(
    FriendsOverview overview,
    Map<String, String> t,
  ) {
    return _buildSection(
      t.text('Friend Requests'),
      overview.incomingRequests.isEmpty
          ? Text(t.text('No new friend requests'))
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSectionBadge(
                  label:
                      '${t.text('Friend Requests')} ${overview.incomingRequests.length}',
                  backgroundColor: const Color(0xFFFFF1CC),
                  foregroundColor: const Color(0xFF8A5A00),
                ),
                const SizedBox(height: 10),
                _buildTileColumn<FriendRequestItem>(
                  overview.incomingRequests,
                  _buildIncomingRequestCard,
                ),
              ],
            ),
    );
  }

  Widget _buildOutgoingRequestSection(
    FriendsOverview overview,
    Map<String, String> t,
  ) {
    return _buildSection(
      t.text('Sent Requests'),
      overview.outgoingRequests.isEmpty
          ? Text(t.text('No pending requests'))
          : _buildTileColumn<FriendRequestItem>(
              overview.outgoingRequests,
              (item) => _buildUserTile(
                user: item.user,
                subtitle: t.text('Waiting for confirmation'),
                actions: _buildOutgoingRequestActions(item),
              ),
            ),
    );
  }

  Widget _buildFriendListSection(
    FriendsOverview overview,
    Map<String, String> t,
  ) {
    final roomInviteByInviterUserId = <int, RoomInviteItem>{
      for (final invite in overview.roomInvites) invite.inviter.userId: invite,
    };

    return _buildSection(
      t.text('Friend List'),
      overview.friends.isEmpty
          ? Text(t.text('You do not have any friends yet. Go add a few.'))
          : _buildTileColumn<SocialUser>(
              overview.friends,
              (friend) {
                final roomInvite = roomInviteByInviterUserId[friend.userId];
                if (roomInvite != null) {
                  return _buildFriendRoomInviteCard(friend, roomInvite);
                }
                return _buildUserTile(
                  user: friend,
                  actions: _buildFriendActions(friend),
                );
              },
            ),
    );
  }

  Widget _buildBlockedUsersSection(
    FriendsOverview overview,
    Map<String, String> t,
  ) {
    return _buildSection(
      t.text('Blocked Users'),
      overview.blockedUsers.isEmpty
          ? Text(t.text('No blocked players'))
          : _buildTileColumn<SocialUser>(
              overview.blockedUsers,
              (user) => _buildUserTile(
                user: user,
                subtitle: t.text('Blocked'),
                actions: _buildBlockedUserActions(user),
              ),
            ),
    );
  }

  Widget _buildOverviewBody(FriendsOverview overview, Map<String, String> t) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildSearchCard(t),
        const SizedBox(height: 20),
        _buildIncomingRequestSection(overview, t),
        const SizedBox(height: 20),
        _buildOutgoingRequestSection(overview, t),
        const SizedBox(height: 20),
        _buildFriendListSection(overview, t),
        const SizedBox(height: 20),
        _buildBlockedUsersSection(overview, t),
      ],
    );
  }

  List<Widget> _buildSearchActions(FriendSearchResult result) {
    final user = result.user;
    return [
      if (result.relationshipStatus == 'none')
        FilledButton.icon(
          onPressed: _isBusy('send-${user.userId}')
              ? null
              : () => _runAction(
                  'send-${user.userId}',
                  () => _friendsService.sendFriendRequest(user.userId),
                  successMessage: _t.text('Friend request sent'),
                ),
          icon: const Icon(Icons.person_add_alt_1),
          label: Text(_t.text('Add Friend')),
        ),
      if (result.relationshipStatus != 'blocked')
        OutlinedButton.icon(
          onPressed: _isBusy('block-${user.userId}')
              ? null
              : () => _runAction(
                  'block-${user.userId}',
                  () => _friendsService.blockUser(user.userId),
                  successMessage: _t.text('Player blocked'),
                ),
          icon: const Icon(Icons.block),
          label: Text(_t.text('Block')),
        ),
    ];
  }

  List<Widget> _buildOutgoingRequestActions(FriendRequestItem item) {
    return [
      OutlinedButton(
        onPressed: _isBusy('cancel-${item.id}')
            ? null
            : () => _runAction(
                'cancel-${item.id}',
                () => _friendsService.cancelFriendRequest(item.id),
              ),
        child: Text(_t.text('Cancel')),
      ),
    ];
  }

  List<Widget> _buildFriendActions(SocialUser friend) {
    return [
      OutlinedButton.icon(
        onPressed: _isBusy('remove-${friend.userId}')
            ? null
            : () => _runAction(
                'remove-${friend.userId}',
                () => _friendsService.removeFriend(friend.userId),
                successMessage: _t.text('Friend removed'),
              ),
        icon: const Icon(Icons.person_remove_outlined),
        label: Text(_t.text('Remove Friend')),
      ),
      OutlinedButton.icon(
        onPressed: _isBusy('block-${friend.userId}')
            ? null
            : () => _runAction(
                'block-${friend.userId}',
                () => _friendsService.blockUser(friend.userId),
                successMessage: _t.text('Player blocked'),
              ),
        icon: const Icon(Icons.block),
        label: Text(_t.text('Block')),
      ),
    ];
  }

  List<Widget> _buildBlockedUserActions(SocialUser user) {
    return [
      OutlinedButton(
        onPressed: _isBusy('unblock-${user.userId}')
            ? null
            : () => _runAction(
                'unblock-${user.userId}',
                () => _friendsService.unblockUser(user.userId),
                successMessage: _t.text('Unblocked'),
              ),
        child: Text(_t.text('Unblock')),
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final t = context.watch<LocaleProvider>().translation;
    final overview = _overview;
    return Scaffold(
      appBar: AppBar(title: Text(t.text('Friends'))),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : overview == null
          ? Center(child: Text(t.text('Failed to load friend data')))
          : _buildOverviewBody(overview, t),
    );
  }
}
