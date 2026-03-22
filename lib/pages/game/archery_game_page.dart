import 'package:flutter/material.dart';

class ArcheryGamePage extends StatefulWidget {
  const ArcheryGamePage({super.key});

  @override
  State<ArcheryGamePage> createState() => _ArcheryGamePageState();
}

class _ArcheryGamePageState extends State<ArcheryGamePage>
    with SingleTickerProviderStateMixin {
  double bowX = 0.5; // 弓的位置 (0~1)
  bool bowMovingRight = true;
  int score = 0;
  int level = 1;
  late AnimationController _controller;
  bool isTargetMoving = false;
  double targetX = 0.5;
  double targetSpeed = 0.01;
  List<_Arrow> arrows = [];
  bool isPulling = false; // 是否正在拉弓
  double pullAmount = 0.0; // 拉弦進度 0~1

  @override
  void initState() {
    super.initState();
    _controller =
        AnimationController(
            vsync: this,
            duration: const Duration(milliseconds: 16),
          )
          ..addListener(_tick)
          ..repeat();
  }

  void _tick() {
    setState(() {
      // 弓左右移動，拉弓時速度變慢
      double moveSpeed = (isPulling ? 0.003 : 0.01) + level * 0.002;
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
        if (targetX > 1 || targetX < 0) {
          targetSpeed = -targetSpeed;
        }
      }
      // 箭矢動畫
      for (final arrow in arrows) {
        if (!arrow.isFlying) continue;
        arrow.y -= 0.04 + level * 0.01 + arrow.power * 0.02;
        if (arrow.y < 0.15) {
          // 命中判斷
          double targetCenter = isTargetMoving ? targetX : 0.5;
          double dx = (arrow.x - targetCenter).abs();
          int hitScore = 0;
          if (dx < 0.05) {
            hitScore = 100;
          } else if (dx < 0.10) {
            hitScore = 60;
          } else if (dx < 0.18) {
            hitScore = 30;
          }
          score += hitScore;
          // 難度提升
          if (score > 200 && level == 1) {
            level = 2;
            isTargetMoving = true;
          } else if (score > 500 && level == 2) {
            level = 3;
            targetSpeed *= 1.5;
          }
          arrow.isFlying = false;
        }
        if (arrow.y < -0.1) {
          arrow.isFlying = false;
        }
      }
      // 移除已結束箭矢
      arrows.removeWhere((a) => !a.isFlying && a.y < -0.1);
    });
  }

  void _shoot() {
    // 發射箭矢，power 取決於拉弦進度
    arrows.add(_Arrow(x: bowX, y: 0.85, power: pullAmount));
    pullAmount = 0.0;
    isPulling = false;
    setState(() {});
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('弓箭射擊遊戲')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('分數: $score', style: const TextStyle(fontSize: 24)),
            const SizedBox(height: 16),
            SizedBox(
              width: 300,
              height: 400,
              child: Stack(
                alignment: Alignment.center,
                children: [
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
                        border: Border.all(width: 4, color: Colors.white),
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
                  // 弓（含拉弦動畫）
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
                            border: Border.all(width: 3, color: Colors.brown),
                          ),
                          child: const Icon(
                            Icons.architecture,
                            color: Colors.black,
                            size: 32,
                          ),
                        ),
                        // 拉弦動畫
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
                  ...arrows
                      .where((a) => a.isFlying)
                      .map(
                        (arrow) => Positioned(
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
                        ),
                      ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            GestureDetector(
              onLongPressStart: (_) {
                setState(() {
                  isPulling = true;
                  pullAmount = 0.0;
                });
              },
              onLongPressEnd: (_) {
                _shoot();
              },
              onLongPressMoveUpdate: (details) {
                setState(() {
                  pullAmount = (pullAmount + 0.02).clamp(0.0, 1.0);
                });
              },
              child: Container(
                width: 120,
                height: 48,
                decoration: BoxDecoration(
                  color: isPulling ? Colors.blue.shade200 : Colors.blue,
                  borderRadius: BorderRadius.circular(24),
                ),
                alignment: Alignment.center,
                child: Text(
                  isPulling ? '拉弦中... ${(pullAmount * 100).toInt()}%' : '長按拉弦',
                  style: const TextStyle(fontSize: 18, color: Colors.white),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text('等級: $level', style: const TextStyle(fontSize: 18)),
            if (level == 1) const Text('靶不會動'),
            if (level >= 2) const Text('靶會動'),
          ],
        ),
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
