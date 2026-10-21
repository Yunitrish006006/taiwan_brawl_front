import 'package:flutter/material.dart';

/// Game-owned result card and rematch affordance for the arena scene.
///
/// Result wording, progress state, and the action itself are host-provided so
/// the game package stays independent of room/session services and localization.
class MiniRoyaleBattleResultOverlay extends StatelessWidget {
  const MiniRoyaleBattleResultOverlay({
    super.key,
    required this.resultLabel,
    required this.subtitle,
    required this.actionLabel,
    required this.compact,
    required this.isSubmitting,
    required this.onPlayAgain,
  });

  final String resultLabel;
  final String subtitle;
  final String actionLabel;
  final bool compact;
  final bool isSubmitting;
  final VoidCallback onPlayAgain;

  @override
  Widget build(BuildContext context) => Positioned.fill(
    child: Center(
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 18 : 28,
          vertical: compact ? 14 : 20,
        ),
        decoration: BoxDecoration(
          color: const Color(0xFF07111F).withValues(alpha: 0.8),
          borderRadius: BorderRadius.circular(compact ? 22 : 26),
          border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              resultLabel,
              style: TextStyle(
                color: Colors.white,
                fontSize: compact ? 22 : 28,
                fontWeight: FontWeight.w800,
              ),
            ),
            SizedBox(height: compact ? 4 : 6),
            Text(
              subtitle,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.72),
                fontSize: compact ? 12 : 14,
              ),
            ),
            SizedBox(height: compact ? 12 : 16),
            FilledButton.icon(
              onPressed: isSubmitting ? null : onPlayAgain,
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFFFB703),
                foregroundColor: const Color(0xFF1F2937),
                padding: EdgeInsets.symmetric(
                  horizontal: compact ? 16 : 20,
                  vertical: compact ? 10 : 14,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(compact ? 14 : 16),
                ),
              ),
              icon: Icon(Icons.replay_rounded, size: compact ? 18 : 24),
              label: Text(actionLabel),
            ),
          ],
        ),
      ),
    ),
  );
}
