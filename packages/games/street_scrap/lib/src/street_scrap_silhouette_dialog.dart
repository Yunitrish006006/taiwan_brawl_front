import 'package:flutter/material.dart';

import 'street_scrap_localizations.dart';
import 'street_scrap_item_sprite.dart';

/// Short, accessible reveal interaction used after the player reads a route
/// clue. Tapping a covered silhouette is equivalent to dragging debris away.
class StreetScrapSilhouetteSurveyDialog extends StatefulWidget {
  const StreetScrapSilhouetteSurveyDialog({
    super.key,
    required this.clueSlot,
    required this.materialItemId,
    required this.materialLabel,
  }) : assert(clueSlot >= 0 && clueSlot < 3);

  final int clueSlot;
  final String materialItemId;
  final String materialLabel;

  @override
  State<StreetScrapSilhouetteSurveyDialog> createState() =>
      _StreetScrapSilhouetteSurveyDialogState();
}

class _StreetScrapSilhouetteSurveyDialogState
    extends State<StreetScrapSilhouetteSurveyDialog> {
  final Set<int> _revealedSlots = {};

  String _slotName(StreetScrapLocalizations strings, int slot) => strings.text(
    [
      'silhouette.slot.left',
      'silhouette.slot.middle',
      'silhouette.slot.right',
    ][slot],
  );

  void _reveal(int slot) {
    setState(() => _revealedSlots.add(slot));
  }

  @override
  Widget build(BuildContext context) {
    final strings = StreetScrapLocalizations.of(context);
    return AlertDialog(
      title: Text(strings.text('silhouette.title')),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              strings.text(
                'silhouette.clue',
                arguments: {
                  'item': widget.materialLabel,
                  'slot': _slotName(strings, widget.clueSlot),
                },
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                for (var slot = 0; slot < 3; slot++) ...[
                  if (slot > 0) const SizedBox(width: 6),
                  Expanded(child: _silhouetteTarget(slot)),
                ],
              ],
            ),
            const SizedBox(height: 8),
            LongPressDraggable<int>(
              data: 1,
              feedback: Material(
                color: Colors.transparent,
                child: _debrisCover(size: 120, dragging: true),
              ),
              childWhenDragging: const SizedBox(
                key: Key('street-scrap-debris-drag-placeholder'),
                width: 120,
                height: 40,
              ),
              child: Semantics(
                label: strings.text('silhouette.debrisLabel'),
                hint: strings.text('silhouette.debrisHint'),
                child: _debrisCover(size: 120),
              ),
            ),
            Text(strings.text('silhouette.instructions')),
          ],
        ),
      ),
      actions: [
        TextButton(
          style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
          onPressed: () => Navigator.pop(context),
          child: Text(strings.text('silhouette.cancel')),
        ),
        for (var slot = 0; slot < 3; slot++)
          TextButton(
            key: Key('street-scrap-select-silhouette-$slot'),
            style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
            onPressed: _revealedSlots.contains(slot)
                ? () => Navigator.pop(context, slot)
                : null,
            child: Text(
              strings.text(
                'silhouette.select',
                arguments: {'slot': _slotName(strings, slot)},
              ),
            ),
          ),
      ],
    );
  }

  Widget _silhouetteTarget(int slot) {
    final strings = StreetScrapLocalizations.of(context);
    final revealed = _revealedSlots.contains(slot);
    return DragTarget<int>(
      key: Key('street-scrap-silhouette-target-$slot'),
      onWillAcceptWithDetails: (_) => !revealed,
      onAcceptWithDetails: (_) => _reveal(slot),
      builder: (context, candidates, rejected) {
        final hovering = candidates.isNotEmpty;
        return Semantics(
          button: true,
          label: strings.text(
            revealed
                ? 'silhouette.target.revealed'
                : 'silhouette.target.covered',
            arguments: {'slot': _slotName(strings, slot)},
          ),
          hint: strings.text(
            revealed
                ? 'silhouette.target.selectHint'
                : 'silhouette.target.revealHint',
          ),
          child: InkWell(
            key: Key('street-scrap-reveal-silhouette-$slot'),
            onTap: revealed ? null : () => _reveal(slot),
            borderRadius: BorderRadius.circular(8),
            child: Container(
              constraints: const BoxConstraints(minHeight: 94),
              decoration: BoxDecoration(
                color: hovering
                    ? Theme.of(context).colorScheme.tertiaryContainer
                    : Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: hovering
                      ? Theme.of(context).colorScheme.primary
                      : Theme.of(context).colorScheme.outline,
                  width: hovering ? 2 : 1,
                ),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 8),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (revealed)
                    StreetScrapItemSprite(
                      itemId: widget.materialItemId,
                      source: 'found_native',
                      size: 36,
                    )
                  else
                    Icon(
                      Icons.layers,
                      size: 28,
                      semanticLabel: strings.text('silhouette.coveredObject'),
                    ),
                  const SizedBox(height: 4),
                  Text(
                    strings.text(
                      revealed
                          ? 'silhouette.status.revealed'
                          : 'silhouette.status.covered',
                    ),
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.labelSmall,
                  ),
                  Text(
                    _slotName(strings, slot),
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.labelSmall,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _debrisCover({required double size, bool dragging = false}) {
    final strings = StreetScrapLocalizations.of(context);
    return Container(
      key: dragging ? null : const Key('street-scrap-draggable-debris'),
      width: size,
      height: 40,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.secondaryContainer,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Theme.of(context).colorScheme.outline),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.max,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.drag_indicator, size: 18),
          Flexible(
            child: Text(
              strings.text(
                dragging
                    ? 'silhouette.debris.dragging'
                    : 'silhouette.debris.move',
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }
}
