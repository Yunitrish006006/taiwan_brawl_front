import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/friends_models.dart';
import '../../models/royale_models.dart';
import '../../services/api_client.dart';
import '../../services/friends_service.dart';
import '../../services/locale_provider.dart';
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
  List<FriendSearchResult> _searchResults = const [];
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
    final t = context.read<LocaleProvider>().translation;
    final decks = await _royaleService.fetchDecks();
    if (decks.isEmpty) {
      throw ApiException(t.text('Please create a deck first'));
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

  Future<void> _inviteFriendToBattle(SocialUser friend) async {
    await _runAction(
      'invite-${friend.userId}',
      () async {
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
          MaterialPageRoute(
            builder: (_) => RoyaleArenaPage(roomCode: room.code),
          ),
        );
      },
      successMessage: context.read<LocaleProvider>().translation.text(
        'Battle invite sent',
      ),
    );
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
    final t = context.read<LocaleProvider>().translation;
    switch (status) {
      case 'friend':
        return t.text('Already friends');
      case 'outgoing_pending':
        return t.text('Invitation already sent');
      case 'incoming_pending':
        return t.text('They invited you');
      case 'blocked':
        return t.text('You blocked them');
      case 'blocked_by_them':
        return t.text('Unable to join');
      case 'self':
        return t.text('This is you');
      default:
        return t.text('Not friends yet');
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
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          t.text('Search Players by Name'),
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
                                decoration: InputDecoration(
                                  labelText: t.text('Enter Player Name'),
                                  border: OutlineInputBorder(),
                                ),
                                onSubmitted: (_) => _searchByName(),
                              ),
                            ),
                            const SizedBox(width: 10),
                            FilledButton(
                              onPressed: _busyKey == 'search'
                                  ? null
                                  : _searchByName,
                              child: Text(
                                _busyKey == 'search'
                                    ? t.text('Searching...')
                                    : t.text('Search'),
                              ),
                            ),
                          ],
                        ),
                        if (_searchController.text.trim().isNotEmpty &&
                            _searchResults.isEmpty &&
                            _busyKey != 'search') ...[
                          const SizedBox(height: 16),
                          Text(t.text('No matching players found')),
                        ],
                        if (_searchResults.isNotEmpty) ...[
                          const SizedBox(height: 16),
                          Text(
                            '${_searchResults.length} ${t.text('people')}',
                            style: TextStyle(
                              color: Theme.of(
                                context,
                              ).colorScheme.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: 12),
                          ..._searchResults.map(
                            (result) => Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: _buildUserTile(
                                user: result.user,
                                subtitle:
                                    '${t.text('Relationship Status')}: ${_relationshipLabel(result.relationshipStatus)}',
                                actions: [
                                  if (result.relationshipStatus == 'none')
                                    FilledButton.icon(
                                      onPressed:
                                          _busyKey ==
                                              'send-${result.user.userId}'
                                          ? null
                                          : () => _runAction(
                                              'send-${result.user.userId}',
                                              () => _friendsService
                                                  .sendFriendRequest(
                                                    result.user.userId,
                                                  ),
                                              successMessage: t.text(
                                                'Friend request sent',
                                              ),
                                            ),
                                      icon: const Icon(Icons.person_add_alt_1),
                                      label: Text(t.text('Add Friend')),
                                    ),
                                  if (result.relationshipStatus == 'friend')
                                    OutlinedButton.icon(
                                      onPressed:
                                          _busyKey ==
                                              'invite-${result.user.userId}'
                                          ? null
                                          : () => _inviteFriendToBattle(
                                              result.user,
                                            ),
                                      icon: const Icon(
                                        Icons.sports_esports_outlined,
                                      ),
                                      label: Text(t.text('Invite Battle')),
                                    ),
                                  if (result.relationshipStatus != 'blocked')
                                    OutlinedButton.icon(
                                      onPressed:
                                          _busyKey ==
                                              'block-${result.user.userId}'
                                          ? null
                                          : () => _runAction(
                                              'block-${result.user.userId}',
                                              () => _friendsService.blockUser(
                                                result.user.userId,
                                              ),
                                              successMessage: t.text(
                                                'Player blocked',
                                              ),
                                            ),
                                      icon: const Icon(Icons.block),
                                      label: Text(t.text('Block')),
                                    ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                _buildSection(
                  t.text('Room Invites'),
                  overview.roomInvites.isEmpty
                      ? Text(t.text('No new room invites'))
                      : Column(
                          children: overview.roomInvites
                              .map(
                                (invite) => _buildUserTile(
                                  user: invite.inviter,
                                  subtitle:
                                      '${t.text('invites you to join room')} ${invite.roomCode}',
                                  actions: [
                                    FilledButton(
                                      onPressed:
                                          _busyKey == 'room-accept-${invite.id}'
                                          ? null
                                          : () => _acceptRoomInvite(invite),
                                      child: Text(t.text('Go to Room')),
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
                                      child: Text(t.text('Reject')),
                                    ),
                                  ],
                                ),
                              )
                              .toList(),
                        ),
                ),
                const SizedBox(height: 20),
                _buildSection(
                  t.text('Friend Requests'),
                  overview.incomingRequests.isEmpty
                      ? Text(t.text('No new friend requests'))
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
                                              successMessage: t.text(
                                                'You are now friends',
                                              ),
                                            ),
                                      child: Text(t.text('Accept')),
                                    ),
                                    OutlinedButton(
                                      onPressed: _busyKey == 'reject-${item.id}'
                                          ? null
                                          : () => _runAction(
                                              'reject-${item.id}',
                                              () => _friendsService
                                                  .rejectFriendRequest(item.id),
                                            ),
                                      child: Text(t.text('Reject')),
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
                                              successMessage: t.text(
                                                'Player blocked',
                                              ),
                                            ),
                                      child: Text(t.text('Block')),
                                    ),
                                  ],
                                ),
                              )
                              .toList(),
                        ),
                ),
                const SizedBox(height: 20),
                _buildSection(
                  t.text('Sent Requests'),
                  overview.outgoingRequests.isEmpty
                      ? Text(t.text('No pending requests'))
                      : Column(
                          children: overview.outgoingRequests
                              .map(
                                (item) => _buildUserTile(
                                  user: item.user,
                                  subtitle: t.text('Waiting for confirmation'),
                                  actions: [
                                    OutlinedButton(
                                      onPressed: _busyKey == 'cancel-${item.id}'
                                          ? null
                                          : () => _runAction(
                                              'cancel-${item.id}',
                                              () => _friendsService
                                                  .cancelFriendRequest(item.id),
                                            ),
                                      child: Text(t.text('Cancel')),
                                    ),
                                  ],
                                ),
                              )
                              .toList(),
                        ),
                ),
                const SizedBox(height: 20),
                _buildSection(
                  t.text('Friend List'),
                  overview.friends.isEmpty
                      ? Text(
                          t.text(
                            'You do not have any friends yet. Go add a few.',
                          ),
                        )
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
                                      label: Text(t.text('Invite Battle')),
                                    ),
                                    OutlinedButton.icon(
                                      onPressed:
                                          _busyKey == 'remove-${friend.userId}'
                                          ? null
                                          : () => _runAction(
                                              'remove-${friend.userId}',
                                              () => _friendsService
                                                  .removeFriend(friend.userId),
                                              successMessage: t.text(
                                                'Friend removed',
                                              ),
                                            ),
                                      icon: const Icon(
                                        Icons.person_remove_outlined,
                                      ),
                                      label: Text(t.text('Remove Friend')),
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
                                              successMessage: t.text(
                                                'Player blocked',
                                              ),
                                            ),
                                      icon: const Icon(Icons.block),
                                      label: Text(t.text('Block')),
                                    ),
                                  ],
                                ),
                              )
                              .toList(),
                        ),
                ),
                const SizedBox(height: 20),
                _buildSection(
                  t.text('Blocked Users'),
                  overview.blockedUsers.isEmpty
                      ? Text(t.text('No blocked players'))
                      : Column(
                          children: overview.blockedUsers
                              .map(
                                (user) => _buildUserTile(
                                  user: user,
                                  subtitle: t.text('Blocked'),
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
                                              successMessage: t.text(
                                                'Unblocked',
                                              ),
                                            ),
                                      child: Text(t.text('Unblock')),
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
