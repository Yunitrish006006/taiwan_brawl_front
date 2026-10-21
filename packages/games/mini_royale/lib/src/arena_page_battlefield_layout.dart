part of 'mini_royale_arena_page.dart';

extension _RoyaleArenaBattlefieldLayout on _MiniRoyaleArenaPageState {
  Widget _buildTowerTargetOverlay({
    required BoxConstraints board,
    required String mySide,
    required RoyalePlayerView player,
    required List<RoyaleCard> selectedCards,
    required battle_rules.BattleArenaConfig arena,
  }) {
    final normalizedCenter = miniRoyaleTowerPosition(
      playerSide: mySide,
      towerSide: player.side,
      arena: arena,
    );
    final threatReach = player.side == mySide
        ? null
        : miniRoyaleSelectedTowerThreatReach(selectedCards);
    final center = Offset(
      board.maxWidth * normalizedCenter.lateral,
      board.maxHeight * normalizedCenter.progress,
    );
    final bodyDiameter =
        board.maxHeight *
        (battle_rules.towerBodyRadius / arena.progressMax) *
        2;
    final threatDiameter = threatReach == null
        ? null
        : board.maxHeight * (threatReach / arena.progressMax) * 2;
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
    return MiniRoyaleBattlefieldHeader(
      highlightDropZone: highlightDropZone,
      hasSelection: selectedCards.isNotEmpty,
      playerSide: mySide,
      compact: compact,
      showCollisionRadius: _showCollisionRadiusOverlay,
      onToggleCollisionRadius: _toggleCollisionRadiusOverlay,
      labels: MiniRoyaleBattlefieldLabels(
        releaseToDeployHere: _t.text('Release to deploy here'),
        releaseToCastSelectionHere: _t.text(
          'Release to cast all selected cards here',
        ),
        tapToDeploySelection: _t.text(
          'Tap the battlefield to deploy selected cards',
        ),
        precisionTapInstruction: _t.text(
          'Precision targeting enabled. Tap the battlefield to place cards.',
        ),
        dragCardToArena: _t.text(
          'Drag a card or combo onto your side of the arena',
        ),
        dragOrSelectCardsInstruction: _t.text(
          'Drag a single card or combo, or select cards first then tap the 2D battlefield.',
        ),
        yourLeftBase: _t.text('Your Left Base'),
        yourRightBase: _t.text('Your Right Base'),
        collisionOverlayTooltip: _t.text('Toggle collision radius'),
      ),
    );
  }

  Widget _buildTowerToken({
    required BoxConstraints board,
    required String mySide,
    required RoyalePlayerView player,
    required bool compact,
    required battle_rules.BattleArenaConfig arena,
  }) {
    final normalizedCenter = miniRoyaleTowerPosition(
      playerSide: mySide,
      towerSide: player.side,
      arena: arena,
    );
    final center = Offset(
      board.maxWidth * normalizedCenter.lateral,
      board.maxHeight * normalizedCenter.progress,
    );
    final shellWidth = compact ? 74.0 : 88.0;
    final tokenHeight = compact ? 46.0 : 54.0;
    return Positioned(
      left: center.dx - shellWidth / 2,
      top: center.dy - tokenHeight / 2,
      child: _TowerToken(
        heroName: player.hero.localizedName(
          context.watch<MiniRoyaleLocalizationPort>().locale,
        ),
        color: _sideColor(player.side),
        towerHp: player.towerHp,
        maxTowerHp: player.maxTowerHp,
        compact: compact,
      ),
    );
  }

  Widget? _buildBattleResultOverlay(
    RoyaleBattleResult? result,
    String mySide, {
    required bool compact,
  }) {
    if (result == null) {
      return null;
    }

    return MiniRoyaleBattleResultOverlay(
      resultLabel: _resultLabel(result, mySide),
      subtitle: _t.text('Battle finished'),
      actionLabel: _rematchSubmitting
          ? _t.text('Returning to room...')
          : _t.text('Play Again'),
      compact: compact,
      isSubmitting: _rematchSubmitting,
      onPlayAgain: _playAgain,
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
    final resultOverlay = _buildBattleResultOverlay(
      battle.result,
      mySide,
      compact: compact,
    );

    return MiniRoyaleBattlefieldCanvas(
      boardKey: _arenaKey,
      width: boardWidth,
      height: boardHeight,
      playerSide: mySide,
      arena: battle.arena,
      compact: compact,
      fullscreen: fullscreen,
      highlightDropZone: highlightDropZone,
      enemyBaseLabel: _t.text('Enemy Base'),
      bridgeLabel: _t.text('Central Bridge'),
      deploymentZoneLabel: _t.text('Your Deployment Zone'),
      presentation: _arenaPresentation,
      onHover: (event) => _updateAimPoint(event.position),
      onExit: (_) => _clearAimPoint(),
      onTapDown: selectedCards.isEmpty
          ? null
          : (details) => _handleBattlefieldTap(details, selectedCards),
      buildOverlays: (board) => [
        _buildTowerTargetOverlay(
          board: board,
          mySide: mySide,
          player: leftPlayer,
          selectedCards: selectedCards,
          arena: battle.arena,
        ),
        _buildTowerTargetOverlay(
          board: board,
          mySide: mySide,
          player: rightPlayer,
          selectedCards: selectedCards,
          arena: battle.arena,
        ),
        _buildTowerToken(
          board: board,
          mySide: mySide,
          player: leftPlayer,
          compact: compact,
          arena: battle.arena,
        ),
        _buildTowerToken(
          board: board,
          mySide: mySide,
          player: rightPlayer,
          compact: compact,
          arena: battle.arena,
        ),
        if (_aimPoint != null && _hasDeploymentTarget && !_dragTargetActive)
          Positioned(
            left: board.maxWidth * _aimPoint!.dx - 28,
            top: board.maxHeight * _aimPoint!.dy - 28,
            child: MiniRoyaleAimMarker(
              point: _aimPoint!,
              active: selectedCards.isNotEmpty,
              arena: battle.arena,
            ),
          ),
        Positioned.fill(
          child: MiniRoyaleBattlefieldUnits(
            battle: battle,
            viewerSide: mySide,
            locale: context.watch<MiniRoyaleLocalizationPort>().locale,
            showCollisionRadii: _showCollisionRadiusOverlay,
          ),
        ),
        ?resultOverlay,
      ],
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
    return MiniRoyaleBattlefieldDropTarget<MiniRoyaleCardDragPayload>(
      canAccept: (payload) => payload.canDeploy,
      onAccept: _handleBattlefieldAccept,
      onMove: _handleBattlefieldMove,
      onLeave: _handleBattlefieldLeave,
      builder: (context, highlightDropZone) {
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
