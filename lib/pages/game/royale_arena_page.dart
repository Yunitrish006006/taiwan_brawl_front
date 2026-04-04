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
import '../../services/royale_battle_rules.dart' as battle_rules;
import '../../services/royale_service.dart';

part 'royale_arena_battlefield_layout.dart';
part 'royale_arena_room_layout.dart';
part 'royale_arena_board_widgets.dart';
part 'royale_arena_chrome.dart';
part 'royale_arena_hand_widgets.dart';

const double _battlefieldAspectRatio = battle_rules.fieldAspectRatio;
const double _battlefieldPhoneMaxWidth = 430;
const double _battlefieldDesktopMaxWidth = 520;
const int _worldScale = battle_rules.worldScale;
const Duration _hostStateSyncInterval = Duration(milliseconds: 250);
const Duration _socketReconnectDelay = Duration(milliseconds: 500);
const int _socketFailureSnackbarThreshold = 3;

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
  Timer? _roomStatePollTimer;
  Timer? _hostStateSyncTimer;
  Timer? _socketReconnectTimer;
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
  bool _isPollingRoomState = false;
  bool _isConnectingSocket = false;
  int _socketFailureCount = 0;
  DateTime? _lastHostStateSyncAt;
  Map<String, dynamic>? _pendingHostState;

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
    _roomStatePollTimer?.cancel();
    _hostStateSyncTimer?.cancel();
    _socketReconnectTimer?.cancel();
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
      if (_shouldUseLiveSocket(room)) {
        _connectSocket();
      } else {
        _startRoomStatePolling();
      }
      if (_usesHostSimulation(room)) {
        await _initializeHostBattle(room);
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
    return current?.simulationMode == 'host' &&
        current?.viewerSide == 'left' &&
        current?.hostUserId == current?.me?.userId;
  }

  bool _isLocalOnlyHostBotBattle([RoyaleRoomSnapshot? room]) {
    final current = room ?? _room;
    if (!_usesHostSimulation(current) || current == null) {
      return false;
    }

    return current.players.any(
      (player) => player.side == 'right' && player.userId <= 0,
    );
  }

  bool _hasRemoteHumanOpponent([RoyaleRoomSnapshot? room]) {
    final current = room ?? _room;
    if (current == null) {
      return false;
    }

    return current.players.any(
      (player) => player.side == 'right' && player.userId > 0,
    );
  }

  bool _shouldUseLiveSocket([RoyaleRoomSnapshot? room]) {
    final current = room ?? _room;
    if (current == null) {
      return false;
    }
    if (_isLocalOnlyHostBotBattle(current)) {
      return false;
    }
    if (_usesHostSimulation(current) && !_hasRemoteHumanOpponent(current)) {
      return false;
    }
    return true;
  }

  void _startRoomStatePolling() {
    if (_roomStatePollTimer != null) {
      return;
    }

    _roomStatePollTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      unawaited(_pollRoomState());
    });
  }

  void _stopRoomStatePolling() {
    _roomStatePollTimer?.cancel();
    _roomStatePollTimer = null;
  }

  Future<void> _pollRoomState() async {
    if (!mounted || _isPollingRoomState) {
      return;
    }
    final room = _room;
    if (room == null) {
      return;
    }
    if (_shouldUseLiveSocket(room)) {
      _stopRoomStatePolling();
      if (_channel == null) {
        _connectSocket();
      }
      return;
    }

    _isPollingRoomState = true;
    try {
      final latestRoom = await _service.fetchRoomState(widget.roomCode);
      if (!mounted) {
        return;
      }
      _applyRoomSnapshot(latestRoom);
      if (_usesHostSimulation(latestRoom)) {
        await _initializeHostBattle(latestRoom);
      }
      if (_shouldUseLiveSocket(latestRoom)) {
        _stopRoomStatePolling();
        if (_channel == null) {
          _connectSocket();
        }
      }
    } on ApiException {
      // Ignore transient polling errors while waiting in the lobby.
    } finally {
      _isPollingRoomState = false;
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

  void _applyRoomSnapshot(RoyaleRoomSnapshot room) {
    setState(() {
      _room = room;
      _syncSelectionWithRoom(room);
    });
    if (_shouldUseLiveSocket(room)) {
      _stopRoomStatePolling();
      if (_channel == null) {
        _connectSocket();
      }
    } else {
      _startRoomStatePolling();
    }
  }

  Future<void> _initializeHostBattle(RoyaleRoomSnapshot room) async {
    if (!_usesHostSimulation(room) ||
        room.battle == null ||
        _hostBattleEngine != null) {
      return;
    }

    try {
      late final HostBattleEngine engine;
      engine = HostBattleEngine(
        room: room,
        onSnapshot: (snapshot) {
          if (!mounted) {
            return;
          }
          setState(() {
            _room = snapshot;
            _syncSelectionWithRoom(snapshot);
          });
          _scheduleHostStateSync(engine.exportBattleState());
          if (snapshot.battle?.result != null) {
            _flushHostStateSync();
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
      _showSnackBar('${_t.text('Action failed')}: $e');
    }
  }

  void _scheduleHostStateSync(
    Map<String, dynamic> state, {
    bool immediate = false,
  }) {
    _pendingHostState = state;

    if (immediate) {
      _flushHostStateSync();
      return;
    }

    final lastSyncAt = _lastHostStateSyncAt;
    if (lastSyncAt == null) {
      _flushHostStateSync();
      return;
    }

    final remaining =
        _hostStateSyncInterval - DateTime.now().difference(lastSyncAt);
    if (remaining <= Duration.zero) {
      _flushHostStateSync();
      return;
    }

    if (_hostStateSyncTimer != null) {
      return;
    }

    _hostStateSyncTimer = Timer(remaining, () {
      _hostStateSyncTimer = null;
      _flushHostStateSync();
    });
  }

  void _flushHostStateSync() {
    _hostStateSyncTimer?.cancel();
    _hostStateSyncTimer = null;

    final state = _pendingHostState;
    final channel = _channel;
    if (state == null || channel == null) {
      return;
    }

    _pendingHostState = null;
    _lastHostStateSyncAt = DateTime.now();
    channel.sink.add(jsonEncode({'type': 'host_state', 'state': state}));
  }

  void _handleSocketDisconnected() {
    final channel = _channel;
    final closeCode = channel?.closeCode;
    final closeReason = channel?.closeReason;

    _pingTimer?.cancel();
    _pingTimer = null;
    _socketSubscription?.cancel();
    _socketSubscription = null;
    _channel = null;
    if (channel != null) {
      try {
        channel.sink.close();
      } catch (_) {}
    }

    debugPrint(
      'Room socket disconnected. closeCode=$closeCode closeReason=$closeReason',
    );
    _registerSocketFailure(
      'disconnect(closeCode=$closeCode, closeReason=$closeReason)',
    );
    if (_room != null) {
      _startRoomStatePolling();
      _scheduleSocketReconnect();
    }
  }

  void _registerSocketFailure(String reason) {
    _socketFailureCount += 1;
    debugPrint('Room socket failure #$_socketFailureCount: $reason');
    if (!mounted || _socketFailureCount < _socketFailureSnackbarThreshold) {
      return;
    }
    _showSnackBar(_t.text('Live connection lost. Please refresh the page.'));
  }

  void _scheduleSocketReconnect() {
    if (!mounted || !_shouldUseLiveSocket()) {
      return;
    }
    if (_socketReconnectTimer != null ||
        _channel != null ||
        _isConnectingSocket) {
      return;
    }

    _socketReconnectTimer = Timer(_socketReconnectDelay, () {
      _socketReconnectTimer = null;
      _connectSocket();
    });
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
    if (_channel != null || _isConnectingSocket) {
      return;
    }
    _socketReconnectTimer?.cancel();
    _socketReconnectTimer = null;
    _isConnectingSocket = true;

    try {
      _channel = _service.connectToRoom(widget.roomCode);
      _flushHostStateSync();
      _socketSubscription = _channel!.stream.listen(
        (message) async {
          final data = jsonDecode(message as String) as Map<String, dynamic>;
          await _handleSocketPayload(data);
        },
        onError: (_) => _handleSocketDisconnected(),
        onDone: _handleSocketDisconnected,
      );

      _pingTimer = Timer.periodic(const Duration(seconds: 10), (_) {
        _channel?.sink.add(jsonEncode({'type': 'ping'}));
      });
    } catch (error, stackTrace) {
      debugPrint('Room socket connect failed: $error');
      debugPrintStack(stackTrace: stackTrace);
      _channel = null;
      _startRoomStatePolling();
      _scheduleSocketReconnect();
      _registerSocketFailure(error.toString());
    } finally {
      _isConnectingSocket = false;
    }
  }

  Future<void> _handleSocketPayload(Map<String, dynamic> data) async {
    _socketFailureCount = 0;
    final type = data['type'] as String?;
    if (type == 'pong') {
      return;
    }
    if (type == 'error') {
      _showSnackBar(data['message'] as String? ?? _t.text('Unknown error'));
      return;
    }
    if (type == 'host_command') {
      _handleHostCommand(data['command'] as Map<String, dynamic>?);
      return;
    }

    final roomJson = data['room'] as Map<String, dynamic>?;
    if (roomJson == null || !mounted) {
      return;
    }

    final room = RoyaleRoomSnapshot.fromJson(roomJson);
    if (type == 'battle_started' && _usesHostSimulation(room)) {
      await _initializeHostBattle(room);
    }
    if (_usesHostSimulation() && type == 'state_snapshot') {
      return;
    }
    _applyRoomSnapshot(room);
  }

  void _handleHostCommand(Map<String, dynamic>? command) {
    if (command == null || !_usesHostSimulation()) {
      return;
    }

    final dropX = (command['dropX'] as num?)?.toDouble();
    final dropY = (command['dropY'] as num?)?.toDouble();
    if (dropX == null || dropY == null) {
      return;
    }

    final error = _hostBattleEngine?.applyRemoteCombo(
      side: command['side'] as String? ?? 'right',
      cardIds: (command['cardIds'] as List<dynamic>? ?? const [])
          .map((cardId) => cardId.toString())
          .toList(),
      dropX: dropX,
      dropY: dropY,
    );
    if (error != null) {
      _showSnackBar(error);
    }
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
      _applyRoomSnapshot(room);
      if (_usesHostSimulation(room)) {
        await _initializeHostBattle(room);
      }
    } on ApiException catch (e) {
      _showSnackBar(e.message);
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
      _showSnackBar(_t.text('You can preselect up to 3 cards at once'));
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

  int _selectedCardCost(List<RoyaleCard> cards) {
    return cards.fold<int>(0, (sum, card) => sum + card.elixirCost);
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
    return battle_rules.isLegalDeployPoint(point.dx, point.dy);
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
      _showSnackBar(
        _t.text('Equipment cards must be played with at least one unit card'),
      );
      return;
    }

    final dropPoint = Offset(dropX, dropY);
    if (!_isLegalDeployPoint(dropPoint)) {
      _showSnackBar(_t.text('Place cards inside your deployment zone'));
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
        _showSnackBar(error);
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
      _hostStateSyncTimer?.cancel();
      _socketReconnectTimer?.cancel();
      setState(() {
        _hostBattleEngine?.dispose();
        _hostBattleEngine = null;
        _hostFinishSubmitting = false;
        _hostFinishSent = false;
        _pendingHostState = null;
        _lastHostStateSyncAt = null;
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
      _showSnackBar('${_t.text('Sent a friend request to')} ${player.name}');
    } on ApiException catch (e) {
      if (!mounted) {
        return;
      }
      _showSnackBar(e.message);
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

  double _boardWidthFor(BoxConstraints constraints, bool compact) {
    final maxWidth = compact
        ? _battlefieldPhoneMaxWidth
        : _battlefieldDesktopMaxWidth;
    return constraints.maxWidth < maxWidth ? constraints.maxWidth : maxWidth;
  }

  RoyalePlayerView _placeholderPlayer(String side) {
    return RoyalePlayerView(
      userId: 0,
      name: _t.text('Waiting for players'),
      side: side,
      deckId: 0,
      deckName: '',
      deckCards: const [],
      elixir: null,
      handCardIds: const [],
      queueCardIds: const [],
      ready: false,
      connected: false,
      towerHp: 0,
      maxTowerHp: 1,
    );
  }

  RoyalePlayerView _playerBySideOrPlaceholder(
    RoyaleRoomSnapshot room,
    String side,
  ) {
    for (final player in room.players) {
      if (player.side == side) {
        return player;
      }
    }
    return _placeholderPlayer(side);
  }

  String _battlefieldHintText(
    bool highlightDropZone,
    List<RoyaleCard> selectedCards,
  ) {
    if (highlightDropZone) {
      return _t.text('Release to cast all selected cards here');
    }
    if (selectedCards.isNotEmpty) {
      return _t.text(
        'Precision targeting enabled. Tap the battlefield to place cards.',
      );
    }
    return _t.text(
      'Drag a single card or combo, or select cards first then tap the 2D battlefield.',
    );
  }

  void _setDragTargetActive(bool active) {
    if (_dragTargetActive == active) {
      return;
    }
    setState(() {
      _dragTargetActive = active;
    });
  }

  void _handleBattlefieldAccept(DragTargetDetails<_ComboDragPayload> details) {
    _setDragTargetActive(false);
    final point = _normalizedDropPointForGlobalOffset(details.offset);
    if (point == null) {
      return;
    }
    _castCards(details.data.cards, dropX: point.dx, dropY: point.dy);
  }

  void _handleBattlefieldLeave() {
    setState(() {
      _dragTargetActive = false;
      if (_selectedCardIds.isEmpty) {
        _aimPoint = null;
      }
    });
  }

  void _handleBattlefieldTap(
    TapDownDetails details,
    List<RoyaleCard> selectedCards,
  ) {
    final point = _normalizedDropPointForGlobalOffset(details.globalPosition);
    if (point == null) {
      return;
    }
    _castCards(selectedCards, dropX: point.dx, dropY: point.dy);
  }

  void _handleBattlefieldMove(DragTargetDetails<_ComboDragPayload> details) {
    if (!_dragTargetActive) {
      _setDragTargetActive(true);
    }
    _updateAimPoint(details.offset);
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
            SafeArea(child: _buildPageContent(t)),
          ],
        ),
      ),
    );
  }
}
