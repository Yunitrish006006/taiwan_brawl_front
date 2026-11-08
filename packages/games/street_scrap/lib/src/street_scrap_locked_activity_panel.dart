import 'package:flutter/material.dart';

/// An image first preview for an activity that has not been unlocked yet.
/// The large emblem keeps the destination recognizable while the single short
/// unlock label avoids turning a locked tab into a text page.
class StreetScrapLockedActivityPanel extends StatelessWidget {
  const StreetScrapLockedActivityPanel({
    super.key,
    required this.featureId,
    required this.title,
    required this.unlockLabel,
    required this.icon,
  });

  final String featureId;
  final String title;
  final String unlockLabel;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 520;
        final narrow = constraints.maxWidth < 360;
        // This panel lives in a ListView, whose children otherwise receive
        // unbounded height and leave the card hugging the top edge.
        final viewportHeight = MediaQuery.sizeOf(context).height;
        final panelHeight = viewportHeight * 0.58;
        final emblemSize = narrow ? 128.0 : (compact ? 168.0 : 244.0);
        final emblem = Semantics(
          label: title,
          child: Container(
            key: Key('street-scrap-locked-art-$featureId'),
            width: emblemSize,
            height: emblemSize,
            decoration: BoxDecoration(
              color: colors.secondaryContainer,
              borderRadius: BorderRadius.circular(compact ? 30 : 38),
              border: Border.all(color: colors.outlineVariant),
              boxShadow: [
                BoxShadow(
                  color: colors.shadow.withValues(alpha: 0.14),
                  blurRadius: 18,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                Positioned(
                  left: 20,
                  top: 24,
                  child: _PixelBlock(color: colors.primary, size: 12),
                ),
                Positioned(
                  right: 26,
                  top: 48,
                  child: _PixelBlock(color: colors.tertiary, size: 8),
                ),
                Positioned(
                  left: 34,
                  bottom: 36,
                  child: _PixelBlock(color: colors.tertiary, size: 9),
                ),
                Positioned(
                  right: 22,
                  bottom: 30,
                  child: _PixelBlock(color: colors.primary, size: 13),
                ),
                Container(
                  width: narrow ? 92 : (compact ? 122 : 176),
                  height: narrow ? 92 : (compact ? 122 : 176),
                  decoration: BoxDecoration(
                    color: colors.surface.withValues(alpha: 0.78),
                    borderRadius: BorderRadius.circular(compact ? 25 : 31),
                  ),
                  alignment: Alignment.center,
                  child: Icon(
                    icon,
                    size: narrow ? 68 : (compact ? 92 : 136),
                    color: colors.onSecondaryContainer,
                  ),
                ),
                Positioned(
                  right: compact ? 17 : 23,
                  bottom: compact ? 17 : 23,
                  child: Container(
                    width: compact ? 48 : 56,
                    height: compact ? 48 : 56,
                    decoration: BoxDecoration(
                      color: colors.surface,
                      shape: BoxShape.circle,
                      border: Border.all(color: colors.outlineVariant),
                    ),
                    alignment: Alignment.center,
                    child: Icon(
                      Icons.lock_rounded,
                      size: compact ? 25 : 30,
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );

        final details = Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: compact
              ? CrossAxisAlignment.center
              : CrossAxisAlignment.start,
          children: [
            Text(
              title,
              key: Key('street-scrap-locked-title-$featureId'),
              textAlign: compact ? TextAlign.center : TextAlign.start,
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
            DecoratedBox(
              decoration: BoxDecoration(
                color: colors.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(18),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 9,
                ),
                child: SizedBox(
                  width: compact ? 230 : 360,
                  child: Row(
                    children: [
                      Icon(
                        Icons.lock_outline_rounded,
                        size: 18,
                        color: colors.primary,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          unlockLabel,
                          textAlign: compact
                              ? TextAlign.center
                              : TextAlign.start,
                          style: theme.textTheme.labelLarge?.copyWith(
                            color: colors.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        );

        return SizedBox(
          height: panelHeight,
          child: Center(
            child: Card(
              key: Key('street-scrap-locked-$featureId'),
              clipBehavior: Clip.antiAlias,
              child: Padding(
                padding: EdgeInsets.all(compact ? 16 : 28),
                child: compact
                    ? Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          emblem,
                          SizedBox(height: narrow ? 14 : 22),
                          details,
                        ],
                      )
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          emblem,
                          const SizedBox(width: 36),
                          Flexible(child: details),
                        ],
                      ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _PixelBlock extends StatelessWidget {
  const _PixelBlock({required this.color, required this.size});

  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) => SizedBox.square(
    dimension: size,
    child: DecoratedBox(
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.66),
        borderRadius: BorderRadius.circular(2),
      ),
    ),
  );
}
