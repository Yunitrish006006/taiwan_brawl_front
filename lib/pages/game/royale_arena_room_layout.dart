part of 'royale_arena_page.dart';

extension _RoyaleArenaRoomLayout on _RoyaleArenaPageState {
  Widget _buildRoomFriendInviteTile(SocialUser friend) {
    final isBusy = _isFriendDrawerBusy('invite-${friend.userId}');
    final canInvite = _canInviteFriendsFromDrawer;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 18,
            backgroundImage:
                friend.avatarUrl != null && friend.avatarUrl!.isNotEmpty
                ? NetworkImage(friend.avatarUrl!)
                : null,
            child: friend.avatarUrl != null && friend.avatarUrl!.isNotEmpty
                ? null
                : Text(friend.name.isEmpty ? '?' : friend.name.characters.first),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  friend.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  friend.isOnline
                      ? _t.text('Online')
                      : friend.lastActiveAt == null || friend.lastActiveAt!.isEmpty
                      ? _t.text('Offline')
                      : '${_t.text('Last online')} ${friend.lastActiveAt}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ],
            ),
          ),
          if (canInvite) ...[
            const SizedBox(width: 12),
            _ArenaFriendInviteButton(
              label: _t.text('Invite Battle'),
              backgroundColor: const Color(0xFFDDEBFF),
              foregroundColor: const Color(0xFF184D8E),
              onTap: _friendDrawerBusyKey == null
                  ? () => _inviteFriendFromDrawer(friend)
                  : null,
              isLoading: isBusy,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildRoomFriendDrawer(FriendsOverview? overview) {
    final friends = overview?.friends ?? const <SocialUser>[];

    return Drawer(
      child: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF07111F), Color(0xFF0D1B2A), Color(0xFF14253A)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 10),
                child: Text(
                  _t.text('Friend List'),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 14),
                child: Text(
                  _canInviteFriendsFromDrawer
                      ? '${_t.text('Room')} ${widget.roomCode}'
                      : _t.text('Battle starts as soon as both players are ready'),
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ),
              if (overview == null)
                const Expanded(
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (friends.isEmpty)
                Expanded(
                  child: Center(
                    child: Text(
                      _t.text('No friends yet'),
                      style: const TextStyle(color: Colors.white70),
                    ),
                  ),
                )
              else
                Expanded(
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    itemCount: friends.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (context, index) =>
                        _buildRoomFriendInviteTile(friends[index]),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHandInfoChips(
    RoyaleBattleView battle,
    List<RoyaleCard> selectedCards,
    bool compact,
  ) {
    final selectedCost = _selectedCardCost(selectedCards);
    return Wrap(
      spacing: compact ? 8 : 12,
      runSpacing: compact ? 8 : 10,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Text(
          _t.text('Battle Hand'),
          style: (compact
                  ? Theme.of(context).textTheme.titleMedium
                  : Theme.of(context).textTheme.titleLarge)
              ?.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.w800,
          ),
        ),
        _InfoChip(
          icon: Icons.bolt_rounded,
          label:
              '${_t.text('Current Elixir')} ${battle.yourElixir.toStringAsFixed(1)}',
          compact: compact,
        ),
        _InfoChip(
          icon: Icons.arrow_forward_rounded,
          label: battle.nextCardId == null
              ? '${_t.text('Next Card')} ${_t.text('Unknown')}'
              : '${_t.text('Next Card')} ${battle.nextCardId}',
          compact: compact,
        ),
        if (selectedCards.isNotEmpty)
          _InfoChip(
            icon: Icons.layers_rounded,
            label:
                '${_t.text('Selected Cards')} ${selectedCards.length} / $selectedCost',
            compact: compact,
          ),
      ],
    );
  }

  Widget _buildHandCardList(RoyaleBattleView battle, {required bool compact}) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: battle.yourHand.map((card) {
          final playable = battle.yourElixir >= card.elixirCost;
          final selectionOrder = _selectedCardIds.indexOf(card.id);
          final handCard = _HandCard(
            card: card,
            playable: playable,
            selectedOrder: selectionOrder,
            cardColor: _cardColor(card.type),
            cardStats: _cardStats(card),
            typeLabel: _cardTypeLabel(card),
            compact: compact,
          );

          return Padding(
            padding: EdgeInsets.only(right: compact ? 10 : 14),
            child: GestureDetector(
              onTap: () => _toggleCardSelection(card),
              child: Draggable<_ComboDragPayload>(
                data: _dragPayloadForHandCard(battle, card),
                maxSimultaneousDrags: playable ? 1 : 0,
                dragAnchorStrategy: pointerDragAnchorStrategy,
                feedback: Material(
                  color: Colors.transparent,
                  child: const _DragCursorFeedback(),
                ),
                childWhenDragging: Opacity(opacity: 0.3, child: handCard),
                child: handCard,
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  String _commandDeckHintText(bool compact) {
    if (compact) {
      return _t.text(
        'Tap cards to build a combo, then drag a single card or combo onto the battlefield.',
      );
    }
    return _t.text(
      'Tap cards to build a combo first. Equipment cards apply to units cast together. Drag a single card or combo into your deployment zone.',
    );
  }

  Widget _buildFloatingArenaActionButton({
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF07111F).withValues(alpha: 0.74),
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF020817).withValues(alpha: 0.28),
            blurRadius: 14,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        shape: const CircleBorder(),
        child: InkWell(
          onTap: onTap,
          customBorder: const CircleBorder(),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Icon(icon, color: Colors.white, size: 22),
          ),
        ),
      ),
    );
  }

  double _immersiveArenaTopReservedHeight(BuildContext context) {
    return MediaQuery.paddingOf(context).top + 108;
  }

  double _immersiveArenaBottomReservedHeight(BuildContext context) {
    final safeBottom = MediaQuery.paddingOf(context).bottom;
    const trayHeight = 188.0;
    return safeBottom + 10 + trayHeight;
  }

  Widget _buildImmersiveArenaTopOverlay({
    required RoyaleRoomSnapshot room,
    required RoyaleBattleView battle,
    required List<RoyaleCard> selectedCards,
  }) {
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(10, 8, 10, 0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Builder(
                  builder: (context) => _buildFloatingArenaActionButton(
                    icon: Icons.groups_rounded,
                    onTap: () => Scaffold.of(context).openDrawer(),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _GlassPanel(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    gradient: LinearGradient(
                      colors: [
                        const Color(0xFF07111F).withValues(alpha: 0.84),
                        const Color(0xFF14253A).withValues(alpha: 0.7),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _formatTime(battle.timeRemainingMs),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${_t.text('Room')} ${room.code}',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.7),
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                _buildFloatingArenaActionButton(
                  icon: Icons.home_outlined,
                  onTap: () => Navigator.of(
                    context,
                  ).pushNamedAndRemoveUntil('/home', (_) => false),
                ),
              ],
            ),
            const SizedBox(height: 8),
            _GlassPanel(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              gradient: LinearGradient(
                colors: [
                  const Color(0xFF07111F).withValues(alpha: 0.82),
                  const Color(0xFF102030).withValues(alpha: 0.62),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.touch_app_rounded,
                    color: Color(0xFFFFD166),
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _battlefieldHintText(
                        _dragTargetActive,
                        selectedCards,
                        compact: true,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImmersiveArenaBottomOverlay({
    required RoyaleBattleView battle,
    required List<RoyaleCard> selectedCards,
    required int selectedCost,
  }) {
    final nextCardText = battle.nextCardId == null
        ? '${_t.text('Next Card')} ${_t.text('Unknown')}'
        : '${_t.text('Next Card')} ${battle.nextCardId}';
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              height: 188,
              child: _GlassPanel(
                padding: const EdgeInsets.fromLTRB(10, 10, 10, 12),
                gradient: LinearGradient(
                  colors: [
                    const Color(0xFF07111F).withValues(alpha: 0.9),
                    const Color(0xFF0D1B2A).withValues(alpha: 0.84),
                    const Color(0xFF17324A).withValues(alpha: 0.86),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _t.text('Battle Hand'),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                nextCardText,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.72),
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        _ElixirMeter(value: battle.yourElixir, compact: true),
                        if (selectedCards.isNotEmpty) ...[
                          const SizedBox(width: 8),
                          _InfoChip(
                            icon: Icons.layers_rounded,
                            label:
                                '${_t.text('Selected Cards')} ${selectedCards.length} / $selectedCost',
                            compact: true,
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 10),
                    Expanded(
                      child: _buildHandCardList(battle, compact: true),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImmersiveArena({
    required RoyaleRoomSnapshot room,
    required RoyaleBattleView battle,
    required String mySide,
    required List<RoyaleCard> selectedCards,
    required int selectedCost,
    required BoxConstraints constraints,
  }) {
    final fallbackHeight = MediaQuery.sizeOf(context).height;
    final topReservedHeight = _immersiveArenaTopReservedHeight(context);
    final bottomReservedHeight = _immersiveArenaBottomReservedHeight(context);
    final availableHeight = constraints.maxHeight.isFinite
        ? constraints.maxHeight
        : fallbackHeight;
    var boardHeight =
        availableHeight - topReservedHeight - bottomReservedHeight;
    if (boardHeight < 0) {
      boardHeight = 0;
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        AnimatedPositioned(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          top: topReservedHeight,
          left: 0,
          right: 0,
          bottom: bottomReservedHeight,
          child: _buildBattlefieldPanel(
            room: room,
            battle: battle,
            mySide: mySide,
            selectedCards: selectedCards,
            boardWidth: constraints.maxWidth,
            boardHeight: boardHeight,
            compact: true,
            fullscreen: true,
          ),
        ),
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: _buildImmersiveArenaTopOverlay(
            room: room,
            battle: battle,
            selectedCards: selectedCards,
          ),
        ),
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: _buildImmersiveArenaBottomOverlay(
            battle: battle,
            selectedCards: selectedCards,
            selectedCost: selectedCost,
          ),
        ),
      ],
    );
  }

  Widget _buildLobby(RoyaleRoomSnapshot room) {
    final myUserId = room.me?.userId;
    final isHostMode = room.simulationMode == 'host';
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 860),
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            _GlassPanel(
              padding: const EdgeInsets.all(24),
              gradient: const LinearGradient(
                colors: [
                  Color(0xFF0E223A),
                  Color(0xFF1C4261),
                  Color(0xFF266A66),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          'ROOM ${room.code}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.1,
                          ),
                        ),
                      ),
                      Text(
                        _t.text(
                          'Battle starts as soon as both players are ready',
                        ),
                        style: TextStyle(color: Colors.white70),
                      ),
                      _StatusPill(
                        label: isHostMode
                            ? _t.text('Host Simulation (Experimental)')
                            : _t.text('Server Simulation'),
                        color: isHostMode
                            ? const Color(0xFFB084F5)
                            : const Color(0xFF48C7F4),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  Text(
                    context.watch<LocaleProvider>().translation.text(
                      'Mini Royale Lobby',
                    ),
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 20),
                  ...room.players.map(
                    (player) => Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: _sideColor(player.side).withValues(alpha: 0.4),
                        ),
                      ),
                      child: Row(
                        children: [
                          _SideBadge(
                            side: player.side,
                            color: _sideColor(player.side),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  player.name,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 16,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  player.deckName,
                                  style: const TextStyle(color: Colors.white70),
                                ),
                              ],
                            ),
                          ),
                          _StatusPill(
                            label: player.ready
                                ? _t.text('Ready')
                                : _t.text('Waiting'),
                            color: player.ready
                                ? const Color(0xFF3ECF8E)
                                : const Color(0xFFF8B64C),
                          ),
                          const SizedBox(width: 8),
                          _StatusPill(
                            label: player.connected
                                ? _t.text('Online')
                                : _t.text('Offline'),
                            color: player.connected
                                ? const Color(0xFF48C7F4)
                                : const Color(0xFF7B8794),
                          ),
                          if (_shouldShowAddFriendButton(player, myUserId)) ...[
                            const SizedBox(width: 8),
                            TextButton.icon(
                              onPressed: () =>
                                  _sendFriendRequestToPlayer(player),
                              icon: const Icon(
                                Icons.person_add_alt_1,
                                size: 18,
                              ),
                              label: Text(_t.text('Add Friend Button')),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: _readySubmitting ? null : _sendReady,
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFFFFB703),
                        foregroundColor: const Color(0xFF1F2937),
                        padding: const EdgeInsets.symmetric(vertical: 18),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                        ),
                      ),
                      icon: const Icon(Icons.flash_on_rounded),
                      label: Text(
                        _readySubmitting
                            ? _t.text('Sending...')
                            : _t.text('Ready to Battle'),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildArena(RoyaleRoomSnapshot room) {
    final battle = room.battle!;
    final me = room.me;
    final opponent = room.opponent;
    final mySide = room.viewerSide ?? 'left';
    final selectedCards = _selectedCards(battle);
    final selectedCost = _selectedCardCost(selectedCards);

    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 880;
        final compactPhone = constraints.maxWidth < 600;
        if (compactPhone) {
          return _buildImmersiveArena(
            room: room,
            battle: battle,
            mySide: mySide,
            selectedCards: selectedCards,
            selectedCost: selectedCost,
            constraints: constraints,
          );
        }
        final boardWidth = _boardWidthFor(constraints, compact);
        final boardHeight = boardWidth / _battlefieldAspectRatio;
        final contentPadding = compact ? 14.0 : 20.0;
        final children = <Widget>[
          _buildHudSection(
            battle: battle,
            me: me,
            opponent: opponent,
            mySide: mySide,
            simulationMode: room.simulationMode,
            compact: compact,
          ),
          const SizedBox(height: 16),
          _buildBattlefieldPanel(
            room: room,
            battle: battle,
            mySide: mySide,
            selectedCards: selectedCards,
            boardWidth: boardWidth,
            boardHeight: boardHeight,
            compact: compact,
          ),
          const SizedBox(height: 12),
          _buildCommandDeck(
            battle: battle,
            compact: compact,
            selectedCards: selectedCards,
          ),
        ];
        return Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1200),
            child: ListView(
              padding: EdgeInsets.all(contentPadding),
              children: children,
            ),
          ),
        );
      },
    );
  }

  Widget _buildHudSection({
    required RoyaleBattleView battle,
    required RoyalePlayerView? me,
    required RoyalePlayerView? opponent,
    required String mySide,
    required String simulationMode,
    required bool compact,
  }) {
    return _GlassPanel(
      padding: EdgeInsets.all(compact ? 12 : 16),
      child: Column(
        children: [
          Wrap(
            spacing: 10,
            runSpacing: 10,
            alignment: WrapAlignment.center,
            children: [
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: compact ? 14 : 18,
                  vertical: compact ? 8 : 10,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.14),
                  ),
                ),
                child: Text(
                  _formatTime(battle.timeRemainingMs),
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: compact ? 22 : 28,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1,
                  ),
                ),
              ),
              _ElixirMeter(value: battle.yourElixir, compact: compact),
              _ArenaLegendChip(
                label: simulationMode == 'host'
                    ? _t.text('Host Simulation (Experimental)')
                    : _t.text('Server Simulation'),
                color: simulationMode == 'host'
                    ? const Color(0xFFB084F5)
                    : const Color(0xFF48C7F4),
                compact: compact,
              ),
              if (opponent != null &&
                  _shouldShowAddFriendButton(opponent, me?.userId))
                ActionChip(
                  avatar: Icon(
                    Icons.person_add_alt_1,
                    size: compact ? 16 : 18,
                  ),
                  label: Text(
                    '${_t.text('Add')} ${opponent.name} ${_t.text('as a friend')}',
                    style: TextStyle(fontSize: compact ? 11 : 13),
                  ),
                  onPressed: () => _sendFriendRequestToPlayer(opponent),
                  visualDensity: compact
                      ? const VisualDensity(
                          horizontal: -2,
                          vertical: -2,
                        )
                      : VisualDensity.standard,
                  materialTapTargetSize: compact
                      ? MaterialTapTargetSize.shrinkWrap
                      : MaterialTapTargetSize.padded,
                ),
              if (!compact) ...[
                _ArenaLegendChip(
                  label: _t.text('Single Lane Battle'),
                  color: const Color(0xFF46C2CB),
                ),
                _ArenaLegendChip(
                  label: _t.text('Up to 3-card combo'),
                  color: const Color(0xFFFFB703),
                ),
                _ArenaLegendChip(
                  label: _t.text('Equipment can stack'),
                  color: const Color(0xFF9B5DE5),
                ),
              ],
            ],
          ),
          SizedBox(height: compact ? 10 : 14),
          Row(
            children: [
              Expanded(
                child: _PlayerHudCard(
                  title: me?.name ?? _t.text('You'),
                  subtitle: mySide == 'left' ? 'Blue Side' : 'Red Side',
                  towerHp: me?.towerHp ?? 0,
                  maxTowerHp: me?.maxTowerHp ?? 1,
                  color: _sideColor(mySide),
                  alignEnd: false,
                  compact: compact,
                ),
              ),
              SizedBox(width: compact ? 8 : 14),
              Expanded(
                child: _PlayerHudCard(
                  title: opponent?.name ?? _t.text('Opponent'),
                  subtitle: mySide == 'left' ? 'Red Side' : 'Blue Side',
                  towerHp: opponent?.towerHp ?? 0,
                  maxTowerHp: opponent?.maxTowerHp ?? 1,
                  color: _sideColor(opponent?.side ?? 'right'),
                  alignEnd: true,
                  compact: compact,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCommandDeck({
    required RoyaleBattleView battle,
    required bool compact,
    required List<RoyaleCard> selectedCards,
  }) {
    return _GlassPanel(
      padding: EdgeInsets.fromLTRB(
        compact ? 12 : 16,
        compact ? 12 : 16,
        compact ? 12 : 16,
        compact ? 14 : 18,
      ),
      gradient: const LinearGradient(
        colors: [Color(0xFF0D1B2A), Color(0xFF132238), Color(0xFF1A2F48)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHandInfoChips(battle, selectedCards, compact),
          SizedBox(height: compact ? 12 : 16),
          _buildHandCardList(battle, compact: compact),
          SizedBox(height: compact ? 10 : 14),
          Text(
            _commandDeckHintText(compact),
            maxLines: compact ? 2 : 3,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.72),
              fontSize: compact ? 11 : 13,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPageContent(Map<String, String> t) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Text(_error!, style: const TextStyle(color: Colors.white)),
      );
    }
    if (_room == null) {
      return Center(
        child: Text(
          t.text('Room not found'),
          style: const TextStyle(color: Colors.white),
        ),
      );
    }

    return _room!.status == 'lobby' ? _buildLobby(_room!) : _buildArena(_room!);
  }
}
