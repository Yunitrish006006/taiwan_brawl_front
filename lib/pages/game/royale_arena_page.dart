import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../../models/royale_models.dart';
import '../../services/api_client.dart';
import '../../services/royale_service.dart';

class RoyaleArenaPage extends StatefulWidget {
  const RoyaleArenaPage({super.key, required this.roomCode});

  final String roomCode;

  @override
  State<RoyaleArenaPage> createState() => _RoyaleArenaPageState();
}

class _RoyaleArenaPageState extends State<RoyaleArenaPage> {
  late final RoyaleService _service;
  final GlobalKey _arenaKey = GlobalKey();
  WebSocketChannel? _channel;
  StreamSubscription<dynamic>? _socketSubscription;
  Timer? _pingTimer;
  RoyaleRoomSnapshot? _room;
  bool _isLoading = true;
  bool _readySubmitting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _service = RoyaleService(ApiClient());
    _bootstrap();
  }

  @override
  void dispose() {
    _pingTimer?.cancel();
    _socketSubscription?.cancel();
    _channel?.sink.close();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    try {
      final room = await _service.fetchRoomState(widget.roomCode);
      if (!mounted) {
        return;
      }
      setState(() {
        _room = room;
        _isLoading = false;
      });
      _connectSocket();
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
        _error = '載入房間失敗: $e';
        _isLoading = false;
      });
    }
  }

  void _connectSocket() {
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
              SnackBar(content: Text(data['message'] as String? ?? '未知錯誤')),
            );
          }
          return;
        }

        final roomJson = data['room'] as Map<String, dynamic>?;
        if (roomJson == null || !mounted) {
          return;
        }
        setState(() {
          _room = RoyaleRoomSnapshot.fromJson(roomJson);
        });
      },
      onError: (_) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('即時連線中斷，請重新整理頁面')));
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
          _readySubmitting = false;
        });
      }
    }
  }

  void _playCard(String cardId, double lanePosition) {
    _channel?.sink.add(
      jsonEncode({
        'type': 'play_card',
        'cardId': cardId,
        'lanePosition': lanePosition,
      }),
    );
  }

  String _formatTime(int ms) {
    final totalSeconds = (ms / 1000).ceil();
    final minutes = totalSeconds ~/ 60;
    final seconds = totalSeconds % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  Color _sideColor(String side) {
    return side == 'left' ? const Color(0xFF00ACC1) : const Color(0xFFE53935);
  }

  Widget _buildLobby(RoyaleRoomSnapshot room) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            gradient: const LinearGradient(
              colors: [Color(0xFF101820), Color(0xFF23415C), Color(0xFF347474)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '房碼 ${room.code}',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                '雙方都按準備後就會立刻開打。',
                style: TextStyle(color: Colors.white70),
              ),
              const SizedBox(height: 18),
              ...room.players.map(
                (player) => Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        backgroundColor: _sideColor(player.side),
                        child: Text(player.side == 'left' ? 'L' : 'R'),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              player.name,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            Text(
                              player.deckName,
                              style: const TextStyle(color: Colors.white70),
                            ),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            player.connected ? '在線' : '未連線',
                            style: const TextStyle(color: Colors.white),
                          ),
                          Text(
                            player.ready ? '已準備' : '等待中',
                            style: TextStyle(
                              color: player.ready
                                  ? Colors.lightGreenAccent
                                  : Colors.amberAccent,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _readySubmitting ? null : _sendReady,
                  icon: const Icon(Icons.flash_on_outlined),
                  label: Text(_readySubmitting ? '送出中...' : '準備開戰'),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildArena(RoyaleRoomSnapshot room) {
    final battle = room.battle!;
    final me = room.me;
    final opponent = room.opponent;
    final mySide = room.viewerSide ?? 'left';
    final myDeployLeft = mySide == 'left' ? 0.0 : 0.58;
    final myDeployWidth = 0.42;

    return LayoutBuilder(
      builder: (context, constraints) {
        final boardHeight = constraints.maxWidth < 680 ? 280.0 : 340.0;
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Row(
              children: [
                Expanded(
                  child: _TowerStatCard(
                    label: me?.name ?? '你',
                    towerHp: me?.towerHp ?? 0,
                    maxTowerHp: me?.maxTowerHp ?? 1,
                    color: _sideColor(mySide),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Column(
                    children: [
                      Text(
                        _formatTime(battle.timeRemainingMs),
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      Text('Elixir ${battle.yourElixir.toStringAsFixed(1)}'),
                    ],
                  ),
                ),
                Expanded(
                  child: _TowerStatCard(
                    label: opponent?.name ?? '對手',
                    towerHp: opponent?.towerHp ?? 0,
                    maxTowerHp: opponent?.maxTowerHp ?? 1,
                    color: _sideColor(opponent?.side ?? 'right'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            DragTarget<RoyaleCard>(
              onAcceptWithDetails: (details) {
                final renderBox =
                    _arenaKey.currentContext?.findRenderObject() as RenderBox?;
                if (renderBox == null) {
                  return;
                }
                final local = renderBox.globalToLocal(details.offset);
                final normalized = (local.dx / renderBox.size.width).clamp(
                  0.0,
                  1.0,
                );
                _playCard(details.data.id, normalized);
              },
              builder: (context, candidateItems, rejectedItems) {
                return Container(
                  key: _arenaKey,
                  height: boardHeight,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(26),
                    gradient: const LinearGradient(
                      colors: [
                        Color(0xFFD9F0FF),
                        Color(0xFFA5D8FF),
                        Color(0xFF7BD389),
                      ],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                  ),
                  child: LayoutBuilder(
                    builder: (context, board) {
                      final laneY = board.maxHeight / 2;
                      return Stack(
                        children: [
                          Positioned.fill(
                            child: CustomPaint(
                              painter: _ArenaPainter(
                                deployLeft: myDeployLeft,
                                deployWidth: myDeployWidth,
                              ),
                            ),
                          ),
                          Positioned(
                            left: board.maxWidth * 0.05 - 30,
                            top: laneY - 48,
                            child: _TowerToken(
                              label: room.players
                                  .firstWhere((p) => p.side == 'left')
                                  .name,
                              color: _sideColor('left'),
                            ),
                          ),
                          Positioned(
                            left: board.maxWidth * 0.95 - 30,
                            top: laneY - 48,
                            child: _TowerToken(
                              label: room.players
                                  .firstWhere(
                                    (p) => p.side == 'right',
                                    orElse: () => const RoyalePlayerView(
                                      userId: 0,
                                      name: '等待玩家',
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
                            ),
                          ),
                          ...battle.units.map((unit) {
                            final left = board.maxWidth * unit.x - 18;
                            final top = laneY - 22 + unit.yOffset * 24;
                            return Positioned(
                              left: left,
                              top: top,
                              child: _UnitToken(unit: unit),
                            );
                          }),
                          if (battle.result != null)
                            Positioned.fill(
                              child: Center(
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 24,
                                    vertical: 18,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withValues(alpha: 0.72),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Text(
                                    _resultLabel(battle.result!, mySide),
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 26,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      );
                    },
                  ),
                );
              },
            ),
            const SizedBox(height: 16),
            Text(
              '拖曳手牌到綠色部署區下兵',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 10),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: battle.yourHand.map((card) {
                  final playable = battle.yourElixir >= card.elixirCost;
                  return Padding(
                    padding: const EdgeInsets.only(right: 12),
                    child: Draggable<RoyaleCard>(
                      data: card,
                      maxSimultaneousDrags: playable ? 1 : 0,
                      feedback: Material(
                        color: Colors.transparent,
                        child: _HandCard(
                          card: card,
                          playable: playable,
                          elevated: true,
                        ),
                      ),
                      childWhenDragging: Opacity(
                        opacity: 0.35,
                        child: _HandCard(card: card, playable: playable),
                      ),
                      child: _HandCard(card: card, playable: playable),
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              battle.nextCardId == null
                  ? '下一張: 未知'
                  : '下一張: ${battle.nextCardId}',
            ),
          ],
        );
      },
    );
  }

  String _resultLabel(RoyaleBattleResult result, String mySide) {
    if (result.winnerSide == null) {
      return '平手';
    }
    return result.winnerSide == mySide ? '你贏了' : '你輸了';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('房間 ${widget.roomCode}')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(child: Text(_error!))
          : _room == null
          ? const Center(child: Text('找不到房間'))
          : (_room!.status == 'lobby'
                ? _buildLobby(_room!)
                : _buildArena(_room!)),
    );
  }
}

class _ArenaPainter extends CustomPainter {
  const _ArenaPainter({required this.deployLeft, required this.deployWidth});

  final double deployLeft;
  final double deployWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final midPaint = Paint()
      ..color = const Color(0xFF305E3B).withValues(alpha: 0.28)
      ..strokeWidth = 3;
    canvas.drawLine(
      Offset(size.width * 0.5, 0),
      Offset(size.width * 0.5, size.height),
      midPaint,
    );

    final lanePaint = Paint()
      ..color = const Color(0xFF5D4037).withValues(alpha: 0.25);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(0, size.height * 0.42, size.width, size.height * 0.16),
        const Radius.circular(18),
      ),
      lanePaint,
    );

    final deployPaint = Paint()
      ..color = const Color(0xFF1B5E20).withValues(alpha: 0.18);
    canvas.drawRect(
      Rect.fromLTWH(
        size.width * deployLeft,
        0,
        size.width * deployWidth,
        size.height,
      ),
      deployPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _ArenaPainter oldDelegate) {
    return oldDelegate.deployLeft != deployLeft ||
        oldDelegate.deployWidth != deployWidth;
  }
}

class _TowerStatCard extends StatelessWidget {
  const _TowerStatCard({
    required this.label,
    required this.towerHp,
    required this.maxTowerHp,
    required this.color,
  });

  final String label;
  final int towerHp;
  final int maxTowerHp;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final progress = maxTowerHp == 0 ? 0.0 : towerHp / maxTowerHp;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          LinearProgressIndicator(
            value: progress.clamp(0.0, 1.0),
            minHeight: 12,
            borderRadius: BorderRadius.circular(99),
          ),
          const SizedBox(height: 6),
          Text('$towerHp / $maxTowerHp'),
        ],
      ),
    );
  }
}

class _TowerToken extends StatelessWidget {
  const _TowerToken({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 60,
          height: 74,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: 0.35),
                blurRadius: 14,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          alignment: Alignment.center,
          child: const Icon(Icons.shield, color: Colors.white, size: 32),
        ),
        const SizedBox(height: 6),
        SizedBox(
          width: 90,
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
          ),
        ),
      ],
    );
  }
}

class _UnitToken extends StatelessWidget {
  const _UnitToken({required this.unit});

  final RoyaleUnitView unit;

  @override
  Widget build(BuildContext context) {
    final color = unit.side == 'left'
        ? const Color(0xFF039BE5)
        : const Color(0xFFD32F2F);
    final progress = unit.maxHp == 0 ? 0.0 : unit.hp / unit.maxHp;

    return Column(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 2),
          ),
          alignment: Alignment.center,
          child: Text(
            unit.name.characters.first,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        const SizedBox(height: 3),
        Container(
          width: 34,
          height: 5,
          decoration: BoxDecoration(
            color: Colors.black12,
            borderRadius: BorderRadius.circular(99),
          ),
          alignment: Alignment.centerLeft,
          child: FractionallySizedBox(
            widthFactor: progress.clamp(0.0, 1.0),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.lightGreenAccent.shade400,
                borderRadius: BorderRadius.circular(99),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _HandCard extends StatelessWidget {
  const _HandCard({
    required this.card,
    required this.playable,
    this.elevated = false,
  });

  final RoyaleCard card;
  final bool playable;
  final bool elevated;

  Color _cardColor() {
    switch (card.type) {
      case 'tank':
        return const Color(0xFF3949AB);
      case 'ranged':
        return const Color(0xFF00897B);
      case 'swarm':
        return const Color(0xFFF57C00);
      case 'spell':
        return const Color(0xFFC62828);
      default:
        return const Color(0xFF6D4C41);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: playable ? 1 : 0.45,
      child: Container(
        width: 120,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: _cardColor(),
          borderRadius: BorderRadius.circular(18),
          boxShadow: elevated
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.2),
                    blurRadius: 14,
                    offset: const Offset(0, 8),
                  ),
                ]
              : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    card.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                CircleAvatar(
                  radius: 14,
                  backgroundColor: Colors.white.withValues(alpha: 0.22),
                  child: Text(
                    '${card.elixirCost}',
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              card.type == 'spell'
                  ? '法術 ${card.spellDamage}'
                  : 'HP ${card.hp} / DMG ${card.damage}',
              style: const TextStyle(color: Colors.white70),
            ),
          ],
        ),
      ),
    );
  }
}
