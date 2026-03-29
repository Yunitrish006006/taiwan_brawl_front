import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../../models/royale_models.dart';
import '../../services/api_client.dart';
import '../../services/friends_service.dart';
import '../../services/host_battle_engine.dart';
import '../../services/locale_provider.dart';
import '../../services/royale_service.dart';

const double _battlefieldAspectRatio = 0.62;
const double _battlefieldPhoneMaxWidth = 430;
const double _battlefieldDesktopMaxWidth = 520;
const int _worldScale = 1000;
const double _deployZoneMinX = 0.12;
const double _deployZoneMaxX = 0.88;
const double _deployZoneMinY = 0.58;
const double _deployZoneMaxY = 0.92;

class RoyaleArenaPage extends StatefulWidget {
  const RoyaleArenaPage({super.key, required this.roomCode});

  final String roomCode;

  @override
  State<RoyaleArenaPage> createState() => _RoyaleArenaPageState();
}

class _RoyaleArenaPageState extends State<RoyaleArenaPage> {
  late final RoyaleService _service;
  late final FriendsService _friendsService;
  final GlobalKey _arenaKey = GlobalKey();
  final List<String> _selectedCardIds = [];
  final Set<int> _friendUserIds = <int>{};
  final Set<int> _sentFriendRequestUserIds = <int>{};
  WebSocketChannel? _channel;
  StreamSubscription<dynamic>? _socketSubscription;
  Timer? _pingTimer;
  RoyaleRoomSnapshot? _room;
  bool _isLoading = true;
  bool _readySubmitting = false;
  bool _rematchSubmitting = false;
  bool _hostFinishSubmitting = false;
  bool _hostFinishSent = false;
  bool _dragTargetActive = false;
  String? _error;
  Offset? _aimPoint;
  HostBattleEngine? _hostBattleEngine;

  Map<String, String> get _t => context.read<LocaleProvider>().translation;

  @override
  void initState() {
    super.initState();
    final apiClient = ApiClient();
    _service = RoyaleService(apiClient);
    _friendsService = FriendsService(apiClient);
    _bootstrap();
  }

