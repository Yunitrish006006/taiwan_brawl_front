part of 'royale_arena_page.dart';

extension _RoyaleArenaBattlefieldLayout on _RoyaleArenaPageState {
  Widget _buildBattlefieldHeader({
    required bool highlightDropZone,
    required List<RoyaleCard> selectedCards,
    required String mySide,
  }) {
    return Row(
      children: [
        const Icon(Icons.grid_view_rounded, color: Colors.white70),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            _battlefieldHintText(highlightDropZone, selectedCards),
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
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
  }) {
    final isLeftSide = player.side == 'left';
    final top =
        (mySide == 'left'
            ? board.maxHeight * (isLeftSide ? 0.95 : 0.05)
            : board.maxHeight * (isLeftSide ? 0.05 : 0.95)) -
        60;
    return Positioned(
      left: board.maxWidth * 0.5 - 34,
      top: top,
      child: _TowerToken(
        label: player.name,
        color: _sideColor(player.side),
        towerHp: player.towerHp,
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

      return Positioned(
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
            _UnitToken(
              unit: unit,
              friendly: unit.side == mySide,
              size: tokenSize,
            ),
          ],
        ),
      );
    }).toList();
  }

  Widget? _buildBattleResultOverlay(RoyaleBattleResult? result, String mySide) {
    if (result == null) {
      return null;
    }

    return Positioned.fill(
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 20),
          decoration: BoxDecoration(
            color: const Color(0xFF07111F).withValues(alpha: 0.8),
            borderRadius: BorderRadius.circular(26),
            border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _resultLabel(result, mySide),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                _t.text('Battle finished'),
                style: TextStyle(color: Colors.white.withValues(alpha: 0.72)),
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: _rematchSubmitting ? null : _playAgain,
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFFFFB703),
                  foregroundColor: const Color(0xFF1F2937),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 14,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                icon: const Icon(Icons.replay_rounded),
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
  }) {
    final leftPlayer = _playerBySideOrPlaceholder(room, 'left');
    final rightPlayer = _playerBySideOrPlaceholder(room, 'right');

    return Align(
      child: SizedBox(
        width: boardWidth,
        height: boardHeight,
        child: Container(
          key: _arenaKey,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(30),
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
                  : Colors.white.withValues(alpha: 0.32),
              width: highlightDropZone ? 2.4 : 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF07111F).withValues(alpha: 0.28),
                blurRadius: 28,
                offset: const Offset(0, 18),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(28),
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
                        Positioned(
                          left: 18,
                          top: 18,
                          child: _FieldLabel(
                            label: _t.text('Enemy Base'),
                            color: const Color(0xFFE25555),
                          ),
                        ),
                        Positioned(
                          left: board.maxWidth * 0.5 - 42,
                          top: 18,
                          child: _FieldLabel(
                            label: _t.text('Central Bridge'),
                            color: const Color(0xFF2F7D87),
                          ),
                        ),
                        Positioned(
                          right: 18,
                          bottom: 18,
                          child: _FieldLabel(
                            label: _t.text('Your Deployment Zone'),
                            color: const Color(0xFF136F63),
                          ),
                        ),
                        _buildTowerToken(
                          board: board,
                          mySide: mySide,
                          player: leftPlayer,
                        ),
                        _buildTowerToken(
                          board: board,
                          mySide: mySide,
                          player: rightPlayer,
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

  Widget _buildSelectedComboLauncher(
    List<RoyaleCard> selectedCards,
    int selectedCost,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Draggable<_ComboDragPayload>(
        data: _ComboDragPayload(cards: selectedCards),
        dragAnchorStrategy: pointerDragAnchorStrategy,
        feedback: Material(
          color: Colors.transparent,
          child: const _DragCursorFeedback(),
        ),
        childWhenDragging: Opacity(
          opacity: 0.38,
          child: _ComboLauncher(cards: selectedCards, totalCost: selectedCost),
        ),
        child: _ComboLauncher(
          cards: selectedCards,
          totalCost: selectedCost,
          onClear: _clearSelection,
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
  }) {
    return DragTarget<_ComboDragPayload>(
      onAcceptWithDetails: _handleBattlefieldAccept,
      onMove: _handleBattlefieldMove,
      onLeave: (_) => _handleBattlefieldLeave(),
      builder: (context, candidateItems, rejectedItems) {
        final highlightDropZone = candidateItems.isNotEmpty;
        return _GlassPanel(
          padding: const EdgeInsets.all(14),
          child: Column(
            children: [
              _buildBattlefieldHeader(
                highlightDropZone: highlightDropZone,
                selectedCards: selectedCards,
                mySide: mySide,
              ),
              const SizedBox(height: 14),
              _buildBattlefieldBoard(
                room: room,
                battle: battle,
                mySide: mySide,
                selectedCards: selectedCards,
                boardWidth: boardWidth,
                boardHeight: boardHeight,
                highlightDropZone: highlightDropZone,
              ),
            ],
          ),
        );
      },
    );
  }
}
