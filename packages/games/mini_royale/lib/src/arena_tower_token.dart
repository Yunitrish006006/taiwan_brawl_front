import 'package:flutter/material.dart';

/// Renders one player's tower status on the Mini Royale battlefield.
///
/// The host supplies the localized hero name, current health, and side color;
/// all tower-token layout and health visualization belongs to this game.
class MiniRoyaleTowerToken extends StatelessWidget {
  const MiniRoyaleTowerToken({
    super.key,
    required this.heroName,
    required this.color,
    required this.towerHp,
    required this.maxTowerHp,
    this.compact = false,
  });

  final String heroName;
  final Color color;
  final int towerHp;
  final int maxTowerHp;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final progress = maxTowerHp <= 0 ? 0.0 : towerHp / maxTowerHp;
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
                  Text(
                    heroName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: const Color(0xFFFFD166),
                      fontWeight: FontWeight.w800,
                      fontSize: compact ? 8 : 9,
                    ),
                  ),
                  SizedBox(height: compact ? 2 : 3),
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
