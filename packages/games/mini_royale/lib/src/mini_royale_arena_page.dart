import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:taiwan_brawl_game_mini_royale/taiwan_brawl_game_mini_royale.dart';
import 'package:taiwan_brawl_game_mini_royale/taiwan_brawl_game_mini_royale.dart'
    as battle_rules;

part 'arena_page_battlefield_layout.dart';
part 'arena_page_room_layout.dart';
part 'arena_page_board_widgets.dart';
part 'arena_page_chrome.dart';

const Duration _hostStateSyncInterval = Duration(milliseconds: 100);
const Duration _socketReconnectDelay = Duration(milliseconds: 250);
const Duration _battlePollingInterval = Duration(milliseconds: 800);
const Duration _lobbyPollingInterval = Duration(milliseconds: 1500);
const int _socketFailureSnackbarThreshold = 3;

class MiniRoyaleArenaPage extends StatefulWidget {
  const MiniRoyaleArenaPage({
    super.key,
    required this.roomCode,
    required this.onExitToHome,
  });

  final String roomCode;
  final VoidCallback onExitToHome;

  @override
  State<MiniRoyaleArenaPage> createState() => _MiniRoyaleArenaPageState();
}

class _MiniRoyaleArenaPageState extends State<MiniRoyaleArenaPage> {
  late final MiniRoyaleService _service;
  late final MiniRoyaleArenaSocialPort _arenaSocial;
  final GlobalKey _arenaKey = GlobalKey();
  final MiniRoyaleBattleSelectionState _battleSelection =
      MiniRoyaleBattleSelectionState();
  MiniRoyaleRoomConnection? _channel;
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
  String? _friendDrawerBusyKey;
  String? _lastSeenBattleEventId;
  bool _battleEventDialogOpen = false;
  bool _showCollisionRadiusOverlay = false;
  MiniRoyaleArenaPresentation _arenaPresentation =
      MiniRoyaleArenaPresentation.fallback;

  MiniRoyaleLocalizationPort get _t =>
      context.read<MiniRoyaleLocalizationPort>();

  void _toggleCollisionRadiusOverlay() {
    setState(() {
      _showCollisionRadiusOverlay = !_showCollisionRadiusOverlay;
    });
  }

  @override
  void initState() {
    super.initState();
    _service = context.read<MiniRoyaleService>();
    _arenaSocial = context.read<MiniRoyaleArenaSocialPort>();
    unawaited(_loadArenaPresentation());
    _bootstrap();
  }

  Future<void> _loadArenaPresentation() async {
    try {
      final presentation = await loadMiniRoyaleArenaPresentation(
        context.read<MiniRoyaleArenaPresentationSource>(),
      );
      if (mounted) setState(() => _arenaPresentation = presentation);
    } on Object {
      // A missing/corrupt local presentation cache must not block battles.
    }
  }

