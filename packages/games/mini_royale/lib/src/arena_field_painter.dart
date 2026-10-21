import 'package:flutter/material.dart';

import 'battle_rules.dart' as battle_rules;

class MiniRoyaleArenaPainter extends CustomPainter {
  const MiniRoyaleArenaPainter({required this.playerSide, required this.arena});

  final String playerSide;
  final battle_rules.BattleArenaConfig arena;

  double _progressToY(Size size, double progress) {
    final normalized = (progress / arena.progressMax)
        .clamp(0.0, 1.0)
        .toDouble();
    final longitudinal = playerSide == 'left' ? 1 - normalized : normalized;
    return size.height * longitudinal;
  }

  double _lateralToX(Size size, double lateral) {
    final normalized = (lateral / arena.lateralMax).clamp(0.0, 1.0).toDouble();
    return size.width * normalized;
  }

  Rect _bandRect(Size size, double startProgress, double endProgress) {
    final y1 = _progressToY(size, startProgress);
    final y2 = _progressToY(size, endProgress);
    final top = y1 < y2 ? y1 : y2;
    final bottom = y1 > y2 ? y1 : y2;
    return Rect.fromLTRB(0, top, size.width, bottom);
  }

  Rect _worldRect(
    Size size, {
    required double leftLateral,
    required double rightLateral,
    required double startProgress,
    required double endProgress,
  }) {
    final x1 = _lateralToX(size, leftLateral);
    final x2 = _lateralToX(size, rightLateral);
    final y1 = _progressToY(size, startProgress);
    final y2 = _progressToY(size, endProgress);
    final left = x1 < x2 ? x1 : x2;
    final right = x1 > x2 ? x1 : x2;
    final top = y1 < y2 ? y1 : y2;
    final bottom = y1 > y2 ? y1 : y2;
    return Rect.fromLTRB(left, top, right, bottom);
  }

