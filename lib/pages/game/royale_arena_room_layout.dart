part of 'royale_arena_page.dart';

extension _RoyaleArenaRoomLayout on _RoyaleArenaPageState {
  Widget _buildHandInfoChips(
    RoyaleBattleView battle,
    List<RoyaleCard> selectedCards,
  ) {
    final selectedCost = _selectedCardCost(selectedCards);
    return Wrap(
      spacing: 12,
      runSpacing: 10,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Text(
          'Battle Hand',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.w800,
          ),
        ),
        _InfoChip(
          icon: Icons.bolt_rounded,
          label:
              '${_t.text('Current Elixir')} ${battle.yourElixir.toStringAsFixed(1)}',
        ),
        _InfoChip(
          icon: Icons.arrow_forward_rounded,
          label: battle.nextCardId == null
              ? '${_t.text('Next Card')} ${_t.text('Unknown')}'
              : '${_t.text('Next Card')} ${battle.nextCardId}',
        ),
        if (selectedCards.isNotEmpty)
          _InfoChip(
            icon: Icons.layers_rounded,
            label:
                '${_t.text('Selected Cards')} ${selectedCards.length} / $selectedCost',
          ),
      ],
    );
  }

  Widget _buildHandCardList(RoyaleBattleView battle) {
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
          );

          return Padding(
            padding: const EdgeInsets.only(right: 14),
            child: GestureDetector(
              onTap: () => _toggleCardSelection(card),
              child: Draggable<_ComboDragPayload>(
                data: _ComboDragPayload(cards: [card]),
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
        final boardWidth = _boardWidthFor(constraints, compact);
        final boardHeight = boardWidth / _battlefieldAspectRatio;
        return Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1200),
            child: ListView(
              padding: EdgeInsets.all(compact ? 14 : 20),
              children: [
                _buildHudSection(
                  battle: battle,
                  me: me,
                  opponent: opponent,
                  mySide: mySide,
                  simulationMode: room.simulationMode,
                ),
                const SizedBox(height: 16),
                _buildBattlefieldPanel(
                  room: room,
                  battle: battle,
                  mySide: mySide,
                  selectedCards: selectedCards,
                  boardWidth: boardWidth,
                  boardHeight: boardHeight,
                ),
                const SizedBox(height: 16),
                if (selectedCards.isNotEmpty)
                  _buildSelectedComboLauncher(selectedCards, selectedCost),
                _buildCommandDeck(
                  battle: battle,
                  compact: compact,
                  selectedCards: selectedCards,
                ),
              ],
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
  }) {
    return _GlassPanel(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
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
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 10,
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
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 28,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1,
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    _ElixirMeter(value: battle.yourElixir),
                  ],
                ),
              ),
              Expanded(
                child: _PlayerHudCard(
                  title: opponent?.name ?? _t.text('Opponent'),
                  subtitle: mySide == 'left' ? 'Red Side' : 'Blue Side',
                  towerHp: opponent?.towerHp ?? 0,
                  maxTowerHp: opponent?.maxTowerHp ?? 1,
                  color: _sideColor(opponent?.side ?? 'right'),
                  alignEnd: true,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
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
              _ArenaLegendChip(
                label: simulationMode == 'host'
                    ? _t.text('Host Simulation (Experimental)')
                    : _t.text('Server Simulation'),
                color: simulationMode == 'host'
                    ? const Color(0xFFB084F5)
                    : const Color(0xFF48C7F4),
              ),
              if (opponent != null &&
                  _shouldShowAddFriendButton(opponent, me?.userId))
                ActionChip(
                  avatar: const Icon(Icons.person_add_alt_1, size: 18),
                  label: Text(
                    '${_t.text('Add')} ${opponent.name} ${_t.text('as a friend')}',
                  ),
                  onPressed: () => _sendFriendRequestToPlayer(opponent),
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
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 18),
      gradient: const LinearGradient(
        colors: [Color(0xFF0D1B2A), Color(0xFF132238), Color(0xFF1A2F48)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHandInfoChips(battle, selectedCards),
          const SizedBox(height: 16),
          _buildHandCardList(battle),
          const SizedBox(height: 14),
          Text(
            _commandDeckHintText(compact),
            style: TextStyle(color: Colors.white.withValues(alpha: 0.72)),
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
