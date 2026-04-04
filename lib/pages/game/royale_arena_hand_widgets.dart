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

class _ComboLauncher extends StatelessWidget {
  const _ComboLauncher({
    required this.cards,
    required this.totalCost,
    this.onClear,
    this.compact = false,
  });

  final List<RoyaleCard> cards;
  final int totalCost;
  final VoidCallback? onClear;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(compact ? 12 : 16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF311B92), Color(0xFF512DA8), Color(0xFF7E57C2)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.24),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: compact ? 36 : 42,
            height: compact ? 36 : 42,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.14),
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Icon(
              Icons.layers_rounded,
              color: Colors.white,
              size: compact ? 18 : 24,
            ),
          ),
          SizedBox(width: compact ? 10 : 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Combo Cast Ready',
                  style: TextStyle(
                    color: Colors.white70,
                    fontWeight: FontWeight.w700,
                    fontSize: compact ? 11 : 13,
                  ),
                ),
                SizedBox(height: compact ? 2 : 4),
                Text(
                  cards
                      .map(
                        (card) => card.localizedName(
                          context.watch<LocaleProvider>().locale,
                        ),
                      )
                      .join(' + '),
                  maxLines: compact ? 2 : 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: compact ? 14 : 16,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: EdgeInsets.symmetric(
              horizontal: compact ? 10 : 14,
              vertical: compact ? 8 : 10,
            ),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              '$totalCost',
              style: TextStyle(
                color: Colors.white,
                fontSize: compact ? 16 : 18,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          if (onClear != null) ...[
            SizedBox(width: compact ? 6 : 10),
            IconButton(
              onPressed: onClear,
              style: IconButton.styleFrom(
                backgroundColor: Colors.white.withValues(alpha: 0.12),
                foregroundColor: Colors.white,
                padding: EdgeInsets.all(compact ? 8 : 12),
                minimumSize: Size(compact ? 34 : 40, compact ? 34 : 40),
              ),
              icon: const Icon(Icons.close_rounded),
            ),
          ],
        ],
      ),
    );
  }
}

class _HandCard extends StatelessWidget {
  const _HandCard({
    required this.card,
    required this.playable,
    required this.cardColor,
    required this.cardStats,
    required this.typeLabel,
    this.selectedOrder = -1,
    this.compact = false,
  });

  final RoyaleCard card;
  final bool playable;
  final Color cardColor;
  final String cardStats;
  final String typeLabel;
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
            width: compact ? 118 : 156,
            padding: EdgeInsets.all(compact ? 10 : 14),
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
                        horizontal: compact ? 6 : 8,
                        vertical: compact ? 4 : 5,
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
                          fontSize: compact ? 9 : 11,
                        ),
                      ),
                    ),
                    const Spacer(),
                    CircleAvatar(
                      radius: compact ? 14 : 16,
                      backgroundColor: Colors.white.withValues(alpha: 0.18),
                      child: Text(
                        '${card.elixirCost}',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: compact ? 12 : 14,
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: compact ? 10 : 14),
                if (card.imageUrl != null && card.imageUrl!.isNotEmpty) ...[
                  Container(
                    width: double.infinity,
                    height: compact ? 48 : 72,
                    margin: EdgeInsets.only(bottom: compact ? 8 : 10),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Image.network(
                      card.imageUrl!,
                      fit: BoxFit.cover,
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
                    fontSize: compact ? 14 : 18,
                  ),
                ),
                SizedBox(height: compact ? 6 : 8),
                Text(
                  cardStats,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white70,
                    height: 1.3,
                    fontSize: compact ? 11 : 13,
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
                  context.watch<LocaleProvider>().translation.text(
                    'Not enough elixir',
                  ),
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
