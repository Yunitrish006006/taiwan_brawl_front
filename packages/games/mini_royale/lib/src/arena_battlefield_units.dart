import 'package:flutter/material.dart';

import 'arena_animated_unit_portrait.dart';
import 'arena_unit_token.dart';
import 'royale_models.dart';

/// Positions and paints all simulation units in the Mini Royale arena.
class MiniRoyaleBattlefieldUnits extends StatelessWidget {
  const MiniRoyaleBattlefieldUnits({
    super.key,
    required this.battle,
    required this.viewerSide,
    required this.locale,
    required this.showCollisionRadii,
  });

  final RoyaleBattleView battle;
  final String viewerSide;
  final String locale;
  final bool showCollisionRadii;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, board) => Stack(
      clipBehavior: Clip.none,
      children: battle.units.map((unit) {
        final arena = battle.arena;
        final longitudinal = viewerSide == 'left'
            ? 1 - (unit.progress / arena.progressMax)
            : unit.progress / arena.progressMax;
        final depthFactor = longitudinal.clamp(0.0, 1.0);
        final tokenSize = 40 + (depthFactor * 8);
        final left =
            board.maxWidth * (unit.lateralPosition / arena.lateralMax) -
            tokenSize / 2;
        final top = board.maxHeight * longitudinal - tokenSize * 0.62;
        final attackDiameter =
            board.maxHeight * (unit.attackRange / arena.progressMax) * 2;
        final collisionDiameter =
            board.maxHeight * (unit.bodyRadius / arena.progressMax) * 2;
        final friendly = unit.side == viewerSide;
        final animationFrames = unit.characterAnimationFramesForViewer(
          viewerSide,
        );
        final eventFrames = unit.animationEventFramesForViewer(viewerSide);
        final imageUrl = unit.characterImageUrlForViewer(viewerSide);
        final fallbackLabel = unit.localizedName(locale).characters.first;
        final hasPortrait =
            eventFrames.isNotEmpty ||
            animationFrames.isNotEmpty ||
            (imageUrl != null && imageUrl.isNotEmpty);

        return Positioned(
          key: ValueKey(unit.id),
          left: left,
          top: top,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              if (unit.attackRange > 0)
                Positioned(
                  left: tokenSize / 2 - attackDiameter / 2,
                  top: tokenSize * 0.5 - attackDiameter / 2,
                  child: _RangeIndicator(
                    key: ValueKey('attack-range:${unit.id}'),
                    diameter: attackDiameter,
                    friendly: friendly,
                  ),
                ),
              if (showCollisionRadii && unit.bodyRadius > 0)
                Positioned(
                  left: tokenSize / 2 - collisionDiameter / 2,
                  top: tokenSize * 0.5 - collisionDiameter / 2,
                  child: _CollisionRadiusIndicator(
                    key: ValueKey('collision-radius:${unit.id}'),
                    diameter: collisionDiameter,
                    friendly: friendly,
                  ),
                ),
              MiniRoyaleUnitToken(
                fallbackLabel: fallbackLabel,
                friendly: friendly,
                hp: unit.hp,
                maxHp: unit.maxHp,
                effectCount: unit.effects.length,
                size: tokenSize,
                portrait: hasPortrait
                    ? MiniRoyaleAnimatedUnitPortrait(
                        frames: animationFrames,
                        eventFrames: eventFrames,
                        eventKey: eventFrames.isEmpty
                            ? null
                            : unit.animationEvent?.key,
                        fallbackUrl: imageUrl,
                        fallback: MiniRoyaleUnitToken.fallbackPortrait(
                          label: fallbackLabel,
                          friendly: friendly,
                          size: tokenSize,
                        ),
                      )
                    : null,
              ),
            ],
          ),
        );
      }).toList(),
    ),
  );
}

class _RangeIndicator extends StatelessWidget {
  const _RangeIndicator({
    super.key,
    required this.diameter,
    required this.friendly,
  });

  final double diameter;
  final bool friendly;

  @override
  Widget build(BuildContext context) {
    final color = friendly ? const Color(0xFF4FC3F7) : const Color(0xFFFF8A80);
    return IgnorePointer(
      child: Container(
        width: diameter,
        height: diameter,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(9999),
          border: Border.all(color: color.withValues(alpha: 0.24), width: 1.4),
        ),
      ),
    );
  }
}

class _CollisionRadiusIndicator extends StatelessWidget {
  const _CollisionRadiusIndicator({
    super.key,
    required this.diameter,
    required this.friendly,
  });

  final double diameter;
  final bool friendly;

  @override
  Widget build(BuildContext context) {
    final color = friendly ? const Color(0xFFFFD166) : const Color(0xFFFF8A80);
    return IgnorePointer(
      child: Container(
        width: diameter,
        height: diameter,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(9999),
          border: Border.all(color: color.withValues(alpha: 0.5), width: 1.2),
        ),
      ),
    );
  }
}