  @override
  void dispose() {
    _pingTimer?.cancel();
    _socketSubscription?.cancel();
    _channel?.sink.close();
    _hostBattleEngine?.dispose();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    try {
      final room = await _service.fetchRoomState(widget.roomCode);
      await _refreshFriendState();
      if (!mounted) {
        return;
      }
      setState(() {
        _room = room;
        _syncSelectionWithRoom(room);
        _isLoading = false;
      });
      if (_usesHostSimulation(room)) {
        await _initializeHostBattle(room);
      } else {
        _connectSocket();
      }
    } on ApiException catch (e) {
      if (!mounted) {
        return;
      }
      setState(() {
        _error = e.message;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) {
        return;
      }
      setState(() {
        _error = '${_t.text('Failed to load room')}: $e';
        _isLoading = false;
      });
    }
  }

  bool _usesHostSimulation([RoyaleRoomSnapshot? room]) {
    final current = room ?? _room;
    return current?.simulationMode == 'host' && current?.opponent?.userId == 0;
  }

  Future<void> _initializeHostBattle(RoyaleRoomSnapshot room) async {
    if (!_usesHostSimulation(room) ||
        room.battle == null ||
        _hostBattleEngine != null) {
      return;
    }

    final me = room.me;
    if (me == null) {
      return;
    }

    try {
      final decks = await _service.fetchDecks();
      RoyaleDeck? deck;
      for (final entry in decks) {
        if (entry.id == me.deckId) {
          deck = entry;
          break;
        }
      }
      if (deck == null || !mounted) {
        return;
      }

      final engine = HostBattleEngine(
        room: room,
        deck: deck,
        onSnapshot: (snapshot) {
          if (!mounted) {
            return;
          }
          setState(() {
            _room = snapshot;
            _syncSelectionWithRoom(snapshot);
          });
          if (snapshot.battle?.result != null) {
            unawaited(_reportHostFinish(snapshot));
          }
        },
      );
      setState(() {
        _hostBattleEngine = engine;
        _room = engine.snapshot;
        _syncSelectionWithRoom(engine.snapshot);
      });
      engine.start();
    } catch (e) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${_t.text('Action failed')}: $e')),
      );
    }
  }

  Future<void> _reportHostFinish(RoyaleRoomSnapshot snapshot) async {
    if (_hostFinishSent || _hostFinishSubmitting) {
      return;
    }
    final result = snapshot.battle?.result;
    if (result == null) {
      return;
    }

    setState(() {
      _hostFinishSubmitting = true;
    });

    try {
      await _service.hostFinishRoom(
        roomCode: widget.roomCode,
        winnerSide: result.winnerSide,
        reason: result.reason,
        leftTowerHp: snapshot.players
            .firstWhere((player) => player.side == 'left')
            .towerHp,
        rightTowerHp: snapshot.players
            .firstWhere((player) => player.side == 'right')
            .towerHp,
      );
      _hostFinishSent = true;
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.message)));
      }
    } finally {
      if (mounted) {
        setState(() {
          _hostFinishSubmitting = false;
        });
      }
    }
  }

  Future<void> _refreshFriendState() async {
    try {
      final overview = await _friendsService.fetchOverview();
      if (!mounted) {
        return;
      }
      setState(() {
        _friendUserIds
          ..clear()
          ..addAll(overview.friends.map((friend) => friend.userId));
        _sentFriendRequestUserIds
          ..clear()
          ..addAll(
            overview.outgoingRequests.map((request) => request.user.userId),
          );
      });
    } on ApiException {
      // Ignore friend sync failures inside battle room.
    }
  }

  void _syncSelectionWithRoom(RoyaleRoomSnapshot room) {
    if (room.battle == null) {
      _selectedCardIds.clear();
      _aimPoint = null;
      return;
    }
    final handIds =
        room.battle?.yourHand.map((card) => card.id).toSet() ?? <String>{};
    _selectedCardIds.removeWhere((id) => !handIds.contains(id));
  }

  void _connectSocket() {
    if (_usesHostSimulation()) {
      return;
    }
    _channel = _service.connectToRoom(widget.roomCode);
    _socketSubscription = _channel!.stream.listen(
      (message) {
        final data = jsonDecode(message as String) as Map<String, dynamic>;
        if (data['type'] == 'pong') {
          return;
        }
        if (data['type'] == 'error') {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  data['message'] as String? ?? _t.text('Unknown error'),
                ),
              ),
            );
          }
          return;
        }

        final roomJson = data['room'] as Map<String, dynamic>?;
        if (roomJson == null || !mounted) {
          return;
        }
        final room = RoyaleRoomSnapshot.fromJson(roomJson);
        setState(() {
          _room = room;
          _syncSelectionWithRoom(room);
        });
      },
      onError: (_) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                _t.text('Live connection lost. Please refresh the page.'),
              ),
            ),
          );
        }
      },
    );

    _pingTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      _channel?.sink.add(jsonEncode({'type': 'ping'}));
    });
  }

  Future<void> _sendReady() async {
    setState(() {
      _readySubmitting = true;
    });
    try {
      final room = await _service.readyRoom(widget.roomCode);
      if (!mounted) {
        return;
      }
      setState(() {
        _room = room;
        _syncSelectionWithRoom(room);
      });
      if (_usesHostSimulation(room)) {
        await _initializeHostBattle(room);
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
          _readySubmitting = false;
        });
      }
    }
  }

  void _toggleCardSelection(RoyaleCard card) {
    final alreadySelected = _selectedCardIds.contains(card.id);
    if (alreadySelected) {
      setState(() {
        _selectedCardIds.remove(card.id);
        if (_selectedCardIds.isEmpty && !_dragTargetActive) {
          _aimPoint = null;
        }
      });
      return;
    }

    if (_selectedCardIds.length >= 3) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_t.text('You can preselect up to 3 cards at once')),
        ),
      );
      return;
    }

    setState(() {
      _selectedCardIds.add(card.id);
    });
  }

  List<RoyaleCard> _selectedCards(RoyaleBattleView battle) {
    final handMap = {for (final card in battle.yourHand) card.id: card};
    return _selectedCardIds
        .map((id) => handMap[id])
        .whereType<RoyaleCard>()
        .toList();
  }

  bool get _hasDeploymentTarget {
    return _selectedCardIds.isNotEmpty || _dragTargetActive;
  }

  void _clearSelection() {
    setState(() {
      _selectedCardIds.clear();
      if (!_dragTargetActive) {
        _aimPoint = null;
      }
    });
  }

  Offset? _normalizedDropPointForGlobalOffset(Offset globalOffset) {
    final renderBox =
        _arenaKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox == null || !renderBox.hasSize) {
      return null;
    }

    final local = renderBox.globalToLocal(globalOffset);
    final dropX = (local.dx / renderBox.size.width).clamp(0.0, 1.0);
    final dropY = (local.dy / renderBox.size.height).clamp(0.0, 1.0);
    return Offset(dropX, dropY);
  }

  bool _isLegalDeployPoint(Offset point) {
    return point.dx >= _deployZoneMinX &&
        point.dx <= _deployZoneMaxX &&
        point.dy >= _deployZoneMinY &&
        point.dy <= _deployZoneMaxY;
  }

  void _updateAimPoint(Offset globalOffset) {
    if (!_hasDeploymentTarget) {
      if (_aimPoint == null) {
        return;
      }
      setState(() {
        _aimPoint = null;
      });
      return;
    }

    final point = _normalizedDropPointForGlobalOffset(globalOffset);
    if (point == null) {
      return;
    }
    if (!_isLegalDeployPoint(point)) {
      if (_aimPoint == null) {
        return;
      }
      setState(() {
        _aimPoint = null;
      });
      return;
    }
    setState(() {
      _aimPoint = point;
    });
  }

  void _clearAimPoint() {
    if (_aimPoint == null) {
      return;
    }
    setState(() {
      _aimPoint = null;
    });
  }

  void _castCards(
    List<RoyaleCard> cards, {
    required double dropX,
    required double dropY,
  }) {
    if (cards.isEmpty) {
      return;
    }

    final hasEquipment = cards.any((card) => card.isEquipment);
    final hasUnit = cards.any(
      (card) => card.type != 'equipment' && card.type != 'spell',
    );

    if (hasEquipment && !hasUnit) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _t.text(
              'Equipment cards must be played with at least one unit card',
            ),
          ),
        ),
      );
      return;
    }

    final dropPoint = Offset(dropX, dropY);
    if (!_isLegalDeployPoint(dropPoint)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_t.text('Place cards inside your deployment zone')),
        ),
      );
      return;
    }

    final mySide = _room?.viewerSide ?? 'left';
    final lanePosition = (mySide == 'left' ? 1 - dropY : dropY).clamp(0.0, 1.0);

    if (_usesHostSimulation()) {
      final error = _hostBattleEngine?.playCombo(
        cards,
        dropX: dropX,
        dropY: dropY,
      );
      if (error != null) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error)));
        return;
      }
    } else {
      _channel?.sink.add(
        jsonEncode({
          'type': 'play_combo',
          'cardIds': cards.map((card) => card.id).toList(),
          'lanePosition': lanePosition,
          'dropX': dropX,
          'dropY': dropY,
        }),
      );
    }
    setState(() {
      _selectedCardIds.clear();
      _aimPoint = dropPoint;
    });
  }

  String _formatTime(int ms) {
    final totalSeconds = (ms / 1000).ceil();
    final minutes = totalSeconds ~/ 60;
    final seconds = totalSeconds % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  Color _sideColor(String side) {
    return side == 'left' ? const Color(0xFF25B7D3) : const Color(0xFFE25555);
  }

  Color _cardColor(String type) {
    switch (type) {
      case 'tank':
        return const Color(0xFF3557D6);
      case 'ranged':
        return const Color(0xFF0F8B6D);
      case 'swarm':
        return const Color(0xFFF28C28);
      case 'spell':
        return const Color(0xFFD64545);
      case 'equipment':
        return const Color(0xFF7B3FF2);
      default:
        return const Color(0xFF84624A);
    }
  }

  String _cardStats(RoyaleCard card) {
    if (card.type == 'spell') {
      return '${_t.text('Spell')} ${card.spellDamage}';
    }
    if (card.type == 'equipment') {
      switch (card.effectKind) {
        case 'damage_boost':
          return '${_t.text('Equipment: +Damage')} ${card.effectValue.toInt()}';
        case 'health_boost':
          return '${_t.text('Equipment: +Health')} ${card.effectValue.toInt()}';
        case 'speed_boost':
          return '${_t.text('Equipment: +Speed')} ${(card.effectValue * 100).toInt()}%';
      }
      return _t.text('Equipment Card');
    }
    return 'HP ${card.hp} / DMG ${card.damage}';
  }

  String _cardTypeLabel(RoyaleCard card) {
    switch (card.type) {
      case 'tank':
        return _t.text('Tank');
      case 'ranged':
        return _t.text('Ranged');
      case 'swarm':
        return _t.text('Swarm');
      case 'spell':
        return _t.text('Spell');
      case 'equipment':
        return _t.text('Equipment');
      default:
        return _t.text('Melee');
    }
  }

  String _resultLabel(RoyaleBattleResult result, String mySide) {
    if (result.winnerSide == null) {
      return _t.text('Draw');
    }
    return result.winnerSide == mySide
        ? _t.text('You won')
        : _t.text('You lost');
  }

  Future<void> _playAgain() async {
    setState(() {
      _rematchSubmitting = true;
    });

    try {
      final room = await _service.rematchRoom(widget.roomCode);
      if (!mounted) {
        return;
      }
      setState(() {
        _hostBattleEngine?.dispose();
        _hostBattleEngine = null;
        _hostFinishSubmitting = false;
        _hostFinishSent = false;
        _room = room;
        _syncSelectionWithRoom(room);
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
          _rematchSubmitting = false;
        });
      }
    }
  }

  Future<void> _sendFriendRequestToPlayer(RoyalePlayerView player) async {
    final userId = player.userId;
    if (_sentFriendRequestUserIds.contains(userId) ||
        _friendUserIds.contains(userId)) {
      return;
    }

    try {
      await _friendsService.sendFriendRequest(userId);
      if (!mounted) {
        return;
      }
      setState(() {
        _sentFriendRequestUserIds.add(userId);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${_t.text('Sent a friend request to')} ${player.name}',
          ),
        ),
      );
    } on ApiException catch (e) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  bool _shouldShowAddFriendButton(RoyalePlayerView player, int? myUserId) {
    if (myUserId == null || player.userId == myUserId || player.userId <= 0) {
      return false;
    }
    if (_friendUserIds.contains(player.userId)) {
      return false;
    }
    if (_sentFriendRequestUserIds.contains(player.userId)) {
      return false;
    }
    return true;
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
    final selectedCost = selectedCards.fold<int>(
      0,
      (sum, card) => sum + card.elixirCost,
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 880;
        final boardWidth =
            constraints.maxWidth <
                (compact
                    ? _battlefieldPhoneMaxWidth
                    : _battlefieldDesktopMaxWidth)
            ? constraints.maxWidth
            : (compact
                  ? _battlefieldPhoneMaxWidth
                  : _battlefieldDesktopMaxWidth);
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
                DragTarget<_ComboDragPayload>(
                  onAcceptWithDetails: (details) {
                    if (mounted) {
                      setState(() {
                        _dragTargetActive = false;
                      });
                    }
                    final point = _normalizedDropPointForGlobalOffset(
                      details.offset,
                    );
                    if (point == null) {
                      return;
                    }
                    _castCards(
                      details.data.cards,
                      dropX: point.dx,
                      dropY: point.dy,
                    );
                  },
                  onMove: (details) {
                    if (!_dragTargetActive) {
                      setState(() {
                        _dragTargetActive = true;
                      });
                    }
                    _updateAimPoint(details.offset);
                  },
                  onLeave: (_) {
                    setState(() {
                      _dragTargetActive = false;
                      if (_selectedCardIds.isEmpty) {
                        _aimPoint = null;
                      }
                    });
                  },
                  builder: (context, candidateItems, rejectedItems) {
                    final highlightDropZone = candidateItems.isNotEmpty;
                    return _GlassPanel(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              const Icon(
                                Icons.grid_view_rounded,
                                color: Colors.white70,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  highlightDropZone
                                      ? _t.text(
                                          'Release to cast all selected cards here',
                                        )
                                      : selectedCards.isNotEmpty
                                      ? _t.text(
                                          'Precision targeting enabled. Tap the battlefield to place cards.',
                                        )
                                      : _t.text(
                                          'Drag a single card or combo, or select cards first then tap the 2D battlefield.',
                                        ),
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
                          ),
                          const SizedBox(height: 14),
                          Align(
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
                                      color: const Color(
                                        0xFF07111F,
                                      ).withValues(alpha: 0.28),
                                      blurRadius: 28,
                                      offset: const Offset(0, 18),
                                    ),
                                  ],
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(28),
                                  child: MouseRegion(
                                    onHover: (event) =>
                                        _updateAimPoint(event.position),
                                    onExit: (_) => _clearAimPoint(),
                                    child: GestureDetector(
                                      behavior: HitTestBehavior.opaque,
                                      onTapDown: selectedCards.isEmpty
                                          ? null
                                          : (details) {
                                              final point =
                                                  _normalizedDropPointForGlobalOffset(
                                                    details.globalPosition,
                                                  );
                                              if (point == null) {
                                                return;
                                              }
                                              _castCards(
                                                selectedCards,
                                                dropX: point.dx,
                                                dropY: point.dy,
                                              );
                                            },
                                      child: LayoutBuilder(
                                        builder: (context, board) {
                                          return Stack(
                                            children: [
                                              Positioned.fill(
                                                child: DecoratedBox(
                                                  decoration: BoxDecoration(
                                                    gradient: RadialGradient(
                                                      center: const Alignment(
                                                        0,
                                                        -0.85,
                                                      ),
                                                      radius: 1.1,
                                                      colors: [
                                                        Colors.white.withValues(
                                                          alpha: 0.44,
                                                        ),
                                                        Colors.transparent,
                                                      ],
                                                    ),
                                                  ),
                                                ),
                                              ),
                                              Positioned.fill(
                                                child: CustomPaint(
                                                  painter: _ArenaPainter(
                                                    playerSide: mySide,
                                                  ),
                                                ),
                                              ),
                                              Positioned(
                                                left: 18,
                                                top: 18,
                                                child: _FieldLabel(
                                                  label: _t.text('Enemy Base'),
                                                  color: const Color(
                                                    0xFFE25555,
                                                  ),
                                                ),
                                              ),
                                              Positioned(
                                                left: board.maxWidth * 0.5 - 42,
                                                top: 18,
                                                child: _FieldLabel(
                                                  label: _t.text(
                                                    'Central Bridge',
                                                  ),
                                                  color: const Color(
                                                    0xFF2F7D87,
                                                  ),
                                                ),
                                              ),
                                              Positioned(
                                                right: 18,
                                                bottom: 18,
                                                child: _FieldLabel(
                                                  label: _t.text(
                                                    'Your Deployment Zone',
                                                  ),
                                                  color: const Color(
                                                    0xFF136F63,
                                                  ),
                                                ),
                                              ),
                                              Positioned(
                                                left: board.maxWidth * 0.5 - 34,
                                                top:
                                                    (mySide == 'left'
                                                        ? board.maxHeight * 0.95
                                                        : board.maxHeight *
                                                              0.05) -
                                                    60,
                                                child: _TowerToken(
                                                  label: room.players
                                                      .firstWhere(
                                                        (p) => p.side == 'left',
                                                      )
                                                      .name,
                                                  color: _sideColor('left'),
                                                  towerHp: room.players
                                                      .firstWhere(
                                                        (p) => p.side == 'left',
                                                      )
                                                      .towerHp,
                                                ),
                                              ),
                                              Positioned(
                                                left: board.maxWidth * 0.5 - 34,
                                                top:
                                                    (mySide == 'left'
                                                        ? board.maxHeight * 0.05
                                                        : board.maxHeight *
                                                              0.95) -
                                                    60,
                                                child: _TowerToken(
                                                  label: room.players
                                                      .firstWhere(
                                                        (p) =>
                                                            p.side == 'right',
                                                        orElse: () =>
                                                            RoyalePlayerView(
                                                              userId: 0,
                                                              name: _t.text(
                                                                'Waiting for players',
                                                              ),
                                                              side: 'right',
                                                              deckId: 0,
                                                              deckName: '',
                                                              ready: false,
                                                              connected: false,
                                                              towerHp: 0,
                                                              maxTowerHp: 1,
                                                            ),
                                                      )
                                                      .name,
                                                  color: _sideColor('right'),
                                                  towerHp: room.players
                                                      .firstWhere(
                                                        (p) =>
                                                            p.side == 'right',
                                                        orElse: () =>
                                                            RoyalePlayerView(
                                                              userId: 0,
                                                              name: _t.text(
                                                                'Waiting for players',
                                                              ),
                                                              side: 'right',
                                                              deckId: 0,
                                                              deckName: '',
                                                              ready: false,
                                                              connected: false,
                                                              towerHp: 0,
                                                              maxTowerHp: 1,
                                                            ),
                                                      )
                                                      .towerHp,
                                                ),
                                              ),
                                              if (_aimPoint != null &&
                                                  _hasDeploymentTarget &&
                                                  !_dragTargetActive)
                                                Positioned(
                                                  left:
                                                      board.maxWidth *
                                                          _aimPoint!.dx -
                                                      28,
                                                  top:
                                                      board.maxHeight *
                                                          _aimPoint!.dy -
                                                      28,
                                                  child: _AimMarker(
                                                    point: _aimPoint!,
                                                    active: selectedCards
                                                        .isNotEmpty,
                                                  ),
                                                ),
                                              ...battle.units.map((unit) {
                                                final longitudinal =
                                                    mySide == 'left'
                                                    ? 1 -
                                                          (unit.progress /
                                                              _worldScale)
                                                    : (unit.progress /
                                                          _worldScale);
                                                final depthFactor = longitudinal
                                                    .clamp(0.0, 1.0);
                                                final tokenSize =
                                                    40 + (depthFactor * 8);
                                                final left =
                                                    board.maxWidth *
                                                        (unit.lateralPosition /
                                                            _worldScale) -
                                                    tokenSize / 2;
                                                final top =
                                                    board.maxHeight *
                                                        longitudinal -
                                                    tokenSize * 0.62;
                                                final attackIndicatorDiameter =
                                                    board.maxHeight *
                                                    (unit.attackRange /
                                                        _worldScale) *
                                                    2;
                                                return Positioned(
                                                  left: left,
                                                  top: top,
                                                  child: Stack(
                                                    clipBehavior: Clip.none,
                                                    children: [
                                                      if (unit.attackRange > 0)
                                                        Positioned(
                                                          left:
                                                              tokenSize / 2 -
                                                              attackIndicatorDiameter /
                                                                  2,
                                                          top:
                                                              tokenSize * 0.5 -
                                                              attackIndicatorDiameter /
                                                                  2,
                                                          child: _AttackRangeIndicator(
                                                            width:
                                                                attackIndicatorDiameter,
                                                            height:
                                                                attackIndicatorDiameter,
                                                            friendly:
                                                                unit.side ==
                                                                mySide,
                                                          ),
                                                        ),
                                                      _UnitToken(
                                                        unit: unit,
                                                        friendly:
                                                            unit.side == mySide,
                                                        size: tokenSize,
                                                      ),
                                                    ],
                                                  ),
                                                );
                                              }),
                                              if (battle.result != null)
                                                Positioned.fill(
                                                  child: Center(
                                                    child: Container(
                                                      padding:
                                                          const EdgeInsets.symmetric(
                                                            horizontal: 28,
                                                            vertical: 20,
                                                          ),
                                                      decoration: BoxDecoration(
                                                        color:
                                                            const Color(
                                                              0xFF07111F,
                                                            ).withValues(
                                                              alpha: 0.8,
                                                            ),
                                                        borderRadius:
                                                            BorderRadius.circular(
                                                              26,
                                                            ),
                                                        border: Border.all(
                                                          color: Colors.white
                                                              .withValues(
                                                                alpha: 0.18,
                                                              ),
                                                        ),
                                                      ),
                                                      child: Column(
                                                        mainAxisSize:
                                                            MainAxisSize.min,
                                                        children: [
                                                          Text(
                                                            _resultLabel(
                                                              battle.result!,
                                                              mySide,
                                                            ),
                                                            style:
                                                                const TextStyle(
                                                                  color: Colors
                                                                      .white,
                                                                  fontSize: 28,
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .w800,
                                                                ),
                                                          ),
                                                          const SizedBox(
                                                            height: 6,
                                                          ),
                                                          Text(
                                                            _t.text(
                                                              'Battle finished',
                                                            ),
                                                            style: TextStyle(
                                                              color: Colors
                                                                  .white
                                                                  .withValues(
                                                                    alpha: 0.72,
                                                                  ),
                                                            ),
                                                          ),
                                                          const SizedBox(
                                                            height: 16,
                                                          ),
                                                          FilledButton.icon(
                                                            onPressed:
                                                                _rematchSubmitting
                                                                ? null
                                                                : _playAgain,
                                                            style: FilledButton.styleFrom(
                                                              backgroundColor:
                                                                  const Color(
                                                                    0xFFFFB703,
                                                                  ),
                                                              foregroundColor:
                                                                  const Color(
                                                                    0xFF1F2937,
                                                                  ),
                                                              padding:
                                                                  const EdgeInsets.symmetric(
                                                                    horizontal:
                                                                        20,
                                                                    vertical:
                                                                        14,
                                                                  ),
                                                              shape: RoundedRectangleBorder(
                                                                borderRadius:
                                                                    BorderRadius.circular(
                                                                      16,
                                                                    ),
                                                              ),
                                                            ),
                                                            icon: const Icon(
                                                              Icons
                                                                  .replay_rounded,
                                                            ),
                                                            label: Text(
                                                              _rematchSubmitting
                                                                  ? _t.text(
                                                                      'Returning to room...',
                                                                    )
                                                                  : _t.text(
                                                                      'Play Again',
                                                                    ),
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                            ],
                                          );
                                        },
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
                const SizedBox(height: 16),
                if (selectedCards.isNotEmpty)
                  Padding(
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
                        child: _ComboLauncher(
                          cards: selectedCards,
                          totalCost: selectedCost,
                        ),
                      ),
                      child: _ComboLauncher(
                        cards: selectedCards,
                        totalCost: selectedCost,
                        onClear: _clearSelection,
                      ),
                    ),
                  ),
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
          Wrap(
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
                      '${_t.text('Selected Cards')} ${selectedCards.length} / ${selectedCards.fold<int>(0, (sum, card) => sum + card.elixirCost)}',
                ),
            ],
          ),
          const SizedBox(height: 16),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: battle.yourHand.map((card) {
                final playable = battle.yourElixir >= card.elixirCost;
                final selectionOrder = _selectedCardIds.indexOf(card.id);
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
                      childWhenDragging: Opacity(
                        opacity: 0.3,
                        child: _HandCard(
                          card: card,
                          playable: playable,
                          selectedOrder: selectionOrder,
                          cardColor: _cardColor(card.type),
                          cardStats: _cardStats(card),
                          typeLabel: _cardTypeLabel(card),
                        ),
                      ),
                      child: _HandCard(
                        card: card,
                        playable: playable,
                        selectedOrder: selectionOrder,
                        cardColor: _cardColor(card.type),
                        cardStats: _cardStats(card),
                        typeLabel: _cardTypeLabel(card),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            compact
                ? _t.text(
                    'Tap cards to build a combo, then drag a single card or combo onto the battlefield.',
                  )
                : _t.text(
                    'Tap cards to build a combo first. Equipment cards apply to units cast together. Drag a single card or combo into your deployment zone.',
                  ),
            style: TextStyle(color: Colors.white.withValues(alpha: 0.72)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = context.watch<LocaleProvider>().translation;
    return Scaffold(
      backgroundColor: const Color(0xFF07111F),
      appBar: AppBar(
        title: Text('${t.text('Room')} ${widget.roomCode}'),
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      extendBodyBehindAppBar: true,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF07111F), Color(0xFF0D1B2A), Color(0xFF14253A)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Stack(
          children: [
            Positioned(
              top: -120,
              left: -40,
              child: _GlowOrb(
                size: 260,
                color: const Color(0xFF2EC4B6).withValues(alpha: 0.16),
              ),
            ),
            Positioned(
              top: 70,
              right: -40,
              child: _GlowOrb(
                size: 220,
                color: const Color(0xFF5E60CE).withValues(alpha: 0.18),
              ),
            ),
            SafeArea(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _error != null
                  ? Center(
                      child: Text(
                        _error!,
                        style: const TextStyle(color: Colors.white),
                      ),
                    )
                  : _room == null
                  ? Center(
                      child: Text(
                        t.text('Room not found'),
                        style: const TextStyle(color: Colors.white),
                      ),
                    )
                  : (_room!.status == 'lobby'
                        ? _buildLobby(_room!)
                        : _buildArena(_room!)),
            ),
          ],
        ),
      ),
    );
  }
}

class _ComboDragPayload {
  const _ComboDragPayload({required this.cards});

  final List<RoyaleCard> cards;
}

class _GlowOrb extends StatelessWidget {
  const _GlowOrb({required this.size, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(colors: [color, Colors.transparent]),
        ),
      ),
    );
  }
}

class _GlassPanel extends StatelessWidget {
  const _GlassPanel({
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.gradient,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final Gradient? gradient;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        gradient:
            gradient ??
            LinearGradient(
              colors: [
                Colors.white.withValues(alpha: 0.08),
                Colors.white.withValues(alpha: 0.04),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF020817).withValues(alpha: 0.36),
            blurRadius: 28,
            offset: const Offset(0, 18),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _SideBadge extends StatelessWidget {
  const _SideBadge({required this.side, required this.color});

  final String side;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 52,
      height: 52,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: [color, color.withValues(alpha: 0.7)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.26),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      alignment: Alignment.center,
      child: Text(
        side == 'left' ? 'L' : 'R',
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w800,
          fontSize: 18,
        ),
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.28)),
      ),
      child: Text(
        label,
        style: TextStyle(color: color, fontWeight: FontWeight.w700),
      ),
    );
  }
}

class _PlayerHudCard extends StatelessWidget {
  const _PlayerHudCard({
    required this.title,
    required this.subtitle,
    required this.towerHp,
    required this.maxTowerHp,
    required this.color,
    required this.alignEnd,
  });

  final String title;
  final String subtitle;
  final int towerHp;
  final int maxTowerHp;
  final Color color;
  final bool alignEnd;

  @override
  Widget build(BuildContext context) {
    final progress = maxTowerHp == 0 ? 0.0 : towerHp / maxTowerHp;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: alignEnd
            ? CrossAxisAlignment.end
            : CrossAxisAlignment.start,
        children: [
          Text(
            subtitle,
            style: TextStyle(
              color: color.withValues(alpha: 0.9),
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              fontSize: 18,
            ),
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: progress.clamp(0.0, 1.0),
              minHeight: 12,
              backgroundColor: Colors.white.withValues(alpha: 0.08),
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '$towerHp / $maxTowerHp',
            style: TextStyle(color: Colors.white.withValues(alpha: 0.86)),
          ),
        ],
      ),
    );
  }
}

class _ElixirMeter extends StatelessWidget {
  const _ElixirMeter({required this.value});

  final double value;

  @override
  Widget build(BuildContext context) {
    final active = value.floor();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.water_drop_rounded, color: Color(0xFFB388FF)),
          const SizedBox(width: 8),
          ...List.generate(10, (index) {
            return Container(
              width: 10,
              height: 18,
              margin: EdgeInsets.only(right: index == 9 ? 0 : 4),
              decoration: BoxDecoration(
                color: index < active
                    ? const Color(0xFF9B5DE5)
                    : Colors.white.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(999),
              ),
            );
          }),
        ],
      ),
    );
  }
}

class _ArenaLegendChip extends StatelessWidget {
  const _ArenaLegendChip({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Text(
        label,
        style: TextStyle(color: color, fontWeight: FontWeight.w700),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: Colors.white70),
          const SizedBox(width: 6),
          Text(label, style: const TextStyle(color: Colors.white)),
        ],
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.24)),
      ),
      child: Text(
        label,
        style: TextStyle(color: color, fontWeight: FontWeight.w700),
      ),
    );
  }
}

