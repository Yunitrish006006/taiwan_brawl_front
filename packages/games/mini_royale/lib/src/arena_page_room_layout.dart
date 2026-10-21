part of 'mini_royale_arena_page.dart';

extension _RoyaleArenaRoomLayout on _MiniRoyaleArenaPageState {
  Widget _buildRoomFriendInviteTile(MiniRoyaleArenaFriend friend) {
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

  Widget _buildRoomFriendDrawer(MiniRoyaleArenaSocialPort social) {
    final friends = social.friends;

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
              if (social.isLoading)
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
    return MiniRoyaleDiscardDropZone<MiniRoyaleCardDragPayload>(
      cardForPayload: (payload) => payload.draggedCard,
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
      final playable = MiniRoyaleBattleSelection.canAffordCard(_room?.me, card);
      final selectionOrder = _battleSelection.selectedIds.indexOf(card.id);
      final handCard = MiniRoyaleHandCard(
        key: ValueKey('hand-card-${card.id}'),
        card: card,
        name: card.localizedName(
          context.read<MiniRoyaleLocalizationPort>().locale,
        ),
        playable: playable,
        selectedOrder: selectionOrder,
        cardStats: MiniRoyaleHandCardContent.stats(card, (key) => _t.text(key)),
        typeLabel: MiniRoyaleHandCardContent.typeLabel(
          card,
          (key) => _t.text(key),
        ),
        costLabel: MiniRoyaleHandCardContent.energyLabel(
          card,
          shortEnergyLabel: _energyTypeShortLabel,
        ),
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
          miniRoyaleCardEnergyType(card),
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
          child: Draggable<MiniRoyaleCardDragPayload>(
            data: _dragPayloadForHandCard(battle, card),
            maxSimultaneousDrags: 1,
            dragAnchorStrategy: pointerDragAnchorStrategy,
            feedback: Material(
              color: Colors.transparent,
              child: const MiniRoyaleAimMarker(
                point: Offset(0.5, 0.5),
                active: true,
                showLabel: false,
              ),
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
                  onTap: widget.onExitToHome,
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
  }) {
    return MiniRoyaleImmersiveBattleLayout(
      fieldAspectRatio: battle.arena.fieldAspectRatio,
      fieldBuilder: (context, fieldWidth, fieldHeight) =>
          _buildBattlefieldPanel(
            room: room,
            battle: battle,
            mySide: mySide,
            selectedCards: selectedCards,
            boardWidth: fieldWidth,
            boardHeight: fieldHeight,
            compact: true,
            fullscreen: true,
          ),
      topOverlay: _buildImmersiveArenaTopOverlay(
        room: room,
        battle: battle,
        selectedCards: selectedCards,
      ),
      bottomHand: _buildImmersiveArenaBottomOverlay(
        battle: battle,
        selectedCards: selectedCards,
      ),
      sideHand: _buildImmersiveArenaSideOverlay(
        battle: battle,
        selectedCards: selectedCards,
      ),
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
    return MiniRoyaleArenaPreview(
      arena: arena,
      playerSide: room.viewerSide ?? 'left',
      mapTypeLabel: _t.text('Random Map'),
      arenaName: _arenaDisplayName(arena),
      bridgeLabel: _t.text('Bridge'),
      arenaLabel: _t.text('Arena'),
    );
  }

  Widget _buildLobby(RoyaleRoomSnapshot room) {
    final t = _t;
    return MiniRoyaleRoomLobby(
      room: room,
      arenaPreview: _buildLobbyArenaPreview(room),
      labels: {
        for (final copy in [
          'Battle starts as soon as both players are ready',
          'Host Simulation (Experimental)',
          'Server Simulation',
          'Mini Royale Lobby',
          'Ready',
          'Waiting',
          'Online',
          'Offline',
          'Add Friend Button',
          'Sending...',
          'Ready to Battle',
        ])
          copy: t.text(copy),
      },
      isReadySubmitting: _readySubmitting,
      canAddFriend: (player) =>
          _shouldShowAddFriendButton(player, room.me?.userId),
      onAddFriend: _sendFriendRequestToPlayer,
      onReady: _sendReady,
    );
  }

  Widget _buildArena(RoyaleRoomSnapshot room) {
    final battle = room.battle!;
    final mySide = room.viewerSide ?? 'left';
    final selectedCards = _selectedCards(battle);

    return _buildImmersiveArena(
      room: room,
      battle: battle,
      mySide: mySide,
      selectedCards: selectedCards,
    );
  }

  Widget _buildPageContent(MiniRoyaleLocalizationPort t) {
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
