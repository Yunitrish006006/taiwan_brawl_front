part of 'royale_arena_page.dart';

extension _RoyaleArenaBattlefieldLayout on _RoyaleArenaPageState {
  void _toggleCollisionRadiusOverlay() {
    setState(() {
      _showCollisionRadiusOverlay = !_showCollisionRadiusOverlay;
    });
  }

  Offset _towerCenter({
    required BoxConstraints board,
    required String mySide,
    required String towerSide,
  }) {
    final towerProgress = towerSide == 'left'
        ? battle_rules.leftTowerX.toDouble()
        : battle_rules.rightTowerX.toDouble();
    final longitudinal = mySide == 'left'
        ? 1 - (towerProgress / _worldScale)
        : (towerProgress / _worldScale);
    return Offset(
      board.maxWidth * (battle_rules.centerLateral / _worldScale),
      board.maxHeight * longitudinal.clamp(0.0, 1.0),
    );
  }

  double? _selectedTowerThreatReach(List<RoyaleCard> selectedCards) {
    double? maxReach;
    for (final card in selectedCards) {
      if (card.type == 'equipment') {
        continue;
      }

      final reach = card.type == 'spell'
          ? battle_rules.effectiveSpellReachToTower(card.spellRadius.toDouble())
          : battle_rules.effectiveAttackReachToTower(
              attackRange: card.attackRange.toDouble(),
              bodyRadius: card.bodyRadius > 0
                  ? card.bodyRadius.toDouble()
                  : battle_rules.bodyRadiusForUnitType(card.type),
            );
      if (maxReach == null || reach > maxReach) {
        maxReach = reach;
      }
    }
    return maxReach;
  }

  Widget _buildTowerTargetOverlay({
    required BoxConstraints board,
    required String mySide,
    required RoyalePlayerView player,
    required List<RoyaleCard> selectedCards,
  }) {
    final center = _towerCenter(
      board: board,
      mySide: mySide,
      towerSide: player.side,
    );
    final threatReach = player.side == mySide
        ? null
        : _selectedTowerThreatReach(selectedCards);
    final bodyDiameter =
        board.maxHeight * (battle_rules.towerBodyRadius / _worldScale) * 2;
    final threatDiameter = threatReach == null
        ? null
        : board.maxHeight * (threatReach / _worldScale) * 2;
    final overlayDiameter = (threatDiameter ?? bodyDiameter) + 28;

    return Positioned(
      left: center.dx - overlayDiameter / 2,
      top: center.dy - overlayDiameter / 2,
      child: _TowerTargetOverlay(
        color: _sideColor(player.side),
        bodyDiameter: bodyDiameter,
        threatDiameter: threatDiameter,
        emphasized: threatReach != null,
      ),
    );
  }