class _ArenaPainter extends CustomPainter {
  const _ArenaPainter({required this.playerSide});

  final String playerSide;

  @override
  void paint(Canvas canvas, Size size) {
    final topFieldRect = Rect.fromLTWH(0, 0, size.width, size.height * 0.5);
    final topFieldPaint = Paint()
      ..shader = const LinearGradient(
        colors: [Color(0xFF9FD49B), Color(0xFF6EA96C)],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ).createShader(topFieldRect);
    canvas.drawRect(topFieldRect, topFieldPaint);

    final bottomFieldRect = Rect.fromLTWH(
      0,
      size.height * 0.5,
      size.width,
      size.height * 0.5,
    );
    final bottomFieldPaint = Paint()
      ..shader = const LinearGradient(
        colors: [Color(0xFF8DD37F), Color(0xFF4F964D)],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ).createShader(bottomFieldRect);
    canvas.drawRect(bottomFieldRect, bottomFieldPaint);

    final hazePaint = Paint()
      ..shader = const LinearGradient(
        colors: [Color(0x55FFFFFF), Color(0x00FFFFFF)],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height * 0.24));
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height * 0.24),
      hazePaint,
    );

    final gridPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.08)
      ..strokeWidth = 1;
    for (double x = 24; x < size.width; x += 36) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
    }
    for (double y = 24; y < size.height; y += 36) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    final riverRect = Rect.fromLTWH(
      0,
      size.height * 0.455,
      size.width,
      size.height * 0.09,
    );
    final riverPaint = Paint()
      ..shader = const LinearGradient(
        colors: [
          Color(0xFF9BE7FF),
          Color(0xFF39A0C5),
          Color(0xFF0E7490),
          Color(0xFF39A0C5),
        ],
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
      ).createShader(riverRect);
    canvas.drawRect(riverRect, riverPaint);

    final bridgeRect = Rect.fromLTWH(
      size.width * 0.38,
      size.height * 0.43,
      size.width * 0.24,
      size.height * 0.14,
    );
    final bridgePaint = Paint()
      ..shader = const LinearGradient(
        colors: [Color(0xFFDCC7A0), Color(0xFFB58A60)],
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
      ).createShader(bridgeRect);
    canvas.drawRRect(
      RRect.fromRectAndRadius(bridgeRect, const Radius.circular(18)),
      bridgePaint,
    );

    final bridgeRail = Paint()
      ..color = Colors.white.withValues(alpha: 0.24)
      ..strokeWidth = 2;
    canvas.drawLine(
      Offset(bridgeRect.left + 12, bridgeRect.top + 8),
      Offset(bridgeRect.left + 12, bridgeRect.bottom - 8),
      bridgeRail,
    );
    canvas.drawLine(
      Offset(bridgeRect.right - 12, bridgeRect.top + 8),
      Offset(bridgeRect.right - 12, bridgeRect.bottom - 8),
      bridgeRail,
    );

    final lanePaint = Paint()
      ..color = const Color(0xFF7B5E57).withValues(alpha: 0.2);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(size.width * 0.43, 0, size.width * 0.14, size.height),
        const Radius.circular(22),
      ),
      lanePaint,
    );

    final roadLine = Paint()
      ..color = Colors.white.withValues(alpha: 0.24)
      ..strokeWidth = 2.2;
    canvas.drawLine(
      Offset(size.width * 0.5, 0),
      Offset(size.width * 0.5, size.height),
      roadLine,
    );

    final deployPaint = Paint()
      ..color = const Color(0xFF1B8F5A).withValues(alpha: 0.1);
    final deployRect = Rect.fromLTWH(
      0,
      size.height * 0.58,
      size.width,
      size.height * 0.42,
    );
    canvas.drawRect(deployRect, deployPaint);

    final deployBorder = Paint()
      ..color = const Color(0xFF3ECF8E).withValues(alpha: 0.34)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawRRect(
      RRect.fromRectAndRadius(deployRect.deflate(8), const Radius.circular(18)),
      deployBorder,
    );

    final bushPaint = Paint()
      ..color = const Color(0xFF2D6A4F).withValues(alpha: 0.2);
    canvas.drawCircle(
      Offset(size.width * 0.22, size.height * 0.18),
      24,
      bushPaint,
    );
    canvas.drawCircle(
      Offset(size.width * 0.78, size.height * 0.22),
      22,
      bushPaint,
    );
    canvas.drawCircle(
      Offset(size.width * 0.2, size.height * 0.8),
      24,
      bushPaint,
    );
    canvas.drawCircle(
      Offset(size.width * 0.76, size.height * 0.76),
      24,
      bushPaint,
    );

    final accentCircle = Paint()
      ..color =
          (playerSide == 'left'
                  ? const Color(0xFF25B7D3)
                  : const Color(0xFFE25555))
              .withValues(alpha: 0.16);
    canvas.drawCircle(
      Offset(size.width * 0.5, size.height * 0.78),
      58,
      accentCircle,
    );
  }

  @override
  bool shouldRepaint(covariant _ArenaPainter oldDelegate) {
    return oldDelegate.playerSide != playerSide;
  }
}

