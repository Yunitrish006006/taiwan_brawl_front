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
  });

  final List<RoyaleCard> cards;
  final int totalCost;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
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
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.14),
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: const Icon(Icons.layers_rounded, color: Colors.white),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Combo Cast Ready',
                  style: TextStyle(
                    color: Colors.white70,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  cards
                      .map(
                        (card) => card.localizedName(
                          context.watch<LocaleProvider>().locale,
                        ),
                      )
                      .join(' + '),
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              '$totalCost',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          if (onClear != null) ...[
            const SizedBox(width: 10),
            IconButton(
              onPressed: onClear,
              style: IconButton.styleFrom(
                backgroundColor: Colors.white.withValues(alpha: 0.12),
                foregroundColor: Colors.white,
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
  });

  final RoyaleCard card;
  final bool playable;
  final Color cardColor;
  final String cardStats;
  final String typeLabel;
  final int selectedOrder;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: playable ? 1 : 0.48,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: 156,
            padding: const EdgeInsets.all(14),
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
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.16),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        typeLabel,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 11,
                        ),
                      ),
                    ),
                    const Spacer(),
                    CircleAvatar(
                      radius: 16,
                      backgroundColor: Colors.white.withValues(alpha: 0.18),
                      child: Text(
                        '${card.elixirCost}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                if (card.imageUrl != null && card.imageUrl!.isNotEmpty) ...[
                  Container(
                    width: double.infinity,
                    height: 72,
                    margin: const EdgeInsets.only(bottom: 10),
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
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 18,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  cardStats,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white70, height: 1.3),
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
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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
                    fontSize: 11,
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
