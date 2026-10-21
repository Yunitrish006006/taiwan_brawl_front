import 'package:flutter/material.dart';

import 'battle_rules.dart' as battle_rules;

/// Visual coordinate marker owned by the Mini Royale battlefield UI.
class MiniRoyaleAimMarker extends StatelessWidget {
  const MiniRoyaleAimMarker({
    super.key,
    required this.point,
    required this.active,
    this.arena = battle_rules.defaultArenaConfig,
    this.showLabel = true,
  });

  final Offset point;
  final bool active;
  final battle_rules.BattleArenaConfig arena;
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
                'x ${(point.dx * arena.lateralMax).round()} / y ${(point.dy * arena.progressMax).round()}',
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

/// Small battlefield-zone label; localization remains host-provided.
class MiniRoyaleFieldLabel extends StatelessWidget {
  const MiniRoyaleFieldLabel({
    super.key,
    required this.label,
    required this.color,
    this.compact = false,
  });

  final String label;
  final Color color;
  final bool compact;

  @override
  Widget build(BuildContext context) => Container(
    padding: EdgeInsets.symmetric(
      horizontal: compact ? 8 : 10,
      vertical: compact ? 4 : 6,
    ),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.16),
      borderRadius: BorderRadius.circular(999),
      border: Border.all(color: color.withValues(alpha: 0.24)),
    ),
    child: Text(
      label,
      style: TextStyle(
        color: color,
        fontWeight: FontWeight.w700,
        fontSize: compact ? 11 : 13,
      ),
    ),
  );
}