class _TowerToken extends StatelessWidget {
  const _TowerToken({
    required this.label,
    required this.color,
    required this.towerHp,
  });

  final String label;
  final Color color;
  final int towerHp;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 68,
          height: 84,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [color, color.withValues(alpha: 0.72)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: Colors.white.withValues(alpha: 0.6)),
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: 0.32),
                blurRadius: 18,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          alignment: Alignment.center,
          child: const Icon(
            Icons.castle_rounded,
            color: Colors.white,
            size: 36,
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: 98,
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Color(0xFF102030),
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const SizedBox(height: 2),
        Text(
          '$towerHp',
          style: const TextStyle(
            color: Color(0xFF102030),
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}

class _UnitToken extends StatelessWidget {
  const _UnitToken({
    required this.unit,
    required this.friendly,
    this.size = 44,
  });

  final RoyaleUnitView unit;
  final bool friendly;
  final double size;

  @override
  Widget build(BuildContext context) {
    final color = friendly ? const Color(0xFF039BE5) : const Color(0xFFD32F2F);
    final progress = unit.maxHp == 0 ? 0.0 : unit.hp / unit.maxHp;
    final iconSize = size;
    final barWidth = size - 2;
    final labelFontSize = size * 0.32;
    final shadowOffset = (size * 0.2).clamp(6.0, 12.0);

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Column(
          children: [
            Container(
              width: iconSize,
              height: iconSize,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [color, color.withValues(alpha: 0.72)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
                boxShadow: [
                  BoxShadow(
                    color: color.withValues(alpha: 0.24),
                    blurRadius: 12,
                    offset: Offset(0, shadowOffset),
                  ),
                ],
              ),
              alignment: Alignment.center,
              child: Text(
                unit
                    .localizedName(context.watch<LocaleProvider>().locale)
                    .characters
                    .first,
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: labelFontSize,
                ),
              ),
            ),
            const SizedBox(height: 4),
            Container(
              width: barWidth,
              height: 6,
              decoration: BoxDecoration(
                color: Colors.black12,
                borderRadius: BorderRadius.circular(999),
              ),
              alignment: Alignment.centerLeft,
              child: FractionallySizedBox(
                widthFactor: progress.clamp(0.0, 1.0),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.lightGreenAccent.shade400,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
            ),
          ],
        ),
        if (unit.effects.isNotEmpty)
          Positioned(
            right: -6,
            top: -6,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
              decoration: BoxDecoration(
                color: const Color(0xFFFFD166),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: Colors.white, width: 1.4),
              ),
              child: Text(
                '+${unit.effects.length}',
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _AttackRangeIndicator extends StatelessWidget {
  const _AttackRangeIndicator({
    required this.width,
    required this.height,
    required this.friendly,
  });

  final double width;
  final double height;
  final bool friendly;

  @override
  Widget build(BuildContext context) {
    final color = friendly ? const Color(0xFF4FC3F7) : const Color(0xFFFF8A80);
    return IgnorePointer(
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(9999),
          border: Border.all(color: color.withValues(alpha: 0.24), width: 1.4),
        ),
      ),
    );
  }
}

class _AimMarker extends StatelessWidget {
  const _AimMarker({
    required this.point,
    required this.active,
    this.showLabel = true,
  });

  final Offset point;
  final bool active;
  final bool showLabel;

  @override
  Widget build(BuildContext context) {
    final markerColor = active
        ? const Color(0xFFFFD166)
        : Colors.white.withValues(alpha: 0.82);

    return IgnorePointer(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: markerColor, width: 2.2),
              boxShadow: [
                BoxShadow(
                  color: markerColor.withValues(alpha: 0.24),
                  blurRadius: 18,
                ),
              ],
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                Container(width: 2, height: 32, color: markerColor),
                Container(width: 32, height: 2, color: markerColor),
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: markerColor,
                    shape: BoxShape.circle,
                  ),
                ),
              ],
            ),
          ),
          if (showLabel) ...[
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFF07111F).withValues(alpha: 0.74),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
              ),
              child: Text(
                'x ${(point.dx * _worldScale).round()} / y ${(point.dy * _worldScale).round()}',
                style: TextStyle(
                  color: markerColor,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _DragCursorFeedback extends StatelessWidget {
  const _DragCursorFeedback();

  @override
  Widget build(BuildContext context) {
    return const _AimMarker(
      point: Offset(0.5, 0.5),
      active: true,
      showLabel: false,
    );
  }
}

class _ComboLauncher extends StatelessWidget {
  const _ComboLauncher({
    required this.cards,
    required this.totalCost,
    this.onClear,
  });

  final List<RoyaleCard> cards;
  final int totalCost;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF311B92), Color(0xFF512DA8), Color(0xFF7E57C2)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.24),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.14),
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: const Icon(Icons.layers_rounded, color: Colors.white),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Combo Cast Ready',
                  style: TextStyle(
                    color: Colors.white70,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  cards
                      .map(
                        (card) => card.localizedName(
                          context.watch<LocaleProvider>().locale,
                        ),
                      )
                      .join(' + '),
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              '$totalCost',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          if (onClear != null) ...[
            const SizedBox(width: 10),
            IconButton(
              onPressed: onClear,
              style: IconButton.styleFrom(
                backgroundColor: Colors.white.withValues(alpha: 0.12),
                foregroundColor: Colors.white,
              ),
              icon: const Icon(Icons.close_rounded),
            ),
          ],
        ],
      ),
    );
  }
}