  Widget _buildBattlefieldHeader({
    required bool highlightDropZone,
    required List<RoyaleCard> selectedCards,
    required String mySide,
    required bool compact,
  }) {
    return Row(
      children: [
        Icon(
          Icons.grid_view_rounded,
          color: Colors.white70,
          size: compact ? 18 : 24,
        ),
        SizedBox(width: compact ? 8 : 10),
        Expanded(
          child: Text(
            _battlefieldHintText(
              highlightDropZone,
              selectedCards,
              compact: compact,
            ),
            maxLines: compact ? 2 : 3,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: compact ? 13 : 15,
            ),
          ),
        ),
        SizedBox(width: compact ? 8 : 10),
        Material(
          color: _showCollisionRadiusOverlay
              ? const Color(0xFFFFD166).withValues(alpha: 0.18)
              : Colors.white.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(compact ? 12 : 14),
          child: InkWell(
            onTap: _toggleCollisionRadiusOverlay,
            borderRadius: BorderRadius.circular(compact ? 12 : 14),
            child: Padding(
              padding: EdgeInsets.all(compact ? 8 : 10),
              child: Icon(
                _showCollisionRadiusOverlay
                    ? Icons.blur_circular_rounded
                    : Icons.radio_button_unchecked_rounded,
                color: _showCollisionRadiusOverlay
                    ? const Color(0xFFFFD166)
                    : Colors.white.withValues(alpha: 0.72),
                size: compact ? 16 : 18,
              ),
            ),
          ),
        ),
        if (!compact)
          _ArenaLegendChip(
            label: mySide == 'left'
                ? _t.text('Your Left Base')
                : _t.text('Your Right Base'),
            color: _sideColor(mySide),
          ),
      ],
    );
  }

  Widget _buildTowerToken({
    required BoxConstraints board,
    required String mySide,
    required RoyalePlayerView player,
    required bool compact,
  }) {
    final center = _towerCenter(
      board: board,
      mySide: mySide,
      towerSide: player.side,
    );
    final shellWidth = compact ? 74.0 : 88.0;
    final tokenHeight = compact ? 46.0 : 54.0;
    return Positioned(
      left: center.dx - shellWidth / 2,
      top: center.dy - tokenHeight / 2,
      child: _TowerToken(
        heroName: player.hero.localizedName(
          context.watch<LocaleProvider>().locale,
        ),
        color: _sideColor(player.side),
        towerHp: player.towerHp,
        maxTowerHp: player.maxTowerHp,
        compact: compact,
      ),
    );
  }

  List<Widget> _buildBattlefieldUnits({
    required RoyaleBattleView battle,
    required String mySide,
    required BoxConstraints board,
  }) {
    return battle.units.map((unit) {
      final longitudinal = mySide == 'left'
          ? 1 - (unit.progress / _worldScale)
          : (unit.progress / _worldScale);
      final depthFactor = longitudinal.clamp(0.0, 1.0);
      final tokenSize = 40 + (depthFactor * 8);
      final left =
          board.maxWidth * (unit.lateralPosition / _worldScale) - tokenSize / 2;
      final top = board.maxHeight * longitudinal - tokenSize * 0.62;
      final attackIndicatorDiameter =
          board.maxHeight * (unit.attackRange / _worldScale) * 2;
      final collisionIndicatorDiameter =
          board.maxHeight * (unit.bodyRadius / _worldScale) * 2;

      return Positioned(
        key: ValueKey(unit.id),
        left: left,
        top: top,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            if (unit.attackRange > 0)
              Positioned(
                left: tokenSize / 2 - attackIndicatorDiameter / 2,
                top: tokenSize * 0.5 - attackIndicatorDiameter / 2,
                child: _AttackRangeIndicator(
                  width: attackIndicatorDiameter,
                  height: attackIndicatorDiameter,
                  friendly: unit.side == mySide,
                ),
              ),
            if (_showCollisionRadiusOverlay && unit.bodyRadius > 0)
              Positioned(
                left: tokenSize / 2 - collisionIndicatorDiameter / 2,
                top: tokenSize * 0.5 - collisionIndicatorDiameter / 2,
                child: _CollisionRadiusIndicator(
                  width: collisionIndicatorDiameter,
                  height: collisionIndicatorDiameter,
                  friendly: unit.side == mySide,
                ),
              ),
            _UnitToken(
              unit: unit,
              friendly: unit.side == mySide,
              viewerSide: mySide,
              size: tokenSize,
            ),
          ],
        ),
      );
    }).toList();
  }

  Widget? _buildBattleResultOverlay(
    RoyaleBattleResult? result,
    String mySide, {
    required bool compact,
  }) {
    if (result == null) {
      return null;
    }

    return Positioned.fill(
      child: Center(
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: compact ? 18 : 28,
            vertical: compact ? 14 : 20,
          ),
          decoration: BoxDecoration(
            color: const Color(0xFF07111F).withValues(alpha: 0.8),
            borderRadius: BorderRadius.circular(compact ? 22 : 26),
            border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _resultLabel(result, mySide),
                style: TextStyle(
                  color: Colors.white,
                  fontSize: compact ? 22 : 28,
                  fontWeight: FontWeight.w800,
                ),
              ),
              SizedBox(height: compact ? 4 : 6),
              Text(
                _t.text('Battle finished'),
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.72),
                  fontSize: compact ? 12 : 14,
                ),
              ),
              SizedBox(height: compact ? 12 : 16),
              FilledButton.icon(
                onPressed: _rematchSubmitting ? null : _playAgain,
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFFFFB703),
                  foregroundColor: const Color(0xFF1F2937),
                  padding: EdgeInsets.symmetric(
                    horizontal: compact ? 16 : 20,
                    vertical: compact ? 10 : 14,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(compact ? 14 : 16),
                  ),
                ),
                icon: Icon(Icons.replay_rounded, size: compact ? 18 : 24),
                label: Text(
                  _rematchSubmitting
                      ? _t.text('Returning to room...')
                      : _t.text('Play Again'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBattlefieldBoard({
    required RoyaleRoomSnapshot room,
    required RoyaleBattleView battle,
    required String mySide,
    required List<RoyaleCard> selectedCards,
    required double boardWidth,
    required double boardHeight,
    required bool highlightDropZone,
    required bool compact,
    bool fullscreen = false,
  }) {
    final leftPlayer = _playerBySideOrPlaceholder(room, 'left');
    final rightPlayer = _playerBySideOrPlaceholder(room, 'right');
    final outerRadius = fullscreen ? 0.0 : 30.0;
    final innerRadius = fullscreen ? 0.0 : 28.0;

    return Align(
      child: SizedBox(
        width: boardWidth,
        height: boardHeight,
        child: Container(
          key: _arenaKey,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(outerRadius),
            gradient: const LinearGradient(
              colors: [
                Color(0xFFDEF4FF),
                Color(0xFF9DD6FF),
                Color(0xFF7EC97D),
                Color(0xFF5DAA4D),
              ],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
            border: Border.all(
              color: highlightDropZone
                  ? const Color(0xFFFFD166)
                  : fullscreen
                  ? Colors.transparent
                  : Colors.white.withValues(alpha: 0.32),
              width: highlightDropZone ? 2.4 : (fullscreen ? 0 : 1.2),
            ),
            boxShadow: fullscreen
                ? const []
                : [
                    BoxShadow(
                      color: const Color(0xFF07111F).withValues(alpha: 0.28),
                      blurRadius: 28,
                      offset: const Offset(0, 18),
                    ),
                  ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(innerRadius),
            child: MouseRegion(
              onHover: (event) => _updateAimPoint(event.position),
              onExit: (_) => _clearAimPoint(),
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTapDown: selectedCards.isEmpty
                    ? null
                    : (details) =>
                          _handleBattlefieldTap(details, selectedCards),
                child: LayoutBuilder(
                  builder: (context, board) {
                    final resultOverlay = _buildBattleResultOverlay(
                      battle.result,
                      mySide,
                      compact: compact,
                    );
                    return Stack(
                      children: [
                        Positioned.fill(
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: RadialGradient(
                                center: const Alignment(0, -0.85),
                                radius: 1.1,
                                colors: [
                                  Colors.white.withValues(alpha: 0.44),
                                  Colors.transparent,
                                ],
                              ),
                            ),
                          ),
                        ),
                        Positioned.fill(
                          child: CustomPaint(
                            painter: _ArenaPainter(playerSide: mySide),
                          ),
                        ),
                        if (!compact && !fullscreen)
                          Positioned(
                            left: 18,
                            top: 18,
                            child: _FieldLabel(
                              label: _t.text('Enemy Base'),
                              color: const Color(0xFFE25555),
                            ),
                          ),
                        if (!compact && !fullscreen)
                          Positioned(
                            left: board.maxWidth * 0.5 - 42,
                            top: 18,
                            child: _FieldLabel(
                              label: _t.text('Central Bridge'),
                              color: const Color(0xFF2F7D87),
                            ),
                          ),
                        if (!fullscreen)
                          Positioned(
                            right: 18,
                            bottom: 18,
                            child: _FieldLabel(
                              label: _t.text('Your Deployment Zone'),
                              color: const Color(0xFF136F63),
                              compact: compact,
                            ),
                          ),
                        _buildTowerTargetOverlay(
                          board: board,
                          mySide: mySide,
                          player: leftPlayer,
                          selectedCards: selectedCards,
                        ),
                        _buildTowerTargetOverlay(
                          board: board,
                          mySide: mySide,
                          player: rightPlayer,
                          selectedCards: selectedCards,
                        ),
                        _buildTowerToken(
                          board: board,
                          mySide: mySide,
                          player: leftPlayer,
                          compact: compact,
                        ),
                        _buildTowerToken(
                          board: board,
                          mySide: mySide,
                          player: rightPlayer,
                          compact: compact,
                        ),
                        if (_aimPoint != null &&
                            _hasDeploymentTarget &&
                            !_dragTargetActive)
                          Positioned(
                            left: board.maxWidth * _aimPoint!.dx - 28,
                            top: board.maxHeight * _aimPoint!.dy - 28,
                            child: _AimMarker(
                              point: _aimPoint!,
                              active: selectedCards.isNotEmpty,
                            ),
                          ),
                        ..._buildBattlefieldUnits(
                          battle: battle,
                          mySide: mySide,
                          board: board,
                        ),
                        if (resultOverlay != null) ...[resultOverlay],
                      ],
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBattlefieldPanel({
    required RoyaleRoomSnapshot room,
    required RoyaleBattleView battle,
    required String mySide,
    required List<RoyaleCard> selectedCards,
    required double boardWidth,
    required double boardHeight,
    required bool compact,
    bool fullscreen = false,
  }) {
    return DragTarget<_ComboDragPayload>(
      onAcceptWithDetails: _handleBattlefieldAccept,
      onMove: _handleBattlefieldMove,
      onLeave: (_) => _handleBattlefieldLeave(),
      builder: (context, candidateItems, rejectedItems) {
        final highlightDropZone = candidateItems.isNotEmpty;
        if (fullscreen) {
          return _buildBattlefieldBoard(
            room: room,
            battle: battle,
            mySide: mySide,
            selectedCards: selectedCards,
            boardWidth: boardWidth,
            boardHeight: boardHeight,
            highlightDropZone: highlightDropZone,
            compact: compact,
            fullscreen: true,
          );
        }
        return _GlassPanel(
          padding: EdgeInsets.all(compact ? 10 : 14),
          child: Column(
            children: [
              _buildBattlefieldHeader(
                highlightDropZone: highlightDropZone,
                selectedCards: selectedCards,
                mySide: mySide,
                compact: compact,
              ),
              SizedBox(height: compact ? 10 : 14),
              _buildBattlefieldBoard(
                room: room,
                battle: battle,
                mySide: mySide,
                selectedCards: selectedCards,
                boardWidth: boardWidth,
                boardHeight: boardHeight,
                highlightDropZone: highlightDropZone,
                compact: compact,
                fullscreen: false,
              ),
            ],
          ),
        );
      },
    );
  }
}
