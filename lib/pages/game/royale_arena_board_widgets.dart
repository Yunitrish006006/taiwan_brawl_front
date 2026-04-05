part of 'royale_arena_page.dart';

class _ArenaPainter extends CustomPainter {
  const _ArenaPainter({required this.playerSide});

  final String playerSide;

  double _progressToY(Size size, double progress) {
    final normalized = (progress / battle_rules.worldScale)
        .clamp(0.0, 1.0)
        .toDouble();
    final longitudinal = playerSide == 'left' ? 1 - normalized : normalized;
    return size.height * longitudinal;
  }

  double _lateralToX(Size size, double lateral) {
    final normalized = (lateral / battle_rules.worldScale)
        .clamp(0.0, 1.0)
        .toDouble();
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
      _lateralToX(size, battle_rules.centerLateral),
      _progressToY(size, progress),
    );
    var outerRadius =
        size.height * ((battle_rules.towerBodyRadius + 34) / _worldScale);
    var innerRadius =
        size.height * ((battle_rules.towerBodyRadius + 14) / _worldScale);
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
    final ownDeployRange = battle_rules.deployRangeForSide(playerSide);
    final enemyDeployRange = battle_rules.deployRangeForSide(enemySide);
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
      battle_rules.leftDeployMax.toDouble(),
      battle_rules.rightDeployMin.toDouble(),
    );
    final riverRect = _bandRect(
      size,
      battle_rules.leftDeployMax + 35,
      battle_rules.rightDeployMin - 35,
    );
    final bridgeRect = _worldRect(
      size,
      leftLateral: 380,
      rightLateral: 620,
      startProgress: 430,
      endProgress: 570,
    );
    final laneRect = _worldRect(
      size,
      leftLateral: 430,
      rightLateral: 570,
      startProgress: 0,
      endProgress: battle_rules.worldScale.toDouble(),
    );
    final ownBoundaryProgress = playerSide == 'left'
        ? battle_rules.leftDeployMax.toDouble()
        : battle_rules.rightDeployMin.toDouble();
    final enemyBoundaryProgress = playerSide == 'left'
        ? battle_rules.rightDeployMin.toDouble()
        : battle_rules.leftDeployMax.toDouble();
    final ownBoundaryY = _progressToY(size, ownBoundaryProgress);
    final enemyBoundaryY = _progressToY(size, enemyBoundaryProgress);
    final centerX = _lateralToX(size, battle_rules.centerLateral);

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
    for (var lateral = 100; lateral < battle_rules.worldScale; lateral += 100) {
      final x = _lateralToX(size, lateral.toDouble());
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
    }
    for (
      var progress = 100;
      progress < battle_rules.worldScale;
      progress += 100
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
      progress: battle_rules.leftTowerX.toDouble(),
      color: const Color(0xFF25B7D3),
    );
    _drawTowerPad(
      canvas,
      size,
      progress: battle_rules.rightTowerX.toDouble(),
      color: const Color(0xFFE25555),
    );
  }

  @override
  bool shouldRepaint(covariant _ArenaPainter oldDelegate) {
    return oldDelegate.playerSide != playerSide;
  }
}

class _TowerTargetOverlay extends StatelessWidget {
  const _TowerTargetOverlay({
    required this.color,
    required this.bodyDiameter,
    this.threatDiameter,
    this.emphasized = false,
  });

  final Color color;
  final double bodyDiameter;
  final double? threatDiameter;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    var markerDiameter = bodyDiameter + 10;
    if (markerDiameter < 16) {
      markerDiameter = 16;
    } else if (markerDiameter > 24) {
      markerDiameter = 24;
    }
    final ringDiameter = markerDiameter + 10;