class _HandCard extends StatelessWidget {
  const _HandCard({
    required this.card,
    required this.playable,
    required this.cardColor,
    required this.cardStats,
    required this.typeLabel,
    this.selectedOrder = -1,
  });

  final RoyaleCard card;
  final bool playable;
  final Color cardColor;
  final String cardStats;
  final String typeLabel;
  final int selectedOrder;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: playable ? 1 : 0.48,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: 156,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [cardColor, cardColor.withValues(alpha: 0.78)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(
                color: selectedOrder >= 0
                    ? const Color(0xFFFFD166)
                    : Colors.white.withValues(alpha: 0.16),
                width: selectedOrder >= 0 ? 2.5 : 1.1,
              ),
              boxShadow: [
                BoxShadow(
                  color: cardColor.withValues(alpha: 0.18),
                  blurRadius: 10,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.16),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        typeLabel,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 11,
                        ),
                      ),
                    ),
                    const Spacer(),
                    CircleAvatar(
                      radius: 16,
                      backgroundColor: Colors.white.withValues(alpha: 0.18),
                      child: Text(
                        '${card.elixirCost}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Text(
                  card.localizedName(context.watch<LocaleProvider>().locale),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 18,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  cardStats,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white70, height: 1.3),
                ),
              ],
            ),
          ),
          if (selectedOrder >= 0)
            Positioned(
              right: -8,
              top: -8,
              child: CircleAvatar(
                radius: 15,
                backgroundColor: const Color(0xFFFFD166),
                child: Text(
                  '${selectedOrder + 1}',
                  style: const TextStyle(
                    color: Colors.black,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
          if (!playable)
            Positioned(
              left: 12,
              bottom: -8,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF07111F),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  context.watch<LocaleProvider>().translation.text(
                    'Not enough elixir',
                  ),
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
