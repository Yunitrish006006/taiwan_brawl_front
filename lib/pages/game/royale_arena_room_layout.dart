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
                : Text(
                    friend.name.isEmpty ? '?' : friend.name.characters.first,
                  ),
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
                      : friend.lastActiveAt == null ||
                            friend.lastActiveAt!.isEmpty
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
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        _t.text('Friend List'),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    FilledButton.icon(
                      onPressed: _openFriendSearchDialog,
                      icon: const Icon(Icons.person_search_rounded, size: 18),
                      label: Text(_t.text('Search players')),
                      style: FilledButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                        backgroundColor: const Color(0xFFDDEBFF),
                        foregroundColor: const Color(0xFF184D8E),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 14),
                child: Text(
                  _canInviteFriendsFromDrawer
                      ? '${_t.text('Room')} ${widget.roomCode}'
                      : _t.text(
                          'Battle starts as soon as both players are ready',
                        ),
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

  Widget _buildDiscardDropZone({required bool compact}) {
    return _DiscardDropZone(
      discardable: _canAffordDiscard(_room?.me),
      label: _t.text('Discard'),
      costLabel: _discardCostLabel(),
      tooltip: _t.text('Drop here to discard'),
      compact: compact,
      onDiscard: _discardCard,
    );
  }

  Widget _buildHandCardList(
    RoyaleBattleView battle, {
    required bool compact,
    Axis scrollDirection = Axis.horizontal,
  }) {
    final vertical = scrollDirection == Axis.vertical;
    final children = battle.yourHand.map((card) {
      final playable = _canAffordCard(_room?.me, card);
      final selectionOrder = _selectedCardIds.indexOf(card.id);
      final handCard = _HandCard(
        key: ValueKey('hand-card-${card.id}'),
        card: card,
        playable: playable,
        selectedOrder: selectionOrder,
        cardColor: _cardColor(card.type),
        cardStats: _cardStats(card),
        typeLabel: _cardTypeLabel(card),
        costLabel: _cardEnergyLabel(card),
        costIcon: card.usesMoney
            ? Icons.attach_money_rounded
            : card.usesSpiritEnergy
            ? Icons.auto_awesome_rounded
            : Icons.bolt_rounded,
        costColor: card.usesMoney
            ? const Color(0xFFFFD166)
            : card.usesSpiritEnergy
            ? const Color(0xFFB388FF)
            : const Color(0xFF4FC3F7),
        insufficientLabel: _notEnoughEnergyMessageForType(
          _cardEnergyType(card),
        ),
        compact: compact,
      );

      return Padding(
        key: ValueKey(
          'hand-entry-${vertical ? 'vertical' : 'horizontal'}-${card.id}',
        ),
        padding: EdgeInsets.only(
          right: vertical ? 0 : (compact ? 10 : 14),
          bottom: vertical ? (compact ? 10 : 14) : 0,
        ),
        child: GestureDetector(
          onTap: () => _toggleCardSelection(card),
          child: Draggable<_ComboDragPayload>(
            data: _dragPayloadForHandCard(battle, card),
            maxSimultaneousDrags: 1,
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
    }).toList();

    return SingleChildScrollView(
      scrollDirection: scrollDirection,
      child: vertical ? Column(children: children) : Row(children: children),
    );
  }

  Widget _buildFloatingArenaActionButton({
    required IconData icon,
    required VoidCallback onTap,
    Color iconColor = Colors.white,
    Color? backgroundColor,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: (backgroundColor ?? const Color(0xFF07111F)).withValues(
          alpha: 0.74,
        ),
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
            child: Icon(icon, color: iconColor, size: 22),
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
                  icon: _showCollisionRadiusOverlay
                      ? Icons.blur_circular_rounded
                      : Icons.radio_button_unchecked_rounded,
                  iconColor: _showCollisionRadiusOverlay
                      ? const Color(0xFFFFD166)
                      : Colors.white,
                  backgroundColor: _showCollisionRadiusOverlay
                      ? const Color(0xFF3A2F12)
                      : null,
                  onTap: _toggleCollisionRadiusOverlay,
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
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              gradient: LinearGradient(
                colors: [
                  const Color(0xFF07111F).withValues(alpha: 0.82),
                  const Color(0xFF102030).withValues(alpha: 0.62),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _InfoChip(
                      icon: Icons.map_rounded,
                      label: _arenaDisplayName(room.arena),
                      compact: true,
                    ),
                    const SizedBox(width: 8),
                    _InfoChip(
                      icon: Icons.style_rounded,
                      label: battle.nextCardId ?? _t.text('Unknown'),
                      compact: true,
                    ),
                    if (selectedCards.isNotEmpty) ...[
                      const SizedBox(width: 8),
                      _InfoChip(
                        icon: Icons.layers_rounded,
                        label:
                            '${selectedCards.length} / ${_energyCostSummary(selectedCards)}',
                        compact: true,
                      ),
                    ],
                  ],
                ),
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
  }) {
    final me = _room?.me ?? _placeholderPlayer(_room?.viewerSide ?? 'left');
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
                        _DualEnergyMeter(
                          physicalEnergy: me.physicalEnergy,
                          spiritEnergy: me.spiritEnergy,
                          compact: true,
                        ),
                        const SizedBox(width: 8),
                        _buildDiscardDropZone(compact: true),
                        if (selectedCards.isNotEmpty) ...[
                          const SizedBox(width: 8),
                          _InfoChip(
                            icon: Icons.layers_rounded,
                            label:
                                '${_t.text('Selected Cards')} ${selectedCards.length} / ${_energyCostSummary(selectedCards)}',
                            compact: true,
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 10),
                    Expanded(child: _buildHandCardList(battle, compact: true)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImmersiveArenaSideOverlay({
    required RoyaleBattleView battle,
    required List<RoyaleCard> selectedCards,
  }) {
    final me = _room?.me ?? _placeholderPlayer(_room?.viewerSide ?? 'left');
    final nextCardText = battle.nextCardId == null
        ? _t.text('Unknown')
        : battle.nextCardId!;

    return _GlassPanel(
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
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  _t.text('Battle Hand'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              _buildDiscardDropZone(compact: true),
            ],
          ),
          const SizedBox(height: 10),
          _DualEnergyMeter(
            physicalEnergy: me.physicalEnergy,
            spiritEnergy: me.spiritEnergy,
            compact: true,
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _InfoChip(
                icon: Icons.style_rounded,
                label: nextCardText,
                compact: true,
              ),
              if (selectedCards.isNotEmpty)
                _InfoChip(
                  icon: Icons.layers_rounded,
                  label:
                      '${selectedCards.length} / ${_energyCostSummary(selectedCards)}',
                  compact: true,
                ),
            ],
          ),
          const SizedBox(height: 12),
          Expanded(
            child: _buildHandCardList(
              battle,
              compact: true,
              scrollDirection: Axis.vertical,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImmersiveArena({
    required RoyaleRoomSnapshot room,
    required RoyaleBattleView battle,
    required String mySide,
    required List<RoyaleCard> selectedCards,
    required BoxConstraints constraints,
  }) {
    final fallbackHeight = MediaQuery.sizeOf(context).height;
    final fallbackWidth = MediaQuery.sizeOf(context).width;
    final maxWidth = constraints.maxWidth.isFinite
        ? constraints.maxWidth
        : fallbackWidth;
    final useSideHand = maxWidth >= 900;
    final sideHandWidth = maxWidth >= 1100 ? 220.0 : 196.0;
    final sideHandRightPadding = useSideHand ? 10.0 : 0.0;
    final sideHandGap = useSideHand ? 12.0 : 0.0;
    final sideReservedWidth = useSideHand
        ? sideHandWidth + sideHandRightPadding + sideHandGap
        : 0.0;
    final topReservedHeight = _immersiveArenaTopReservedHeight(context);
    final safeBottom = MediaQuery.paddingOf(context).bottom;
    final bottomReservedHeight = useSideHand
        ? safeBottom + 10
        : _immersiveArenaBottomReservedHeight(context);
    final availableHeight = constraints.maxHeight.isFinite
        ? constraints.maxHeight
        : fallbackHeight;
    var boardHeight =
        availableHeight - topReservedHeight - bottomReservedHeight;
    if (boardHeight < 0) {
      boardHeight = 0;
    }
    final arenaAspectRatio = battle.arena.fieldAspectRatio <= 0
        ? battle_rules.fieldAspectRatio
        : battle.arena.fieldAspectRatio;
    var maxBoardWidth = maxWidth - sideReservedWidth;
    if (maxBoardWidth < 0) {
      maxBoardWidth = 0;
    }
    final fittedByHeightWidth = boardHeight * arenaAspectRatio;
    final boardWidth = fittedByHeightWidth <= maxBoardWidth
        ? fittedByHeightWidth
        : maxBoardWidth;
    boardHeight = arenaAspectRatio <= 0
        ? boardHeight
        : boardWidth / arenaAspectRatio;

    return Stack(
      fit: StackFit.expand,
      children: [
        AnimatedPositioned(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          top: topReservedHeight,
          left: 0,
          right: sideReservedWidth,
          bottom: bottomReservedHeight,
          child: _buildBattlefieldPanel(
            room: room,
            battle: battle,
            mySide: mySide,
            selectedCards: selectedCards,
            boardWidth: boardWidth,
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
        if (useSideHand)
          Positioned(
            top: topReservedHeight,
            right: sideHandRightPadding,
            bottom: safeBottom + 10,
            width: sideHandWidth,
            child: _buildImmersiveArenaSideOverlay(
              battle: battle,
              selectedCards: selectedCards,
            ),
          )
        else
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: _buildImmersiveArenaBottomOverlay(
              battle: battle,
              selectedCards: selectedCards,
            ),
          ),
      ],
    );
  }

  String _arenaDisplayName(battle_rules.BattleArenaConfig arena) {
    return switch (arena.id) {
      battle_rules.defaultArenaId => _t.text('Central Bridge'),
      battle_rules.doubleBridgeArenaId => _t.text('Double Bridge'),
      battle_rules.wideBridgeArenaId => _t.text('Wide Center Bridge'),
      battle_rules.sideBridgesArenaId => _t.text('Side Bridges'),
      battle_rules.tripleBridgeArenaId => _t.text('Three Bridge Crossing'),
      _ => arena.name,
    };
  }

  Widget _buildLobbyArenaPreview(RoyaleRoomSnapshot room) {
    final arena = room.arena;
    final bridgeCount = arena.terrainGates.fold<int>(
      0,
      (total, gate) => total + gate.passableLateralRanges.length,
    );
    final playerSide = room.viewerSide ?? 'left';
    final preview = ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border.all(color: Colors.white.withValues(alpha: 0.16)),
        ),
        child: AspectRatio(
          aspectRatio: arena.fieldAspectRatio,
          child: CustomPaint(
            painter: _ArenaPainter(playerSide: playerSide, arena: arena),
            child: const SizedBox.expand(),
          ),
        ),
      ),
    );
    final details = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.map_rounded, color: const Color(0xFFFFD166), size: 18),
            const SizedBox(width: 8),
            Text(
              _t.text('Random Map'),
              style: const TextStyle(
                color: Color(0xFFFFD166),
                fontWeight: FontWeight.w800,
                letterSpacing: 0.2,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          _arenaDisplayName(arena),
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _StatusPill(
              label: '${_t.text('Bridge')} x$bridgeCount',
              color: const Color(0xFF48C7F4),
            ),
            _StatusPill(
              label:
                  '${arena.width.round()} x ${arena.height.round()} ${_t.text('Arena')}',
              color: const Color(0xFF3ECF8E),
            ),
          ],
        ),
      ],
    );

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.09),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth >= 620) {
            return Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                SizedBox(width: 220, child: preview),
                const SizedBox(width: 18),
                Expanded(child: details),
              ],
            );
          }

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [preview, const SizedBox(height: 14), details],
          );
        },
      ),
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
                  _buildLobbyArenaPreview(room),
                  const SizedBox(height: 18),
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
                                const SizedBox(height: 4),
                                Text(
                                  player.hero.localizedName(
                                    context.watch<LocaleProvider>().locale,
                                  ),
                                  style: const TextStyle(
                                    color: Color(0xFFFFD166),
                                    fontWeight: FontWeight.w700,
                                    fontSize: 12,
                                  ),
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
    final mySide = room.viewerSide ?? 'left';
    final selectedCards = _selectedCards(battle);

    return LayoutBuilder(
      builder: (context, constraints) {
        return _buildImmersiveArena(
          room: room,
          battle: battle,
          mySide: mySide,
          selectedCards: selectedCards,
          constraints: constraints,
        );
      },
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