  @override
  void dispose() {
    _pingTimer?.cancel();
    _roomStatePollTimer?.cancel();
    _hostStateSyncTimer?.cancel();
    _socketReconnectTimer?.cancel();
    _socketSubscription?.cancel();
    unawaited(_channel?.close());
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
      _prefetchBattleAnimations(room);
      _primeLatestBattleEvent(room);
      if (_shouldUseLiveSocket(room)) {
        _connectSocket();
      } else {
        _startRoomStatePolling();
      }
      if (_usesHostSimulation(room)) {
        await _initializeHostBattle(room);
      }
    } on MiniRoyaleServiceException catch (e) {
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

    final room = _room;
    final interval = room?.status == 'battle'
        ? _battlePollingInterval
        : _lobbyPollingInterval;
    _roomStatePollTimer = Timer.periodic(interval, (_) {
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
    } on MiniRoyaleServiceException {
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

  bool _isFriendDrawerBusy(String key) => _friendDrawerBusyKey == key;

  bool _isFriendUser(int userId) => _arenaSocial.isFriend(userId);

  bool _hasOutgoingFriendRequest(int userId) =>
      _arenaSocial.hasOutgoingFriendRequest(userId);

  bool get _canInviteFriendsFromDrawer {
    final room = _room;
    if (room == null) {
      return false;
    }
    return room.status == 'lobby' && room.players.length < 2;
  }

  Future<void> _runFriendDrawerAction(
    String busyKey,
    Future<void> Function() action, {
    String? successMessage,
  }) async {
    if (_friendDrawerBusyKey != null) {
      return;
    }

    setState(() {
      _friendDrawerBusyKey = busyKey;
    });

    try {
      await action();
      if (!mounted) {
        return;
      }
      await _refreshFriendState();
      if (!mounted) {
        return;
      }
      if (successMessage != null) {
        _showSnackBar(successMessage);
      }
    } on MiniRoyaleArenaSocialException catch (e) {
      if (!mounted) {
        return;
      }
      _showSnackBar(e.message);
    } finally {
      if (mounted) {
        setState(() {
          _friendDrawerBusyKey = null;
        });
      }
    }
  }

  Future<void> _inviteFriendFromDrawer(MiniRoyaleArenaFriend friend) async {
    await _runFriendDrawerAction(
      'invite-${friend.userId}',
      () => _arenaSocial.sendRoomInvite(
        roomCode: widget.roomCode,
        userId: friend.userId,
      ),
      successMessage: _t.text('Battle invite sent'),
    );
  }

  Future<void> _openFriendSearchDialog() async {
    await _arenaSocial.openSearch(context: context, onMessage: _showSnackBar);
  }

  void _applyRoomSnapshot(RoyaleRoomSnapshot room) {
    setState(() {
      _room = room;
      _syncSelectionWithRoom(room);
    });
    _prefetchBattleAnimations(room);
    _showLatestBattleEventIfNeeded(room);
    if (_isLocalOnlyHostBotBattle(room) && _hostBattleEngine != null) {
      _stopRoomStatePolling();
      return;
    }
    if (_shouldUseLiveSocket(room)) {
      _stopRoomStatePolling();
      if (_channel == null) {
        _connectSocket();
      }
    } else {
      _stopRoomStatePolling();
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
      final gameplayRules = await loadMiniRoyaleGameplayRules(
        source: context.read<MiniRoyaleGameplayRulesSource>(),
        gameContract: room.gameContract,
      );
      if (!mounted) return;
      late final HostBattleEngine engine;
      engine = HostBattleEngine(
        room: room,
        gameplayRules: gameplayRules,
        llmService: _service,
        onNotice: _showSnackBar,
        onSnapshot: (snapshot) {
          if (!mounted) {
            return;
          }
          setState(() {
            _room = snapshot;
            _syncSelectionWithRoom(snapshot);
          });
          _prefetchBattleAnimations(snapshot);
          _showLatestBattleEventIfNeeded(snapshot);
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
      _prefetchBattleAnimations(engine.snapshot);
      if (_isLocalOnlyHostBotBattle(engine.snapshot)) {
        _stopRoomStatePolling();
      }
      engine.start();
    } catch (e) {
      _showSnackBar('${_t.text('Action failed')}: $e');
    }
  }

  void _prefetchBattleAnimations(RoyaleRoomSnapshot room) {
    if (!mounted || room.status != 'battle') {
      return;
    }
    final cacheService = context.read<BattleAnimationCacheService>();
    if (!cacheService.enabled) {
      return;
    }
    unawaited(cacheService.prefetchForRoom(room));
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
    channel.send({'type': 'host_state', 'state': state});
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
      unawaited(channel.close());
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
    } on MiniRoyaleServiceException catch (e) {
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
    await _arenaSocial.refresh();
  }

  void _primeLatestBattleEvent(RoyaleRoomSnapshot room) {
    final latest = _latestBattleEventForViewer(room);
    if (latest == null) {
      return;
    }
    _lastSeenBattleEventId = latest.id;
  }

  RoyaleBattleEvent? _latestBattleEventForViewer(RoyaleRoomSnapshot room) {
    final viewerSide = room.viewerSide;
    final events = room.battle?.events;
    if (viewerSide == null || events == null || events.isEmpty) {
      return null;
    }
    for (final event in events.reversed) {
      if (event.side == viewerSide || event.side == 'both') {
        return event;
      }
    }
    return null;
  }

  void _showLatestBattleEventIfNeeded(RoyaleRoomSnapshot room) {
    final latest = _latestBattleEventForViewer(room);
    if (latest == null || latest.id == _lastSeenBattleEventId) {
      return;
    }
    _lastSeenBattleEventId = latest.id;
    if (_battleEventDialogOpen || !mounted) {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      unawaited(_showBattleEventDialog(latest));
    });
  }

  Offset _defaultJobDropPoint() {
    final viewerSide = _room?.viewerSide ?? 'left';
    return viewerSide == 'left'
        ? const Offset(0.5, 0.82)
        : const Offset(0.5, 0.18);
  }

  Future<void> _showBattleEventDialog(RoyaleBattleEvent event) async {
    if (_battleEventDialogOpen || !mounted) {
      return;
    }
    _battleEventDialogOpen = true;
    final locale = _t.locale;
    final theme = Theme.of(context);
    final deltas = <({String label, double value, Color color, IconData icon})>[
      if (event.moneyDelta != 0)
        (
          label: _t.text('Money'),
          value: event.moneyDelta,
          color: event.moneyDelta > 0
              ? const Color(0xFF2E7D32)
              : const Color(0xFFC62828),
          icon: Icons.attach_money_rounded,
        ),
      if (event.physicalHealthDelta != 0)
        (
          label: _t.text('Physical Health'),
          value: event.physicalHealthDelta,
          color: event.physicalHealthDelta > 0
              ? const Color(0xFF2E7D32)
              : const Color(0xFFC62828),
          icon: Icons.favorite_border_rounded,
        ),
      if (event.spiritHealthDelta != 0)
        (
          label: _t.text('Spirit Health'),
          value: event.spiritHealthDelta,
          color: event.spiritHealthDelta > 0
              ? const Color(0xFF2E7D32)
              : const Color(0xFFC62828),
          icon: Icons.psychology_alt_outlined,
        ),
      if (event.physicalEnergyDelta != 0)
        (
          label: _t.text('Physical Energy'),
          value: event.physicalEnergyDelta,
          color: event.physicalEnergyDelta > 0
              ? const Color(0xFF2E7D32)
              : const Color(0xFFC62828),
          icon: Icons.bolt_outlined,
        ),
      if (event.spiritEnergyDelta != 0)
        (
          label: _t.text('Spirit Energy'),
          value: event.spiritEnergyDelta,
          color: event.spiritEnergyDelta > 0
              ? const Color(0xFF2E7D32)
              : const Color(0xFFC62828),
          icon: Icons.auto_awesome_outlined,
        ),
    ];

    try {
      await showDialog<void>(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: Text(event.localizedTitle(locale)),
            content: SizedBox(
              width: 420,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    event.localizedCardName(locale),
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(event.localizedDescription(locale)),
                  if (deltas.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: deltas
                          .map(
                            (entry) => Chip(
                              avatar: Icon(
                                entry.icon,
                                size: 18,
                                color: entry.color,
                              ),
                              label: Text(
                                '${entry.label} ${entry.value > 0 ? '+' : ''}${entry.value.toStringAsFixed(1)}',
                              ),
                              side: BorderSide(color: entry.color),
                            ),
                          )
                          .toList(),
                    ),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('OK'),
              ),
            ],
          );
        },
      );
    } finally {
      _battleEventDialogOpen = false;
    }
  }

  void _syncSelectionWithRoom(RoyaleRoomSnapshot room) {
    if (room.battle == null) {
      if (room.status != 'battle') {
        _battleSelection.clear();
        _aimPoint = null;
      }
      return;
    }
    final handIds =
        room.battle?.yourHand.map((card) => card.id).toSet() ?? <String>{};
    final hasCompleteHandSnapshot = handIds.length >= 4;
    if (!hasCompleteHandSnapshot) {
      return;
    }
    _battleSelection.reconcileWithHand(room.battle!.yourHand);
  }

  Future<void> _connectSocket() async {
    if (_channel != null || _isConnectingSocket) {
      return;
    }
    _socketReconnectTimer?.cancel();
    _socketReconnectTimer = null;
    _isConnectingSocket = true;

    try {
      _channel = await _service.connectToRoom(widget.roomCode);
      _flushHostStateSync();
      _socketSubscription = _channel!.messages.listen(
        _handleSocketPayload,
        onError: (_) => _handleSocketDisconnected(),
        onDone: _handleSocketDisconnected,
      );

      _pingTimer = Timer.periodic(const Duration(seconds: 10), (_) {
        _channel?.send({'type': 'ping'});
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
    final decoded = MiniRoyaleRoomCommandCodec.decodeHostCommand(command);
    if (decoded is MiniRoyaleRemoteDiscardCommand) {
      final error = _hostBattleEngine?.applyRemoteDiscard(
        side: decoded.side,
        cardId: decoded.cardId,
      );
      if (error != null) {
        _showSnackBar(error);
        return;
      }
      final engine = _hostBattleEngine;
      if (engine != null) {
        _scheduleHostStateSync(engine.exportBattleState(), immediate: true);
      }
      return;
    }
    if (decoded is! MiniRoyaleRemotePlayCommand) {
      return;
    }

    final error = _hostBattleEngine?.applyRemoteCombo(
      side: decoded.side,
      cardIds: decoded.cardIds,
      dropX: decoded.dropX,
      dropY: decoded.dropY,
    );
    if (error != null) {
      _showSnackBar(error);
      return;
    }
    final engine = _hostBattleEngine;
    if (engine != null) {
      _scheduleHostStateSync(engine.exportBattleState(), immediate: true);
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
    } on MiniRoyaleServiceException catch (e) {
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
    if (card.isJob) {
      if (_battleSelection.isNotEmpty) {
        _showSnackBar(_t.text('Job cards must be played alone'));
        return;
      }
      if (!MiniRoyaleBattleSelection.canAffordCard(_room?.me, card)) {
        _showSnackBar(
          _notEnoughEnergyMessageForType(miniRoyaleCardEnergyType(card)),
        );
        return;
      }
      final point = _defaultJobDropPoint();
      _castCards([card], dropX: point.dx, dropY: point.dy);
      return;
    }
    final result = _battleSelection.toggle(card);
    if (result.outcome == MiniRoyaleSelectionOutcome.maximumReached) {
      _showSnackBar(_t.text('You can preselect up to 3 cards at once'));
      return;
    }
    if (result.outcome == MiniRoyaleSelectionOutcome.jobMustBePlayedAlone) {
      _showSnackBar(_t.text('Job cards must be played alone'));
      return;
    }
    setState(() {
      if (_battleSelection.isEmpty && !_dragTargetActive) _aimPoint = null;
    });
  }

  List<RoyaleCard> _selectedCards(RoyaleBattleView battle) {
    return _battleSelection.resolve(battle.yourHand);
  }

  ({int physical, int spirit, int money}) _selectedCardCosts(
    List<RoyaleCard> cards,
  ) {
    final costs = MiniRoyaleBattleSelection.costs(cards);
    return (physical: costs.physical, spirit: costs.spirit, money: costs.money);
  }

  String _notEnoughEnergyMessageForType(String energyType) {
    if (energyType == 'money') {
      return _t.text('Not enough Money');
    }
    return energyType == 'spirit'
        ? _t.text('Not enough Spirit Energy')
        : _t.text('Not enough Physical Energy');
  }

  bool _canAffordDiscard(RoyalePlayerView? player) {
    return player != null &&
        player.spiritEnergy.current + 1e-6 >= battle_rules.discardSpiritCost;
  }

  String _discardCostLabel() {
    final cost = battle_rules.discardSpiritCost;
    final value = cost == cost.roundToDouble()
        ? cost.toInt().toString()
        : cost.toStringAsFixed(1);
    return '${_energyTypeShortLabel('spirit')} $value';
  }

  String _energyTypeShortLabel(String energyType) {
    final locale = _t.locale;
    switch (locale) {
      case 'ja':
        if (energyType == 'money') {
          return '金';
        }
        return energyType == 'spirit' ? '精' : '体';
      case 'zh-Hant':
        if (energyType == 'money') {
          return '金';
        }
        return energyType == 'spirit' ? '精' : '生';
      case 'en':
      default:
        if (energyType == 'money') {
          return r'$';
        }
        return energyType == 'spirit' ? 'SP' : 'PH';
    }
  }

  String _energyCostSummary(List<RoyaleCard> cards) {
    final costs = _selectedCardCosts(cards);
    final segments = <String>[];
    if (costs.physical > 0) {
      segments.add('${_energyTypeShortLabel('physical')} ${costs.physical}');
    }
    if (costs.spirit > 0) {
      segments.add('${_energyTypeShortLabel('spirit')} ${costs.spirit}');
    }
    if (costs.money > 0) {
      segments.add('${_energyTypeShortLabel('money')} ${costs.money}');
    }
    if (segments.isEmpty) {
      segments.add('0');
    }
    return segments.join(' · ');
  }

  MiniRoyaleCardDragPayload _dragPayloadForHandCard(
    RoyaleBattleView battle,
    RoyaleCard draggedCard,
  ) {
    return _battleSelection.dragPayload(battle.yourHand, draggedCard);
  }

  bool get _hasDeploymentTarget {
    return _battleSelection.isNotEmpty || _dragTargetActive;
  }

  Offset? _normalizedDropPointForGlobalOffset(Offset globalOffset) {
    final renderBox =
        _arenaKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox == null || !renderBox.hasSize) {
      return null;
    }

    final local = renderBox.globalToLocal(globalOffset);
    return miniRoyaleNormalizeBoardPoint(
      localPoint: local,
      boardSize: renderBox.size,
    );
  }

  bool _isLegalDeployPoint(Offset point) {
    return miniRoyaleIsLegalDeployPoint(point);
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
    final prepared = MiniRoyaleBattleSelection.preparePlay(
      cards: cards,
      player: _room?.me,
      dropX: dropX,
      dropY: dropY,
      playerSide: _room?.viewerSide ?? 'left',
    );
    final command = prepared.command;
    if (command == null) {
      switch (prepared.rejection) {
        case MiniRoyalePlayRejection.emptyCombo:
          return;
        case MiniRoyalePlayRejection.invalidCombo:
          _showSnackBar(
            _t.text(
              prepared.comboError == MiniRoyaleComboError.jobMustBePlayedAlone
                  ? 'Job cards must be played alone'
                  : 'Equipment cards must be played with at least one unit card',
            ),
          );
          return;
        case MiniRoyalePlayRejection.insufficientEnergy:
          _showSnackBar(
            _notEnoughEnergyMessageForType(prepared.energyType ?? 'physical'),
          );
          return;
        case MiniRoyalePlayRejection.invalidDeploymentPoint:
          _showSnackBar(_t.text('Place cards inside your deployment zone'));
          return;
        case null:
          return;
      }
    }
    if (_usesHostSimulation()) {
      final error = _hostBattleEngine?.playCombo(
        command.cards,
        dropX: command.dropX,
        dropY: command.dropY,
      );
      if (error != null) {
        _showSnackBar(error);
        return;
      }
      final engine = _hostBattleEngine;
      if (engine != null) {
        _scheduleHostStateSync(engine.exportBattleState(), immediate: true);
      }
    } else {
      _channel?.send(MiniRoyaleRoomCommandCodec.encodePlayCombo(command));
    }
    setState(() {
      _battleSelection.clear();
      _aimPoint = Offset(command.dropX, command.dropY);
    });
  }

  void _discardCard(RoyaleCard card) {
    if (!_canAffordDiscard(_room?.me)) {
      _showSnackBar(_notEnoughEnergyMessageForType('spirit'));
      return;
    }

    if (_usesHostSimulation()) {
      final error = _hostBattleEngine?.discardCard(card.id);
      if (error != null) {
        _showSnackBar(error);
        return;
      }
      final engine = _hostBattleEngine;
      if (engine != null) {
        _scheduleHostStateSync(engine.exportBattleState(), immediate: true);
      }
    } else {
      _channel?.send(MiniRoyaleRoomCommandCodec.encodeDiscardCard(card.id));
    }

    setState(() {
      _dragTargetActive = false;
      _battleSelection.remove(card.id);
      if (_battleSelection.isEmpty) {
        _aimPoint = null;
      }
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
      _prefetchBattleAnimations(room);
    } on MiniRoyaleServiceException catch (e) {
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
    if (_hasOutgoingFriendRequest(userId) || _isFriendUser(userId)) {
      return;
    }

    try {
      await _arenaSocial.sendFriendRequest(userId);
      if (!mounted) {
        return;
      }
      await _refreshFriendState();
      if (!mounted) {
        return;
      }
      _showSnackBar('${_t.text('Sent a friend request to')} ${player.name}');
    } on MiniRoyaleArenaSocialException catch (e) {
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
    if (_isFriendUser(player.userId)) {
      return false;
    }
    if (_hasOutgoingFriendRequest(player.userId)) {
      return false;
    }
    return true;
  }

  RoyalePlayerView _placeholderPlayer(String side) {
    const placeholderHero = RoyaleHero(
      id: 'waiting',
      name: 'Waiting',
      nameZhHant: '待命',
      nameEn: 'Waiting',
      nameJa: '待機',
      bonusSummary: '',
      bonusSummaryZhHant: '',
      bonusSummaryEn: '',
      bonusSummaryJa: '',
      bonusKind: 'none',
      bonusValue: 0,
      physicalHealth: RoyaleResourceDefinition(
        initial: 0,
        max: 0,
        regenPerSecond: 0,
      ),
      spiritHealth: RoyaleResourceDefinition(
        initial: 0,
        max: 0,
        regenPerSecond: 0,
      ),
      physicalEnergy: RoyaleResourceDefinition(
        initial: 0,
        max: 0,
        regenPerSecond: 0,
      ),
      spiritEnergy: RoyaleResourceDefinition(
        initial: 0,
        max: 0,
        regenPerSecond: 0,
      ),
      money: RoyaleResourceDefinition(initial: 0, max: 0, regenPerSecond: 0),
      unitDamageMultiplier: 1,
      jobMoneyMultiplier: 1,
      jobPositiveWeightMultiplier: 1,
      jobNegativeWeightMultiplier: 1,
      mentalEventWeightMultiplier: 1,
      mentalDamageMultiplier: 1,
      mentalIllnessStageFloor: 1,
    );
    return RoyalePlayerView(
      userId: 0,
      name: _t.text('Waiting for players'),
      side: side,
      deckId: 0,
      deckName: '',
      deckCards: const [],
      handCardIds: const [],
      queueCardIds: const [],
      hero: placeholderHero,
      botController: 'heuristic',
      ready: false,
      connected: false,
      physicalHealth: const RoyaleResourceState(
        current: 0,
        max: 0,
        regenPerSecond: 0,
      ),
      spiritHealth: const RoyaleResourceState(
        current: 0,
        max: 0,
        regenPerSecond: 0,
      ),
      physicalEnergy: const RoyaleResourceState(
        current: 0,
        max: 0,
        regenPerSecond: 0,
      ),
      spiritEnergy: const RoyaleResourceState(
        current: 0,
        max: 0,
        regenPerSecond: 0,
      ),
      money: const RoyaleResourceState(current: 0, max: 0, regenPerSecond: 0),
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

  void _setDragTargetActive(bool active) {
    if (_dragTargetActive == active) {
      return;
    }
    setState(() {
      _dragTargetActive = active;
    });
  }

  void _handleBattlefieldAccept(
    DragTargetDetails<MiniRoyaleCardDragPayload> details,
  ) {
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
      if (_battleSelection.isEmpty) {
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

  void _handleBattlefieldMove(
    DragTargetDetails<MiniRoyaleCardDragPayload> details,
  ) {
    if (!_dragTargetActive) {
      _setDragTargetActive(true);
    }
    _updateAimPoint(details.offset);
  }

  @override
  Widget build(BuildContext context) {
    final t = context.watch<MiniRoyaleLocalizationPort>();
    final arenaSocial = context.watch<MiniRoyaleArenaSocialPort>();
    final isImmersiveBattle = _room != null && _room!.status != 'lobby';
    return Scaffold(
      backgroundColor: const Color(0xFF07111F),
      drawer: _buildRoomFriendDrawer(arenaSocial),
      appBar: isImmersiveBattle
          ? null
          : AppBar(
              title: Text('${t.text('Room')} ${widget.roomCode}'),
              backgroundColor: Colors.transparent,
              foregroundColor: Colors.white,
              elevation: 0,
              actions: [
                IconButton(
                  onPressed: widget.onExitToHome,
                  icon: const Icon(Icons.home_outlined),
                  tooltip: t.text('Home'),
                ),
              ],
            ),
      extendBodyBehindAppBar: !isImmersiveBattle,
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
            isImmersiveBattle
                ? _buildPageContent(t)
                : SafeArea(child: _buildPageContent(t)),
          ],
        ),
      ),
    );
  }
}