  void _drawTowerPad(
    Canvas canvas,
    Size size, {
    required double progress,
    required Color color,
  }) {
    final center = Offset(
      _lateralToX(size, arena.centerLateral),
      _progressToY(size, progress),
    );
    var outerRadius =
        size.height * ((battle_rules.towerBodyRadius + 34) / arena.progressMax);
    var innerRadius =
        size.height * ((battle_rules.towerBodyRadius + 14) / arena.progressMax);
    if (outerRadius < 18) {
      outerRadius = 18;
    }
    if (innerRadius < 10) {
      innerRadius = 10;
    }

    canvas.drawCircle(
      center,
      outerRadius,
      Paint()..color = color.withValues(alpha: 0.08),
    );
    canvas.drawCircle(
      center,
      outerRadius,
      Paint()
        ..color = color.withValues(alpha: 0.22)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4,
    );
    canvas.drawCircle(
      center,
      innerRadius,
      Paint()..color = const Color(0xFF07111F).withValues(alpha: 0.12),
    );
    canvas.drawCircle(
      center,
      innerRadius,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.22)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.1,
    );
  }

  @override
  void paint(Canvas canvas, Size size) {
    final fullRect = Rect.fromLTWH(0, 0, size.width, size.height);
    final enemySide = playerSide == 'left' ? 'right' : 'left';
    final ownDeployRange = battle_rules.deployRangeForSide(playerSide, arena);
    final enemyDeployRange = battle_rules.deployRangeForSide(enemySide, arena);
    final ownDeployRect = _bandRect(
      size,
      ownDeployRange.first,
      ownDeployRange.last,
    );
    final enemyDeployRect = _bandRect(
      size,
      enemyDeployRange.first,
      enemyDeployRange.last,
    );
    final neutralRect = _bandRect(
      size,
      arena.leftDeploy.max,
      arena.rightDeploy.min,
    );
    battle_rules.BattleTerrainGate? riverGate;
    for (final gate in arena.terrainGates) {
      if (gate.kind == 'river') {
        riverGate = gate;
        break;
      }
    }
    final riverRect = riverGate == null
        ? Rect.zero
        : _bandRect(size, riverGate.progressMin, riverGate.progressMax);
    final laneRect = _worldRect(
      size,
      leftLateral: arena.centerLateral - 70,
      rightLateral: arena.centerLateral + 70,
      startProgress: arena.progressMin,
      endProgress: arena.progressMax,
    );
    final ownBoundaryProgress = playerSide == 'left'
        ? arena.leftDeploy.max
        : arena.rightDeploy.min;
    final enemyBoundaryProgress = playerSide == 'left'
        ? arena.rightDeploy.min
        : arena.leftDeploy.max;
    final ownBoundaryY = _progressToY(size, ownBoundaryProgress);
    final enemyBoundaryY = _progressToY(size, enemyBoundaryProgress);
    final centerX = _lateralToX(size, arena.centerLateral);

    final fieldPaint = Paint()
      ..shader = const LinearGradient(
        colors: [
          Color(0xFF89C97E),
          Color(0xFF6CB46A),
          Color(0xFF5DAA4D),
          Color(0xFF43874C),
        ],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ).createShader(fullRect);
    canvas.drawRect(fullRect, fieldPaint);

    canvas.drawRect(
      enemyDeployRect,
      Paint()
        ..shader = LinearGradient(
          colors: [
            const Color(0xFFE25555).withValues(alpha: 0.09),
            const Color(0xFFE25555).withValues(alpha: 0.02),
          ],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ).createShader(enemyDeployRect),
    );
    canvas.drawRect(
      ownDeployRect,
      Paint()
        ..shader = LinearGradient(
          colors: [
            const Color(0xFF25B7D3).withValues(alpha: 0.04),
            const Color(0xFF1B8F5A).withValues(alpha: 0.12),
          ],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ).createShader(ownDeployRect),
    );
    canvas.drawRect(
      neutralRect,
      Paint()..color = const Color(0xFF143D2F).withValues(alpha: 0.07),
    );

    final hazePaint = Paint()
      ..shader = const LinearGradient(
        colors: [Color(0x55FFFFFF), Color(0x00FFFFFF)],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ).createShader(fullRect);
    canvas.drawRect(fullRect, hazePaint);

    final gridPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.08)
      ..strokeWidth = 1;
    final lateralGridStep = (arena.lateralMax / 10).clamp(50.0, 160.0);
    for (
      var lateral = lateralGridStep;
      lateral < arena.lateralMax;
      lateral += lateralGridStep
    ) {
      final x = _lateralToX(size, lateral.toDouble());
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
    }
    final progressGridStep = (arena.progressMax / 10).clamp(50.0, 180.0);
    for (
      var progress = progressGridStep;
      progress < arena.progressMax;
      progress += progressGridStep
    ) {
      final y = _progressToY(size, progress.toDouble());
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    canvas.drawRRect(
      RRect.fromRectAndRadius(laneRect, const Radius.circular(22)),
      Paint()..color = const Color(0xFF7B5E57).withValues(alpha: 0.16),
    );
    canvas.drawLine(
      Offset(centerX, 0),
      Offset(centerX, size.height),
      Paint()
        ..color = Colors.white.withValues(alpha: 0.22)
        ..strokeWidth = 2.2,
    );

    if (riverGate != null) {
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
    }
    if (riverGate != null) {
      for (final bridgeRange in riverGate.passableLateralRanges) {
        final bridgeRect = _worldRect(
          size,
          leftLateral: bridgeRange.min,
          rightLateral: bridgeRange.max,
          startProgress: riverGate.bridgeMinProgress,
          endProgress: riverGate.bridgeMaxProgress,
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
      }
    }

    final obstaclePaint = Paint()
      ..color = const Color(0xFF2B2B35).withValues(alpha: 0.48);
    for (final obstacle in arena.obstacles) {
      final obstacleRect = _worldRect(
        size,
        leftLateral: obstacle.lateralMin,
        rightLateral: obstacle.lateralMax,
        startProgress: obstacle.progressMin,
        endProgress: obstacle.progressMax,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(obstacleRect, const Radius.circular(10)),
        obstaclePaint,
      );
    }

    canvas.drawLine(
      Offset(0, ownBoundaryY),
      Offset(size.width, ownBoundaryY),
      Paint()
        ..color = const Color(0xFF3ECF8E).withValues(alpha: 0.48)
        ..strokeWidth = 2.2,
    );
    canvas.drawLine(
      Offset(0, enemyBoundaryY),
      Offset(size.width, enemyBoundaryY),
      Paint()
        ..color = const Color(0xFFFFA3A3).withValues(alpha: 0.28)
        ..strokeWidth = 1.6,
    );

    if (ownDeployRect.height > 18) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          ownDeployRect.deflate(8),
          const Radius.circular(18),
        ),
        Paint()
          ..color = const Color(0xFF3ECF8E).withValues(alpha: 0.3)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );
    }

    final bushPaint = Paint()
      ..color = const Color(0xFF2D6A4F).withValues(alpha: 0.2);
    canvas.drawCircle(
      Offset(_lateralToX(size, 220), _progressToY(size, 820)),
      24,
      bushPaint,
    );
    canvas.drawCircle(
      Offset(_lateralToX(size, 780), _progressToY(size, 780)),
      22,
      bushPaint,
    );
    canvas.drawCircle(
      Offset(_lateralToX(size, 200), _progressToY(size, 200)),
      24,
      bushPaint,
    );
    canvas.drawCircle(
      Offset(_lateralToX(size, 760), _progressToY(size, 240)),
      24,
      bushPaint,
    );

    _drawTowerPad(
      canvas,
      size,
      progress: arena.leftTower.progress,
      color: const Color(0xFF25B7D3),
    );
    _drawTowerPad(
      canvas,
      size,
      progress: arena.rightTower.progress,
      color: const Color(0xFFE25555),
    );
  }

  @override
  bool shouldRepaint(covariant MiniRoyaleArenaPainter oldDelegate) {
    return oldDelegate.playerSide != playerSide || oldDelegate.arena != arena;
  }
}
