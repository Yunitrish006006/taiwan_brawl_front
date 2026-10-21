import 'package:flutter/material.dart';

import 'battle_rules.dart' show BattleArenaConfig;
import 'arena_field_painter.dart';

/// Responsive game-owned lobby summary for the selected battlefield.
///
/// Labels are supplied by the host so the game package stays independent from
/// the application's localization provider.
class MiniRoyaleArenaPreview extends StatelessWidget {
  const MiniRoyaleArenaPreview({
    super.key,
    required this.arena,
    required this.playerSide,
    required this.mapTypeLabel,
    required this.arenaName,
    required this.bridgeLabel,
    required this.arenaLabel,
  });

  final BattleArenaConfig arena;
  final String playerSide;
  final String mapTypeLabel;
  final String arenaName;
  final String bridgeLabel;
  final String arenaLabel;

  @override
  Widget build(BuildContext context) {
    final bridgeCount = arena.terrainGates.fold<int>(
      0,
      (total, gate) => total + gate.passableLateralRanges.length,
    );
    final preview = ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border.all(color: Colors.white.withValues(alpha: 0.16)),
        ),
        child: AspectRatio(
          aspectRatio: arena.fieldAspectRatio,
          child: CustomPaint(
            painter: MiniRoyaleArenaPainter(
              playerSide: playerSide,
              arena: arena,
            ),
            child: const SizedBox.expand(),
          ),
        ),
      ),
    );
    final details = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.map_rounded, color: Color(0xFFFFD166), size: 18),
            const SizedBox(width: 8),
            Text(
              mapTypeLabel,
              style: const TextStyle(
                color: Color(0xFFFFD166),
                fontWeight: FontWeight.w800,
                letterSpacing: 0.2,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          arenaName,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _ArenaPreviewPill(
              label: '$bridgeLabel x$bridgeCount',
              color: const Color(0xFF48C7F4),
            ),
            _ArenaPreviewPill(
              label:
                  '${arena.width.round()} x ${arena.height.round()} $arenaLabel',
              color: const Color(0xFF3ECF8E),
            ),
          ],
        ),
      ],
    );

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.09),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth >= 620) {
            return Row(
              key: const ValueKey('mini-royale-arena-preview-wide'),
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                SizedBox(width: 220, child: preview),
                const SizedBox(width: 18),
                Expanded(child: details),
              ],
            );
          }
          return Column(
            key: const ValueKey('mini-royale-arena-preview-compact'),
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [preview, const SizedBox(height: 14), details],
          );
        },
      ),
    );
  }
}

class _ArenaPreviewPill extends StatelessWidget {
  const _ArenaPreviewPill({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.14),
      borderRadius: BorderRadius.circular(999),
      border: Border.all(color: color.withValues(alpha: 0.3)),
    ),
    child: Text(
      label,
      style: TextStyle(color: color, fontWeight: FontWeight.w800, fontSize: 12),
    ),
  );
}