    return IgnorePointer(
      child: SizedBox(
        width: (threatDiameter ?? ringDiameter) + 28,
        height: (threatDiameter ?? ringDiameter) + 28,
        child: Stack(
          alignment: Alignment.center,
          children: [
            if (threatDiameter != null && threatDiameter! > 0)
              Container(
                width: threatDiameter,
                height: threatDiameter,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: color.withValues(alpha: emphasized ? 0.09 : 0.05),
                  border: Border.all(
                    color: color.withValues(alpha: emphasized ? 0.34 : 0.18),
                    width: emphasized ? 1.8 : 1.2,
                  ),
                ),
              ),
            Container(
              width: ringDiameter,
              height: ringDiameter,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF07111F).withValues(alpha: 0.14),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.34),
                  width: 1.1,
                ),
              ),
            ),
            Container(
              width: markerDiameter,
              height: markerDiameter,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: color.withValues(alpha: emphasized ? 0.26 : 0.18),
                border: Border.all(
                  color: color.withValues(alpha: 0.96),
                  width: 2.1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: color.withValues(alpha: emphasized ? 0.28 : 0.16),
                    blurRadius: emphasized ? 16 : 10,
                  ),
                ],
              ),
            ),
            Container(
              width: 2,
              height: ringDiameter + 10,
              color: color.withValues(alpha: 0.7),
            ),
            Container(
              width: ringDiameter + 10,
              height: 2,
              color: color.withValues(alpha: 0.7),
            ),
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.white.withValues(alpha: 0.5),
                    blurRadius: 8,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TowerToken extends StatelessWidget {
  const _TowerToken({
    required this.color,
    required this.towerHp,
    required this.maxTowerHp,
    this.compact = false,
  });

  final Color color;
  final int towerHp;
  final int maxTowerHp;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final progress = maxTowerHp == 0 ? 0.0 : towerHp / maxTowerHp;
    final shellWidth = compact ? 74.0 : 88.0;
    final tokenSize = compact ? 46.0 : 54.0;
    final iconSize = compact ? 22.0 : 28.0;
    final bannerWidth = compact ? 70.0 : 82.0;
    final bannerTop = compact ? -8.0 : -10.0;
    final progressHeight = compact ? 4.0 : 5.0;

    return SizedBox(
      width: shellWidth,
      height: tokenSize,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          Positioned(
            top: bannerTop,
            child: Container(
              width: bannerWidth,
              padding: EdgeInsets.fromLTRB(
                compact ? 7 : 8,
                compact ? 3 : 4,
                compact ? 7 : 8,
                compact ? 4 : 5,
              ),
              decoration: BoxDecoration(
                color: const Color(0xFF07111F).withValues(alpha: 0.84),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: Colors.white.withValues(alpha: 0.16)),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF020817).withValues(alpha: 0.28),
                    blurRadius: compact ? 8 : 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.favorite_rounded,
                        size: compact ? 10 : 11,
                        color: const Color(0xFFFF7B7B),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '$towerHp',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: compact ? 9 : 10,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: compact ? 3 : 4),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(999),
                    child: LinearProgressIndicator(
                      value: progress.clamp(0.0, 1.0),
                      minHeight: progressHeight,
                      backgroundColor: Colors.white.withValues(alpha: 0.12),
                      valueColor: AlwaysStoppedAnimation<Color>(color),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Container(
            width: tokenSize,
            height: tokenSize,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [color, color.withValues(alpha: 0.72)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(compact ? 14 : 18),
              border: Border.all(color: Colors.white.withValues(alpha: 0.72)),
              boxShadow: [
                BoxShadow(
                  color: color.withValues(alpha: 0.32),
                  blurRadius: compact ? 10 : 14,
                  offset: Offset(0, compact ? 6 : 8),
                ),
              ],
            ),
            alignment: Alignment.center,
            child: Icon(
              Icons.castle_rounded,
              color: Colors.white,
              size: iconSize,
            ),
          ),
        ],
      ),
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
              clipBehavior: Clip.antiAlias,
              child: unit.imageUrl != null && unit.imageUrl!.isNotEmpty
                  ? Image.network(
                      unit.imageUrl!,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => Text(
                        unit
                            .localizedName(
                              context.watch<LocaleProvider>().locale,
                            )
                            .characters
                            .first,
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: labelFontSize,
                        ),
                      ),
                    )
                  : Text(
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
