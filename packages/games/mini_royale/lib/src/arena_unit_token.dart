import 'package:flutter/material.dart';

/// Game-owned unit token chrome for battlefield units.
///
/// The host may provide a portrait widget backed by its chosen asset/runtime
/// adapter. Health, side color, fallback appearance, and effect count remain
/// part of the Mini Royale presentation contract.
class MiniRoyaleUnitToken extends StatelessWidget {
  const MiniRoyaleUnitToken({
    super.key,
    required this.fallbackLabel,
    required this.friendly,
    required this.hp,
    required this.maxHp,
    required this.effectCount,
    this.size = 44,
    this.portrait,
  });

  final String fallbackLabel;
  final bool friendly;
  final int hp;
  final int maxHp;
  final int effectCount;
  final double size;
  final Widget? portrait;

  static Widget fallbackPortrait({
    required String label,
    required bool friendly,
    required double size,
  }) {
    final color = friendly ? const Color(0xFF039BE5) : const Color(0xFFD32F2F);
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color, color.withValues(alpha: 0.72)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 2),
      ),
      alignment: Alignment.center,
      child: Text(
        label,
        maxLines: 1,
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: size * 0.32,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final progress = maxHp <= 0 ? 0.0 : hp / maxHp;
    final fallback = fallbackPortrait(
      label: fallbackLabel,
      friendly: friendly,
      size: size,
    );

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Column(
          children: [
            SizedBox(width: size, height: size, child: portrait ?? fallback),
            const SizedBox(height: 2),
            Container(
              width: size - 2,
              height: 5,
              decoration: BoxDecoration(
                color: Colors.black26,
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
        if (effectCount > 0)
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
                '+$effectCount',
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
