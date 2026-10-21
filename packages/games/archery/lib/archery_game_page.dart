import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:user_ui_settings/user_ui_settings.dart';
import 'src/archery_rules.dart';
import 'src/archery_player_data.dart';

class ArcheryGamePage extends StatefulWidget {
  const ArcheryGamePage({
    super.key,
    this.progressRepository,
    this.profileId,
    this.rulesContentSource,
  });

  final ArcheryPlayerDataRepository? progressRepository;
  final String? profileId;
  final ArcheryRulesContentSource? rulesContentSource;

  @override
  State<ArcheryGamePage> createState() => _ArcheryGamePageState();
}

class _ArcheryGamePageState extends State<ArcheryGamePage>
    with SingleTickerProviderStateMixin {
  double bowX = 0.5; // 0..1
  bool bowMovingRight = true;
  int score = 0;
  int highScore = 0;
  int level = 1;
  ArcheryRules rules = ArcheryRules.builtIn;
  bool _rulesReady = false;
  late final AnimationController _controller;

  bool isTargetMoving = false;
  double targetX = 0.5;
  double targetSpeed = 0.01;

  final List<_Arrow> arrows = [];

  // 拉弦相關
  bool isPulling = false;
  double pullAmount = 0.0; // 0..1, 0=沒拉
  int stamina = 100; // 100 -> 0

  @override
  void initState() {
    super.initState();
    _restoreProgress();
    _loadActiveRules();
    _controller =
        AnimationController(
            vsync: this,
            duration: const Duration(milliseconds: 16),
          )
          ..addListener(_tick)
          ..repeat();
  }

  Future<void> _loadActiveRules() async {
    final source = widget.rulesContentSource;
    if (source == null) {
      _rulesReady = true;
      return;
    }
    try {
      final payload = await source.readActiveRulesJson();
      if (!mounted) return;
      setState(() {
        if (payload != null) rules = ArcheryRules.decode(payload);
        _rulesReady = true;
      });
    } on Object catch (error) {
      // Preserve the built-in playable rules if an optional local pack is bad.
      debugPrint(
        'Unable to load active Archery rules; using built-ins: $error',
      );
      if (mounted) setState(() => _rulesReady = true);
    }
  }

  Future<void> _restoreProgress() async {
    final repository = widget.progressRepository;
    final profileId = widget.profileId;
    if (repository == null || profileId == null || profileId.isEmpty) return;
    try {
      final progress = await repository.readProgress(profileId);
      if (!mounted) return;
      setState(() => highScore = progress.highScore);
    } on Object {
      // A corrupt local save must not prevent the standalone game from opening.
    }
  }

  void _tick() {
    if (!_rulesReady) return;
    setState(() {
      // 弓左右移動
      final moveSpeed = rules.bowSpeed(level, drawing: isPulling);
      if (bowMovingRight) {
        bowX += moveSpeed;
        if (bowX > 0.95) {
          bowX = 0.95;
          bowMovingRight = false;
        }
      } else {
        bowX -= moveSpeed;
        if (bowX < 0.05) {
          bowX = 0.05;
          bowMovingRight = true;
        }
      }

      // 標靶移動
      if (isTargetMoving) {
        targetX += targetSpeed;
        if (targetX > 1 || targetX < 0) targetSpeed = -targetSpeed;
      }

      // 拉弦時消耗體力（stamina 以 0..100 表示）
      if (isPulling) {
        final drainPercent = rules.staminaDrain(level);
        stamina = (stamina - drainPercent).clamp(0, 100).toInt();
        pullAmount = ((100 - stamina) / 100).clamp(0.0, 1.0);
        if (stamina <= 0) {
          _shoot(); // 自動放開
        }
      }

      // 箭矢移動與命中判斷
      for (final a in arrows) {
        if (!a.isFlying) continue;
        a.y -= rules.arrowRiseSpeed(level, a.power);
        if (a.y < 0.15) {
          final double targetCenter = isTargetMoving ? targetX : 0.5;
          final double dx = (a.x - targetCenter).abs();
          final hitScore = rules.scoreForDistance(dx);
          score += hitScore;
          if (score > highScore) {
            highScore = score;
            _saveHighScore(score);
          }
          if (score > rules.targetMovesAtScore && level == 1) {
            level = 2;
            isTargetMoving = true;
          } else if (score > rules.targetAcceleratesAtScore && level == 2) {
            level = 3;
            targetSpeed *= rules.targetSpeedMultiplier;
          }
          a.isFlying = false;
        }
        if (a.y < -0.1) a.isFlying = false;
      }

      arrows.removeWhere((a) => !a.isFlying && a.y < -0.1);
    });
  }

  Future<void> _saveHighScore(int value) async {
    final repository = widget.progressRepository;
    final profileId = widget.profileId;
    if (repository == null || profileId == null || profileId.isEmpty) return;
    try {
      await repository.writeProgress(
        profileId,
        ArcheryPlayerProgress(highScore: value),
      );
    } on Object {
      // Persistence is best-effort; a transient local-store failure is non-fatal.
    }
  }

  void _shoot() {
    arrows.add(_Arrow(x: bowX, y: 0.85, power: pullAmount));
    pullAmount = 0.0;
    isPulling = false;
    stamina = 100;
    setState(() {});
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.watch<LocaleProvider>().translation;
    return Scaffold(
      appBar: AppBar(title: Text(t.text('Archery Game'))),
      body: Stack(
        children: [
          IgnorePointer(
            ignoring: !_rulesReady,
            child: SingleChildScrollView(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      '${t.text('Score')}: $score',
                      style: const TextStyle(fontSize: 24),
                    ),
                    Text('${t.text('Best')}: $highScore'),
                    const SizedBox(height: 16),

                    // 遊戲畫面
                    SizedBox(
                      width: 300,
                      height: 400,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          Positioned.fill(
                            child: Container(
                              decoration: const BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [
                                    Color(0xFFB3E5FC),
                                    Color(0xFF81D4FA),
                                    Color(0xFF4FC3F7),
                                    Color(0xFFB2DFDB),
                                  ],
                                  stops: [0.0, 0.5, 0.8, 1.0],
                                ),
                              ),
                            ),
                          ),

                          // 標靶
                          Positioned(
                            left: 300 * (isTargetMoving ? targetX : 0.5) - 25,
                            top: 50,
                            child: Container(
                              width: 50,
                              height: 50,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.red,
                                border: Border.all(
                                  width: 4,
                                  color: Colors.white,
                                ),
                              ),
                              child: Center(
                                child: Container(
                                  width: 20,
                                  height: 20,
                                  decoration: const BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: Colors.yellow,
                                  ),
                                ),
                              ),
                            ),
                          ),

                          // 弓
                          Positioned(
                            left: 300 * bowX - 20,
                            top: 340,
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                Container(
                                  width: 40,
                                  height: 40,
                                  decoration: BoxDecoration(
                                    color: Colors.brown.shade200,
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(
                                      width: 3,
                                      color: Colors.brown,
                                    ),
                                  ),
                                  child: const Icon(
                                    Icons.architecture,
                                    color: Colors.black,
                                    size: 32,
                                  ),
                                ),
                                if (isPulling)
                                  Positioned(
                                    right: 0,
                                    child: Container(
                                      width: 8,
                                      height: 40 * (1 + pullAmount),
                                      color: Colors.blueAccent,
                                    ),
                                  ),
                              ],
                            ),
                          ),

                          // 箭矢
                          ...arrows.where((a) => a.isFlying).map((arrow) {
                            return Positioned(
                              left: 300 * arrow.x - 5,
                              top: 400 * arrow.y,
                              child: Container(
                                width: 10,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade700,
                                  borderRadius: BorderRadius.circular(5),
                                ),
                                child: const Icon(
                                  Icons.arrow_upward,
                                  color: Colors.white,
                                  size: 18,
                                ),
                              ),
                            );
                          }),
                        ],
                      ),
                    ),

                    const SizedBox(height: 18),

                    // 體力條
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 32.0),
                      child: Column(
                        children: [
                          Stack(
                            children: [
                              Container(
                                width: 200,
                                height: 18,
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade300,
                                  borderRadius: BorderRadius.circular(9),
                                ),
                              ),
                              AnimatedContainer(
                                duration: const Duration(milliseconds: 100),
                                width: (stamina / 100) * 200,
                                height: 18,
                                decoration: BoxDecoration(
                                  color: stamina > 40
                                      ? Colors.green
                                      : Colors.red,
                                  borderRadius: BorderRadius.circular(9),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            '${t.text('Draw Strength')} $stamina%',
                            style: const TextStyle(fontSize: 14),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 12),

                    GestureDetector(
                      onLongPressStart: (_) {
                        setState(() {
                          isPulling = true;
                          stamina = 100;
                          pullAmount = 0.0;
                        });
                      },
                      onLongPressEnd: (_) {
                        _shoot();
                      },
                      child: Container(
                        width: 140,
                        height: 48,
                        decoration: BoxDecoration(
                          color: isPulling ? Colors.blue.shade200 : Colors.blue,
                          borderRadius: BorderRadius.circular(24),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          isPulling
                              ? '${t.text('Drawing...')} ${(pullAmount * 100).toInt()}%'
                              : t.text('Long press to draw'),
                          style: const TextStyle(
                            fontSize: 18,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 12),
                    Text(
                      '${t.text('Level')}: $level',
                      style: const TextStyle(fontSize: 18),
                    ),
                    if (level == 1) Text(t.text('Target is stationary')),
                    if (level >= 2) Text(t.text('Target is moving')),
                  ],
                ),
              ),
            ),
          ),
          if (!_rulesReady) const Center(child: CircularProgressIndicator()),
        ],
      ),
    );
  }
}

class _Arrow {
  double x;
  double y;
  double power;
  bool isFlying;
  _Arrow({required this.x, required this.y, this.power = 0.0})
    : isFlying = true;
}
