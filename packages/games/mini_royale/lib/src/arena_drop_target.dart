import 'package:flutter/material.dart';

import 'royale_models.dart';

/// Typed game interaction data shared by the hand, discard zone, and arena.
/// The host decides affordability and maps accepted drops to room commands.
class MiniRoyaleCardDragPayload {
  const MiniRoyaleCardDragPayload({
    required this.cards,
    required this.draggedCard,
    required this.canDeploy,
  });

  final List<RoyaleCard> cards;
  final RoyaleCard draggedCard;
  final bool canDeploy;
}

/// Game-owned drag/drop interaction boundary for a Mini Royale battlefield.
/// The host retains command semantics and supplies them through typed callbacks.
class MiniRoyaleBattlefieldDropTarget<T extends Object>
    extends StatelessWidget {
  const MiniRoyaleBattlefieldDropTarget({
    super.key,
    required this.canAccept,
    required this.onAccept,
    required this.onMove,
    required this.onLeave,
    required this.builder,
  });

  final bool Function(T payload) canAccept;
  final ValueChanged<DragTargetDetails<T>> onAccept;
  final ValueChanged<DragTargetDetails<T>> onMove;
  final VoidCallback onLeave;
  final Widget Function(BuildContext context, bool isHighlighted) builder;

  @override
  Widget build(BuildContext context) => DragTarget<T>(
    onWillAcceptWithDetails: (details) => canAccept(details.data),
    onAcceptWithDetails: onAccept,
    onMove: onMove,
    onLeave: (_) => onLeave(),
    builder: (context, candidateItems, rejectedItems) =>
        builder(context, candidateItems.isNotEmpty),
  );
}
