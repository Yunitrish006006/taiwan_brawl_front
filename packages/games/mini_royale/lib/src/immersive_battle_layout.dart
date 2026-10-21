import 'package:flutter/material.dart';

import 'battle_rules.dart' as battle_rules;

/// Responsive geometry policy for the game-owned immersive battle screen.
class MiniRoyaleImmersiveBattleMetrics {
  const MiniRoyaleImmersiveBattleMetrics({
    required this.useSideHand,
    required this.sideHandWidth,
    required this.sideReservedWidth,
    required this.topReservedHeight,
    required this.bottomReservedHeight,
    required this.fieldWidth,
    required this.fieldHeight,
  });

  final bool useSideHand;
  final double sideHandWidth;
  final double sideReservedWidth;
  final double topReservedHeight;
  final double bottomReservedHeight;
  final double fieldWidth;
  final double fieldHeight;

  static MiniRoyaleImmersiveBattleMetrics calculate({
    required double maxWidth,
    required double maxHeight,
    required double safeTop,
    required double safeBottom,
    required double fieldAspectRatio,
  }) {
    final useSideHand = maxWidth >= 900;
    final sideHandWidth = maxWidth >= 1100 ? 220.0 : 196.0;
    final sideReservedWidth = useSideHand ? sideHandWidth + 22 : 0.0;
    final topReservedHeight = safeTop + 108;
    final bottomReservedHeight = useSideHand
        ? safeBottom + 10
        : safeBottom + 10 + 188;
    final availableHeight =
        (maxHeight - topReservedHeight - bottomReservedHeight)
            .clamp(0.0, double.infinity)
            .toDouble();
    final aspectRatio = fieldAspectRatio > 0
        ? fieldAspectRatio
        : battle_rules.fieldAspectRatio;
    final availableWidth = (maxWidth - sideReservedWidth)
        .clamp(0.0, double.infinity)
        .toDouble();
    final fieldWidth = (availableHeight * aspectRatio)
        .clamp(0.0, availableWidth)
        .toDouble();
    final fieldHeight = fieldWidth / aspectRatio;

    return MiniRoyaleImmersiveBattleMetrics(
      useSideHand: useSideHand,
      sideHandWidth: sideHandWidth,
      sideReservedWidth: sideReservedWidth,
      topReservedHeight: topReservedHeight,
      bottomReservedHeight: bottomReservedHeight,
      fieldWidth: fieldWidth,
      fieldHeight: fieldHeight,
    );
  }
}

/// Hosts app-provided battle controls around a game-owned responsive field.
class MiniRoyaleImmersiveBattleLayout extends StatelessWidget {
  const MiniRoyaleImmersiveBattleLayout({
    super.key,
    required this.fieldAspectRatio,
    required this.fieldBuilder,
    required this.topOverlay,
    required this.bottomHand,
    required this.sideHand,
  });

  final double fieldAspectRatio;
  final Widget Function(
    BuildContext context,
    double fieldWidth,
    double fieldHeight,
  )
  fieldBuilder;
  final Widget topOverlay;
  final Widget bottomHand;
  final Widget sideHand;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final media = MediaQuery.of(context);
        final metrics = MiniRoyaleImmersiveBattleMetrics.calculate(
          maxWidth: constraints.maxWidth.isFinite
              ? constraints.maxWidth
              : media.size.width,
          maxHeight: constraints.maxHeight.isFinite
              ? constraints.maxHeight
              : media.size.height,
          safeTop: media.padding.top,
          safeBottom: media.padding.bottom,
          fieldAspectRatio: fieldAspectRatio,
        );
        return Stack(
          fit: StackFit.expand,
          children: [
            AnimatedPositioned(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOutCubic,
              top: metrics.topReservedHeight,
              left: 0,
              right: metrics.sideReservedWidth,
              bottom: metrics.bottomReservedHeight,
              child: fieldBuilder(
                context,
                metrics.fieldWidth,
                metrics.fieldHeight,
              ),
            ),
            Positioned(top: 0, left: 0, right: 0, child: topOverlay),
            if (metrics.useSideHand)
              Positioned(
                top: metrics.topReservedHeight,
                right: 10,
                bottom: media.padding.bottom + 10,
                width: metrics.sideHandWidth,
                child: sideHand,
              )
            else
              Positioned(left: 0, right: 0, bottom: 0, child: bottomHand),
          ],
        );
      },
    );
  }
}
