import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../../constants/app_constants.dart';
import '../../models/friends_models.dart';
import '../../models/royale_models.dart';
import '../../services/api_client.dart';
import '../../services/auth_service.dart';
import '../../services/battle_animation_cache_service.dart';
import '../../services/friends_service.dart';
import '../../services/friends_overview_sync_service.dart';
import '../../services/host_battle_engine.dart';
import '../../services/locale_provider.dart';
import '../../services/royale_battle_rules.dart' as battle_rules;
import '../../services/royale_service.dart';
import '../../widgets/friend_search_dialog.dart';

part 'royale_arena_battlefield_layout.dart';
part 'royale_arena_room_layout.dart';
part 'royale_arena_board_widgets.dart';
part 'royale_arena_chrome.dart';
part 'royale_arena_hand_widgets.dart';

const double _battlefieldAspectRatio = battle_rules.fieldAspectRatio;
const double _battlefieldPhoneMaxWidth = 430;
const double _battlefieldDesktopMaxWidth = 520;
const int _worldScale = battle_rules.worldScale;
const Duration _hostStateSyncInterval = Duration(milliseconds: 100);
const Duration _socketReconnectDelay = Duration(milliseconds: 250);
const Duration _battlePollingInterval = Duration(milliseconds: 800);
const Duration _lobbyPollingInterval = Duration(milliseconds: 1500);
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
  String? _friendDrawerBusyKey;
  String? _lastSeenBattleEventId;
  bool _battleEventDialogOpen = false;

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

  bool _isFriendDrawerBusy(String key) => _friendDrawerBusyKey == key;

  FriendsOverview? get _currentFriendsOverview =>
      context.read<FriendsOverviewSyncService>().overview;

  bool _isFriendUser(int userId) {
    return _currentFriendsOverview?.friends.any(
          (friend) => friend.userId == userId,
        ) ??
        false;
  }

  bool _hasOutgoingFriendRequest(int userId) {
    return _currentFriendsOverview?.outgoingRequests.any(
          (request) => request.user.userId == userId,
        ) ??
        false;
  }

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
    } on ApiException catch (e) {
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

  Future<void> _inviteFriendFromDrawer(SocialUser friend) async {
    await _runFriendDrawerAction(
      'invite-${friend.userId}',
      () => _friendsService.sendRoomInvite(
        roomCode: widget.roomCode,
        inviteeUserId: friend.userId,
      ),
      successMessage: _t.text('Battle invite sent'),
    );
  }

  Future<void> _openFriendSearchDialog() async {
    await showFriendSearchDialog(
      context: context,
      friendsService: _friendsService,
      onRefreshFriends: _refreshFriendState,
      onMessage: _showSnackBar,
    );
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
      late final HostBattleEngine engine;
      engine = HostBattleEngine(
        room: room,
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
    await context.read<FriendsOverviewSyncService>().refreshFor(
      context.read<AuthService>(),
    );
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
    final locale = context.read<LocaleProvider>().locale;
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
        _selectedCardIds.clear();
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
    if (card.isJob) {
      if (_selectedCardIds.isNotEmpty) {
        _showSnackBar(_t.text('Job cards must be played alone'));
        return;
      }
      if (!_canAffordCard(_room?.me, card)) {
        _showSnackBar(_notEnoughEnergyMessageForType(_cardEnergyType(card)));
        return;
      }
      final point = _defaultJobDropPoint();
      _castCards([card], dropX: point.dx, dropY: point.dy);
      return;
    }
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

  String _cardEnergyType(RoyaleCard card) => card.usesMoney
      ? 'money'
      : card.usesSpiritEnergy
      ? 'spirit'
      : 'physical';

  int _cardEnergyCost(RoyaleCard card) => card.energyCost;

  double _playerResourceForType(RoyalePlayerView? player, String energyType) {
    if (player == null) {
      return 0;
    }
    if (energyType == 'money') {
      return player.money.current;
    }
    return energyType == 'spirit'
        ? player.spiritEnergy.current
        : player.physicalEnergy.current;
  }

  bool _canAffordCard(RoyalePlayerView? player, RoyaleCard card) {
    return _playerResourceForType(player, _cardEnergyType(card)) + 1e-6 >=
        _cardEnergyCost(card);
  }

  ({int physical, int spirit, int money}) _selectedCardCosts(
    List<RoyaleCard> cards,
  ) {
    var physical = 0;
    var spirit = 0;
    var money = 0;
    for (final card in cards) {
      if (card.usesMoney) {
        money += _cardEnergyCost(card);
      } else if (card.usesSpiritEnergy) {
        spirit += _cardEnergyCost(card);
      } else {
        physical += _cardEnergyCost(card);
      }
    }
    return (physical: physical, spirit: spirit, money: money);
  }

  bool _canAffordCards(RoyalePlayerView? player, List<RoyaleCard> cards) {
    final costs = _selectedCardCosts(cards);
    return _playerResourceForType(player, 'physical') + 1e-6 >=
            costs.physical &&
        _playerResourceForType(player, 'spirit') + 1e-6 >= costs.spirit &&
        _playerResourceForType(player, 'money') + 1e-6 >= costs.money;
  }

  String _notEnoughEnergyMessageForType(String energyType) {
    if (energyType == 'money') {
      return _t.text('Not enough Money');
    }
    return energyType == 'spirit'
        ? _t.text('Not enough Spirit Energy')
        : _t.text('Not enough Physical Energy');
  }

  String _notEnoughEnergyMessageForCards(
    RoyalePlayerView? player,
    List<RoyaleCard> cards,
  ) {
    final costs = _selectedCardCosts(cards);
    if (_playerResourceForType(player, 'physical') + 1e-6 < costs.physical) {
      return _notEnoughEnergyMessageForType('physical');
    }
    if (_playerResourceForType(player, 'spirit') + 1e-6 < costs.spirit) {
      return _notEnoughEnergyMessageForType('spirit');
    }
    if (_playerResourceForType(player, 'money') + 1e-6 < costs.money) {
      return _notEnoughEnergyMessageForType('money');
    }
    return _t.text('Not enough energy');
  }

  String _energyTypeShortLabel(String energyType) {
    final locale = context.read<LocaleProvider>().locale;
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

  String _cardEnergyLabel(RoyaleCard card) {
    return '${_energyTypeShortLabel(_cardEnergyType(card))} ${_cardEnergyCost(card)}';
  }

  _ComboDragPayload _dragPayloadForHandCard(
    RoyaleBattleView battle,
    RoyaleCard draggedCard,
  ) {
    final selectedCards = _selectedCards(battle);
    final shouldUseSelectedCombo =
        selectedCards.length > 1 &&
        selectedCards.any((card) => card.id == draggedCard.id);

    return _ComboDragPayload(
      cards: shouldUseSelectedCombo ? selectedCards : [draggedCard],
    );
  }

  bool get _hasDeploymentTarget {
    return _selectedCardIds.isNotEmpty || _dragTargetActive;
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

    final hasJobCard = cards.any((card) => card.isJob);
    final hasEquipment = cards.any((card) => card.isEquipment);
    final hasUnit = cards.any(
      (card) => card.type != 'equipment' && card.type != 'spell' && !card.isJob,
    );

    if (hasEquipment && !hasUnit) {
      _showSnackBar(
        _t.text('Equipment cards must be played with at least one unit card'),
      );
      return;
    }
    if (hasJobCard && cards.length != 1) {
      _showSnackBar(_t.text('Job cards must be played alone'));
      return;
    }
    if (!_canAffordCards(_room?.me, cards)) {
      _showSnackBar(_notEnoughEnergyMessageForCards(_room?.me, cards));
      return;
    }

    final dropPoint = Offset(dropX, dropY);
    if (!hasJobCard && !_isLegalDeployPoint(dropPoint)) {
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
      final engine = _hostBattleEngine;
      if (engine != null) {
        _scheduleHostStateSync(engine.exportBattleState(), immediate: true);
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
      case 'job':
        return const Color(0xFF6D8E23);
      default:
        return const Color(0xFF84624A);
    }
  }

  String _cardStats(RoyaleCard card) {
    if (card.isJob) {
      return '${_jobProfileLabel(card)} · ${_t.text('Base Pay')} ${card.effectValue.toInt()}';
    }
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
        case 'hanger_strike':
          return '${_t.text('Equipment: +Damage')} ${card.effectValue.toInt()} · ${_t.text('Bruise')} 20% · ${_t.text('Mental Illness')} 1%+';
        case 'cane_strike':
          return '${_t.text('Equipment: +Damage')} ${card.effectValue.toInt()} · ${_t.text('Bruise')} 50% · ${_t.text('Bleed')} 20%';
        case 'bottle_strike':
          return '${_t.text('Equipment: +Damage')} ${card.effectValue.toInt()} · ${_t.text('Miss')} 20% · ${_t.text('Bleed')} 40%';
        case 'western_med':
          return _t.text('Equipment: Random Effect');
        case 'eastern_med':
          return '${_t.text('Equipment: Slow on Hit')} 20%';
        case 'electric_shock':
          return '${_t.text('Equipment: Stun')} 60%';
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
      case 'job':
        return _t.text('Job');
      default:
        return _t.text('Melee');
    }
  }

  String _jobProfileLabel(RoyaleCard card) {
    switch (card.effectKind) {
      case 'job_delivery':
        return _t.text('Delivery Gig');
      case 'job_day_labor':
        return _t.text('Day Labor');
      case 'job_part_time':
      default:
        return _t.text('Part-time Shift');
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
      _prefetchBattleAnimations(room);
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
    if (_hasOutgoingFriendRequest(userId) || _isFriendUser(userId)) {
      return;
    }

    try {
      await _friendsService.sendFriendRequest(userId);
      if (!mounted) {
        return;
      }
      await _refreshFriendState();
      if (!mounted) {
        return;
      }
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
    if (_isFriendUser(player.userId)) {
      return false;
    }
    if (_hasOutgoingFriendRequest(player.userId)) {
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

  String _battlefieldHintText(
    bool highlightDropZone,
    List<RoyaleCard> selectedCards, {
    bool compact = false,
  }) {
    if (highlightDropZone) {
      if (compact) {
        return _t.text('Release to deploy here');
      }
      return _t.text('Release to cast all selected cards here');
    }
    if (selectedCards.isNotEmpty) {
      if (compact) {
        return _t.text('Tap the battlefield to deploy selected cards');
      }
      return _t.text(
        'Precision targeting enabled. Tap the battlefield to place cards.',
      );
    }
    if (compact) {
      return _t.text('Drag a card or combo onto your side of the arena');
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
    final friendsOverview = context
        .watch<FriendsOverviewSyncService>()
        .overview;
    final isImmersiveBattle =
        MediaQuery.sizeOf(context).width < 600 &&
        _room != null &&
        _room!.status != 'lobby';
    return Scaffold(
      backgroundColor: const Color(0xFF07111F),
      drawer: _buildRoomFriendDrawer(friendsOverview),
      appBar: isImmersiveBattle
          ? null
          : AppBar(
              title: Text('${t.text('Room')} ${widget.roomCode}'),
              backgroundColor: Colors.transparent,
              foregroundColor: Colors.white,
              elevation: 0,
              actions: [
                IconButton(
                  onPressed: () => Navigator.of(
                    context,
                  ).pushNamedAndRemoveUntil('/home', (_) => false),
                  icon: const Icon(Icons.home_outlined),
                  tooltip: AppConstants.appName,
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
