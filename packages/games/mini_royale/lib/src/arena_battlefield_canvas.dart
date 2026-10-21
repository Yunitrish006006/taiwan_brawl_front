import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';

import 'arena_field_painter.dart';
import 'battle_rules.dart' as battle_rules;
import 'arena_overlay_widgets.dart';
import 'arena_presentation.dart';

/// Mini Royale's game-owned battlefield surface and input coordinate space.
///
/// The host supplies localized copy, live-state overlays, and callbacks that
/// translate gestures into its room/transport commands. The canvas owns the
/// arena background, painter, scene clipping, and pointer/tap hit surface.
class MiniRoyaleBattlefieldCanvas extends StatelessWidget {
  const MiniRoyaleBattlefieldCanvas({
    super.key,
    required this.width,
    required this.height,
    required this.playerSide,
    required this.arena,
    required this.compact,
    required this.fullscreen,
    required this.highlightDropZone,
    required this.enemyBaseLabel,
    required this.bridgeLabel,
    required this.deploymentZoneLabel,
    required this.buildOverlays,
    required this.onHover,
    required this.onExit,
    this.onTapDown,
    this.boardKey,
    this.presentation = MiniRoyaleArenaPresentation.fallback,
  });

  final double width;
  final double height;
  final String playerSide;
  final battle_rules.BattleArenaConfig arena;
  final bool compact;
  final bool fullscreen;
  final bool highlightDropZone;
  final String enemyBaseLabel;
  final String bridgeLabel;
  final String deploymentZoneLabel;
  final List<Widget> Function(BoxConstraints board) buildOverlays;
  final void Function(PointerHoverEvent event) onHover;
  final void Function(PointerExitEvent event) onExit;
  final GestureTapDownCallback? onTapDown;
  final Key? boardKey;
  final MiniRoyaleArenaPresentation presentation;

  @override
  Widget build(BuildContext context) {
    final radius = fullscreen ? 0.0 : 30.0;
    return Align(
      child: SizedBox(
        width: width,
        height: height,
        child: Container(
          key: boardKey,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(radius),
            gradient: LinearGradient(
              colors: presentation.fieldColors,
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
            border: Border.all(
              color: highlightDropZone
                  ? const Color(0xFFFFD166)
                  : fullscreen
                  ? Colors.transparent
                  : Colors.white.withValues(alpha: 0.32),
              width: highlightDropZone ? 2.4 : (fullscreen ? 0 : 1.2),
            ),
            boxShadow: fullscreen
                ? const []
                : [
                    BoxShadow(
                      color: const Color(0xFF07111F).withValues(alpha: 0.28),
                      blurRadius: 28,
                      offset: const Offset(0, 18),
                    ),
                  ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(fullscreen ? 0 : 28),
            child: MouseRegion(
              onHover: onHover,
              onExit: onExit,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTapDown: onTapDown,
                child: LayoutBuilder(
                  builder: (context, board) => Stack(
                    children: [
                      Positioned.fill(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: RadialGradient(
                              center: const Alignment(0, -0.85),
                              radius: 1.1,
                              colors: [
                                Colors.white.withValues(alpha: 0.44),
                                Colors.transparent,
                              ],
                            ),
                          ),
                        ),
                      ),
                      Positioned.fill(
                        child: CustomPaint(
                          painter: MiniRoyaleArenaPainter(
                            playerSide: playerSide,
                            arena: arena,
                          ),
                        ),
                      ),
                      if (!compact && !fullscreen)
                        Positioned(
                          left: 18,
                          top: 18,
                          child: MiniRoyaleFieldLabel(
                            label: enemyBaseLabel,
                            color: const Color(0xFFE25555),
                          ),
                        ),
                      if (!compact && !fullscreen)
                        Positioned(
                          left: board.maxWidth * 0.5 - 42,
                          top: 18,
                          child: MiniRoyaleFieldLabel(
                            label: bridgeLabel,
                            color: const Color(0xFF2F7D87),
                          ),
                        ),
                      if (!fullscreen)
                        Positioned(
                          right: 18,
                          bottom: 18,
                          child: MiniRoyaleFieldLabel(
                            label: deploymentZoneLabel,
                            color: const Color(0xFF136F63),
                            compact: compact,
                          ),
                        ),
                      ...buildOverlays(board),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
