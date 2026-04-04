part of 'royale_arena_page.dart';

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
    this.compact = false,
  });

  final String label;
  final Color color;
  final int towerHp;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final tokenWidth = compact ? 54.0 : 68.0;
    final tokenHeight = compact ? 68.0 : 84.0;
    final iconSize = compact ? 28.0 : 36.0;
    final labelWidth = compact ? 76.0 : 98.0;

    return Column(
      children: [
        Container(
          width: tokenWidth,
          height: tokenHeight,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [color, color.withValues(alpha: 0.72)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(compact ? 18 : 22),
            border: Border.all(color: Colors.white.withValues(alpha: 0.6)),
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: 0.32),
                blurRadius: compact ? 12 : 18,
                offset: Offset(0, compact ? 7 : 10),
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
        SizedBox(height: compact ? 5 : 8),
        SizedBox(
          width: labelWidth,
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Color(0xFF102030),
              fontWeight: FontWeight.w700,
              fontSize: compact ? 11 : 14,
            ),
          ),
        ),
        SizedBox(height: compact ? 1 : 2),
        Text(
          '$towerHp',
          style: TextStyle(
            color: Color(0xFF102030),
            fontWeight: FontWeight.w800,
            fontSize: compact ? 11 : 13,
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
