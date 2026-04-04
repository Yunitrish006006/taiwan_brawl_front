import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/friends_models.dart';
import '../../models/royale_models.dart';
import '../../services/api_client.dart';
import '../../services/auth_service.dart';
import '../../services/friends_service.dart';
import '../../services/friends_overview_sync_service.dart';
import '../../services/locale_provider.dart';
import '../../services/royale_service.dart';
import '../../main.dart';
import '../game/royale_arena_page.dart';

class FriendsPage extends StatefulWidget {
  const FriendsPage({super.key});

  @override
  State<FriendsPage> createState() => _FriendsPageState();
}

class _FriendsPageState extends State<FriendsPage> with RouteAware {
  late final FriendsService _friendsService;
  late final RoyaleService _royaleService;
  final TextEditingController _searchController = TextEditingController();

  List<FriendSearchResult> _searchResults = const [];
  String? _busyKey;
  int? _overviewRequestedForUserId;
  PageRoute<dynamic>? _observedRoute;

  Map<String, String> get _t => context.read<LocaleProvider>().translation;

  @override
  void initState() {
    super.initState();
    final apiClient = ApiClient();
    _friendsService = FriendsService(apiClient);
    _royaleService = RoyaleService(apiClient);
  }

  @override
  void dispose() {
    if (_observedRoute != null) {
      appRouteObserver.unsubscribe(this);
    }
    _searchController.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route is PageRoute<dynamic> && route != _observedRoute) {
      if (_observedRoute != null) {
        appRouteObserver.unsubscribe(this);
      }
      _observedRoute = route;
      appRouteObserver.subscribe(this, route);
    }
    final auth = context.read<AuthService>();
    final userId = auth.user?.id;
    if (userId == null || userId == _overviewRequestedForUserId) {
      return;
    }
    _overviewRequestedForUserId = userId;
    unawaited(
      context.read<FriendsOverviewSyncService>().refreshFor(auth, silent: false),
    );
  }

  Future<void> _refreshFriendsOverview({bool silent = true}) async {
    await context.read<FriendsOverviewSyncService>().refreshFor(
      context.read<AuthService>(),
      silent: silent,
    );
  }

  @override
  void didPopNext() {
    unawaited(_refreshFriendsOverview(silent: false));
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
      if (!mounted) {
        return;
      }
      await _refreshFriendsOverview();
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

  bool _isCompactLayout(BuildContext context) =>
      MediaQuery.sizeOf(context).width < 640;

  bool _useStackedCardActions(BuildContext context) =>
      MediaQuery.sizeOf(context).width < 560;

  EdgeInsets _pagePadding(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    if (width < 420) {
      return const EdgeInsets.fromLTRB(12, 12, 12, 24);
    }
    if (width < 900) {
      return const EdgeInsets.fromLTRB(16, 16, 16, 28);
    }
    return const EdgeInsets.fromLTRB(20, 20, 20, 32);
  }

  ButtonStyle? _compactFilledButtonStyle(BuildContext context) {
    if (!_isCompactLayout(context)) {
      return null;
    }
    return FilledButton.styleFrom(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      visualDensity: const VisualDensity(horizontal: -2, vertical: -2),
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
  }

  ButtonStyle? _compactOutlinedButtonStyle(BuildContext context) {
    if (!_isCompactLayout(context)) {
      return null;
    }
    return OutlinedButton.styleFrom(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      visualDensity: const VisualDensity(horizontal: -2, vertical: -2),
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
  }

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
    final compact = _isCompactLayout(context);
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 8 : 10,
        vertical: compact ? 3 : 4,
      ),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: foregroundColor,
          fontSize: compact ? 11 : 12,
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
    final compact = _useStackedCardActions(context);
    final isAcceptBusy = _isBusy('accept-${item.id}');
    final isRejectBusy = _isBusy('reject-${item.id}');
    final isBlockBusy = _isBusy('block-${item.user.userId}');
    final isActionLocked =
        _busyKey != null && !isAcceptBusy && !isRejectBusy && !isBlockBusy;
    final blockAction = _buildCompactActionButton(
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
    );
    final rejectAction = _buildCompactActionButton(
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
    );
    final acceptAction = _buildCompactActionButton(
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
    );

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 10 : 12,
        vertical: compact ? 10 : 12,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF7E6),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFF2D28B)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
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
                      style: TextStyle(
                        fontSize: compact ? 15 : 16,
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
                        maxLines: compact ? 3 : 2,
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
              if (!compact) ...[
                const SizedBox(width: 12),
                SizedBox(
                  width: 124,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      blockAction,
                      const SizedBox(width: 8),
                      rejectAction,
                      const SizedBox(width: 8),
                      acceptAction,
                    ],
                  ),
                ),
              ],
            ],
          ),
          if (compact) ...[
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerRight,
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  blockAction,
                  rejectAction,
                  acceptAction,
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildFriendRoomInviteCard(SocialUser friend, RoomInviteItem invite) {
    final compact = _useStackedCardActions(context);
    final isAcceptBusy = _isBusy('room-accept-${invite.id}');
    final isRejectBusy = _isBusy('room-reject-${invite.id}');
    final isActionLocked = _busyKey != null && !isAcceptBusy && !isRejectBusy;
    final rejectAction = _buildCompactActionButton(
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
    );
    final acceptAction = _buildCompactActionButton(
      icon: Icons.check_rounded,
      backgroundColor: const Color(0xFFDDF4E4),
      foregroundColor: const Color(0xFF17663A),
      onTap: isActionLocked ? null : () => _acceptRoomInvite(invite),
      isLoading: isAcceptBusy,
    );

    return Card(
      child: Padding(
        padding: EdgeInsets.all(compact ? 10 : 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildUserAvatar(friend),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        friend.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: compact ? 15 : 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${_t.text('Room')} ${invite.roomCode}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Color(0xFF184D8E),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                if (!compact) ...[
                  const SizedBox(width: 12),
                  rejectAction,
                  const SizedBox(width: 8),
                  acceptAction,
                ],
              ],
            ),
            if (compact) ...[
              const SizedBox(height: 10),
              Align(
                alignment: Alignment.centerRight,
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [rejectAction, acceptAction],
                ),
              ),
            ],
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
    final compact = _isCompactLayout(context);
    final t = context.watch<LocaleProvider>().translation;
    final statusText = user.isOnline
        ? t.text('Online')
        : user.lastActiveAt == null || user.lastActiveAt!.isEmpty
        ? t.text('Offline')
        : '${t.text('Last online')} ${user.lastActiveAt}';

    return Card(
      child: Padding(
        padding: EdgeInsets.all(compact ? 10 : 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildUserAvatar(user),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        user.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: compact ? 15 : 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle ?? statusText,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: compact ? 12 : 14,
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
              SizedBox(height: compact ? 8 : 10),
              Text(
                user.bio,
                maxLines: compact ? 3 : 4,
                overflow: TextOverflow.ellipsis,
              ),
            ],
            if (actions.isNotEmpty) ...[
              SizedBox(height: compact ? 10 : 12),
              Wrap(spacing: 8, runSpacing: 8, children: actions),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSection(String title, Widget child) {
    final compact = _isCompactLayout(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: compact ? 17 : 18,
            fontWeight: FontWeight.w800,
          ),
        ),
        SizedBox(height: compact ? 8 : 10),
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
    final compact = _isCompactLayout(context);
    final hasSearchInput = _searchController.text.trim().isNotEmpty;
    final showEmptySearchResult =
        hasSearchInput && _searchResults.isEmpty && _busyKey != 'search';
    final searchField = TextField(
      controller: _searchController,
      textInputAction: TextInputAction.search,
      decoration: InputDecoration(
        labelText: t.text('Enter Player Name'),
        border: const OutlineInputBorder(),
      ),
      onSubmitted: (_) => _searchByName(),
    );
    final searchButton = FilledButton(
      onPressed: _busyKey == 'search' ? null : _searchByName,
      style: _compactFilledButtonStyle(context),
      child: Text(
        _busyKey == 'search' ? t.text('Searching...') : t.text('Search'),
      ),
    );

    return Card(
      child: Padding(
        padding: EdgeInsets.all(compact ? 12 : 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              t.text('Search Players by Name'),
              style: TextStyle(
                fontSize: compact ? 17 : 18,
                fontWeight: FontWeight.w800,
              ),
            ),
            SizedBox(height: compact ? 10 : 12),
            LayoutBuilder(
              builder: (context, constraints) {
                final stacked = compact || constraints.maxWidth < 520;
                if (stacked) {
                  return Column(
                    children: [
                      searchField,
                      const SizedBox(height: 10),
                      SizedBox(width: double.infinity, child: searchButton),
                    ],
                  );
                }
                return Row(
                  children: [
                    Expanded(child: searchField),
                    const SizedBox(width: 10),
                    searchButton,
                  ],
                );
              },
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
    final compact = _isCompactLayout(context);
    final sectionSpacing = compact ? 16.0 : 20.0;

    return RefreshIndicator(
      onRefresh: () => _refreshFriendsOverview(silent: false),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: _pagePadding(context),
        children: [
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 920),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildSearchCard(t),
                  SizedBox(height: sectionSpacing),
                  _buildIncomingRequestSection(overview, t),
                  SizedBox(height: sectionSpacing),
                  _buildOutgoingRequestSection(overview, t),
                  SizedBox(height: sectionSpacing),
                  _buildFriendListSection(overview, t),
                  SizedBox(height: sectionSpacing),
                  _buildBlockedUsersSection(overview, t),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildSearchActions(FriendSearchResult result) {
    final compactFilledStyle = _compactFilledButtonStyle(context);
    final compactOutlinedStyle = _compactOutlinedButtonStyle(context);
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
          style: compactFilledStyle,
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
          style: compactOutlinedStyle,
          icon: const Icon(Icons.block),
          label: Text(_t.text('Block')),
        ),
    ];
  }

  List<Widget> _buildOutgoingRequestActions(FriendRequestItem item) {
    final compactOutlinedStyle = _compactOutlinedButtonStyle(context);
    return [
      OutlinedButton(
        onPressed: _isBusy('cancel-${item.id}')
            ? null
            : () => _runAction(
                'cancel-${item.id}',
                () => _friendsService.cancelFriendRequest(item.id),
              ),
        style: compactOutlinedStyle,
        child: Text(_t.text('Cancel')),
      ),
    ];
  }

  List<Widget> _buildFriendActions(SocialUser friend) {
    final compactOutlinedStyle = _compactOutlinedButtonStyle(context);
    return [
      OutlinedButton.icon(
        onPressed: _isBusy('remove-${friend.userId}')
            ? null
            : () => _runAction(
                'remove-${friend.userId}',
                () => _friendsService.removeFriend(friend.userId),
                successMessage: _t.text('Friend removed'),
              ),
        style: compactOutlinedStyle,
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
        style: compactOutlinedStyle,
        icon: const Icon(Icons.block),
        label: Text(_t.text('Block')),
      ),
    ];
  }

  List<Widget> _buildBlockedUserActions(SocialUser user) {
    final compactOutlinedStyle = _compactOutlinedButtonStyle(context);
    return [
      OutlinedButton(
        onPressed: _isBusy('unblock-${user.userId}')
            ? null
            : () => _runAction(
                'unblock-${user.userId}',
                () => _friendsService.unblockUser(user.userId),
                successMessage: _t.text('Unblocked'),
              ),
        style: compactOutlinedStyle,
        child: Text(_t.text('Unblock')),
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final t = context.watch<LocaleProvider>().translation;
    final friendsSync = context.watch<FriendsOverviewSyncService>();
    final overview = friendsSync.overview;
    return Scaffold(
      appBar: AppBar(title: Text(t.text('Friends'))),
      body: friendsSync.isLoading && overview == null
          ? const Center(child: CircularProgressIndicator())
          : overview == null
          ? Center(child: Text(t.text('Failed to load friend data')))
          : _buildOverviewBody(overview, t),
    );
  }
}
