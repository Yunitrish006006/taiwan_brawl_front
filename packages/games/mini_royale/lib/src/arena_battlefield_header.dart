import 'package:flutter/material.dart';

/// Localized copy consumed by the game-owned battlefield instruction header.
class MiniRoyaleBattlefieldLabels {
  const MiniRoyaleBattlefieldLabels({
    required this.releaseToDeployHere,
    required this.releaseToCastSelectionHere,
    required this.tapToDeploySelection,
    required this.precisionTapInstruction,
    required this.dragCardToArena,
    required this.dragOrSelectCardsInstruction,
    required this.yourLeftBase,
    required this.yourRightBase,
    required this.collisionOverlayTooltip,
  });

  final String releaseToDeployHere;
  final String releaseToCastSelectionHere;
  final String tapToDeploySelection;
  final String precisionTapInstruction;
  final String dragCardToArena;
  final String dragOrSelectCardsInstruction;
  final String yourLeftBase;
  final String yourRightBase;
  final String collisionOverlayTooltip;
}

/// Mini Royale's battlefield instructions and collision-overlay control.
class MiniRoyaleBattlefieldHeader extends StatelessWidget {
  const MiniRoyaleBattlefieldHeader({
    super.key,
    required this.highlightDropZone,
    required this.hasSelection,
    required this.playerSide,
    required this.compact,
    required this.showCollisionRadius,
    required this.labels,
    required this.onToggleCollisionRadius,
  });

  final bool highlightDropZone;
  final bool hasSelection;
  final String playerSide;
  final bool compact;
  final bool showCollisionRadius;
  final MiniRoyaleBattlefieldLabels labels;
  final VoidCallback onToggleCollisionRadius;

  String get _hint {
    if (highlightDropZone) {
      return compact
          ? labels.releaseToDeployHere
          : labels.releaseToCastSelectionHere;
    }
    if (hasSelection) {
      return compact
          ? labels.tapToDeploySelection
          : labels.precisionTapInstruction;
    }
    return compact
        ? labels.dragCardToArena
        : labels.dragOrSelectCardsInstruction;
  }

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Icon(
        Icons.grid_view_rounded,
        color: Colors.white70,
        size: compact ? 18 : 24,
      ),
      SizedBox(width: compact ? 8 : 10),
      Expanded(
        child: Text(
          _hint,
          maxLines: compact ? 2 : 3,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w700,
            fontSize: compact ? 13 : 15,
          ),
        ),
      ),
      SizedBox(width: compact ? 8 : 10),
      Tooltip(
        message: labels.collisionOverlayTooltip,
        child: Material(
          color: showCollisionRadius
              ? const Color(0xFFFFD166).withValues(alpha: 0.18)
              : Colors.white.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(compact ? 12 : 14),
          child: InkWell(
            onTap: onToggleCollisionRadius,
            borderRadius: BorderRadius.circular(compact ? 12 : 14),
            child: Padding(
              padding: EdgeInsets.all(compact ? 8 : 10),
              child: Icon(
                showCollisionRadius
                    ? Icons.blur_circular_rounded
                    : Icons.radio_button_unchecked_rounded,
                color: showCollisionRadius
                    ? const Color(0xFFFFD166)
                    : Colors.white.withValues(alpha: 0.72),
                size: compact ? 16 : 18,
              ),
            ),
          ),
        ),
      ),
      if (!compact)
        _BaseLegend(
          label: playerSide == 'left'
              ? labels.yourLeftBase
              : labels.yourRightBase,
          color: playerSide == 'left'
              ? const Color(0xFF039BE5)
              : const Color(0xFFD32F2F),
        ),
    ],
  );
}

class _BaseLegend extends StatelessWidget {
  const _BaseLegend({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.15),
      borderRadius: BorderRadius.circular(999),
      border: Border.all(color: color.withValues(alpha: 0.25)),
    ),
    child: Text(
      label,
      style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 13),
    ),
  );
}
