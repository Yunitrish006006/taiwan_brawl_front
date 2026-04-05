part of 'royale_arena_page.dart';

class _ComboDragPayload {
  const _ComboDragPayload({required this.cards});

  final List<RoyaleCard> cards;
}

class _DragCursorFeedback extends StatelessWidget {
  const _DragCursorFeedback();

  @override
  Widget build(BuildContext context) {
    return const _AimMarker(
      point: Offset(0.5, 0.5),
      active: true,
      showLabel: false,
    );
  }
}

class _HandCard extends StatelessWidget {
  const _HandCard({
    super.key,
    required this.card,
    required this.playable,
    required this.cardColor,
    required this.cardStats,
    required this.typeLabel,
    required this.costLabel,
    required this.costIcon,
    required this.costColor,
    required this.insufficientLabel,
    this.selectedOrder = -1,
    this.compact = false,
  });

  final RoyaleCard card;
  final bool playable;
  final Color cardColor;
  final String cardStats;
  final String typeLabel;
  final String costLabel;
  final IconData costIcon;
  final Color costColor;
  final String insufficientLabel;
  final int selectedOrder;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: playable ? 1 : 0.48,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: compact ? 102 : 156,
            padding: EdgeInsets.all(compact ? 8 : 14),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [cardColor, cardColor.withValues(alpha: 0.78)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(
                color: selectedOrder >= 0
                    ? const Color(0xFFFFD166)
                    : Colors.white.withValues(alpha: 0.16),
                width: selectedOrder >= 0 ? 2.5 : 1.1,
              ),
              boxShadow: [
                BoxShadow(
                  color: cardColor.withValues(alpha: 0.18),
                  blurRadius: 10,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: compact ? 5 : 8,
                        vertical: compact ? 3 : 5,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.16),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        typeLabel,
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: compact ? 8 : 11,
                        ),
                      ),
                    ),
                    const Spacer(),
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: compact ? 7 : 9,
                        vertical: compact ? 5 : 6,
                      ),
                      decoration: BoxDecoration(
                        color: costColor.withValues(alpha: 0.22),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(
                          color: costColor.withValues(alpha: 0.5),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            costIcon,
                            size: compact ? 12 : 14,
                            color: costColor,
                          ),
                          SizedBox(width: compact ? 3 : 4),
                          Text(
                            costLabel,
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                              fontSize: compact ? 10 : 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                SizedBox(height: compact ? 8 : 14),
                if (card.imageUrl != null && card.imageUrl!.isNotEmpty) ...[
                  Container(
                    width: double.infinity,
                    height: compact ? 40 : 72,
                    margin: EdgeInsets.only(bottom: compact ? 6 : 10),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Image.network(
                      card.imageUrl!,
                      fit: BoxFit.cover,
                      gaplessPlayback: true,
                      errorBuilder: (_, _, _) => const SizedBox.shrink(),
                    ),
                  ),
                ],
                Text(
                  card.localizedName(context.watch<LocaleProvider>().locale),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: compact ? 13 : 18,
                  ),
                ),
                SizedBox(height: compact ? 4 : 8),
                Text(
                  cardStats,
                  maxLines: compact ? 1 : 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white70,
                    height: 1.3,
                    fontSize: compact ? 10 : 13,
                  ),
                ),
              ],
            ),
          ),
          if (selectedOrder >= 0)
            Positioned(
              right: -8,
              top: -8,
              child: CircleAvatar(
                radius: 15,
                backgroundColor: const Color(0xFFFFD166),
                child: Text(
                  '${selectedOrder + 1}',
                  style: const TextStyle(
                    color: Colors.black,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
          if (!playable)
            Positioned(
              left: 12,
              bottom: -8,
              child: Container(
                padding: EdgeInsets.symmetric(
                  horizontal: compact ? 6 : 8,
                  vertical: compact ? 3 : 4,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFF07111F),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  insufficientLabel,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
