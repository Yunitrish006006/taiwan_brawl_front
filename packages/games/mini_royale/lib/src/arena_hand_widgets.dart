import 'package:flutter/material.dart';

import 'royale_models.dart';

Color miniRoyaleHandCardColor(String type) => switch (type) {
  'tank' => const Color(0xFF3557D6),
  'ranged' => const Color(0xFF0F8B6D),
  'swarm' => const Color(0xFFF28C28),
  'spell' => const Color(0xFFD64545),
  'equipment' => const Color(0xFF7B3FF2),
  'job' => const Color(0xFF6D8E23),
  _ => const Color(0xFF84624A),
};

String miniRoyaleCardEnergyType(RoyaleCard card) => card.usesMoney
    ? 'money'
    : card.usesSpiritEnergy
    ? 'spirit'
    : 'physical';

/// Derives game-owned card semantics while delegating translated copy to the
/// host shell.
class MiniRoyaleHandCardContent {
  const MiniRoyaleHandCardContent._();

  static String typeLabel(RoyaleCard card, String Function(String) translate) =>
      translate(switch (card.type) {
        'tank' => 'Tank',
        'ranged' => 'Ranged',
        'swarm' => 'Swarm',
        'spell' => 'Spell',
        'equipment' => 'Equipment',
        'job' => 'Job',
        _ => 'Melee',
      });

  static String energyLabel(
    RoyaleCard card, {
    required String Function(String) shortEnergyLabel,
  }) =>
      '${shortEnergyLabel(miniRoyaleCardEnergyType(card))} ${card.energyCost}';

  static String stats(RoyaleCard card, String Function(String) translate) {
    if (card.isJob) {
      return '${translate(_jobLabelKey(card))} · ${translate('Base Pay')} ${card.effectValue.toInt()}';
    }
    if (card.type == 'spell') {
      return '${translate('Spell')} ${card.spellDamage}';
    }
    if (card.type != 'equipment') {
      return 'HP ${card.hp} / DMG ${card.damage}';
    }
    return switch (card.effectKind) {
      'damage_boost' =>
        '${translate('Equipment: +Damage')} ${card.effectValue.toInt()}',
      'health_boost' =>
        '${translate('Equipment: +Health')} ${card.effectValue.toInt()}',
      'speed_boost' =>
        '${translate('Equipment: +Speed')} ${(card.effectValue * 100).toInt()}%',
      'hanger_strike' =>
        '${translate('Equipment: +Damage')} ${card.effectValue.toInt()} · ${translate('Bruise')} 20% · ${translate('Mental Illness')} 1%+',
      'cane_strike' =>
        '${translate('Equipment: +Damage')} ${card.effectValue.toInt()} · ${translate('Bruise')} 50% · ${translate('Bleed')} 20%',
      'bottle_strike' =>
        '${translate('Equipment: +Damage')} ${card.effectValue.toInt()} · ${translate('Miss')} 20% · ${translate('Bleed')} 40%',
      'western_med' => translate('Equipment: Random Effect'),
      'eastern_med' => '${translate('Equipment: Slow on Hit')} 20%',
      'electric_shock' => '${translate('Equipment: Stun')} 60%',
      _ => translate('Equipment Card'),
    };
  }

  static String _jobLabelKey(RoyaleCard card) => switch (card.effectKind) {
    'job_delivery' => 'Delivery Gig',
    'job_day_labor' => 'Day Labor',
    _ => 'Part-time Shift',
  };
}

/// Game-owned discard target; the host retains what discarding means.
class MiniRoyaleDiscardDropZone<T extends Object> extends StatelessWidget {
  const MiniRoyaleDiscardDropZone({
    super.key,
    required this.cardForPayload,
    required this.discardable,
    required this.label,
    required this.costLabel,
    required this.tooltip,
    required this.onDiscard,
    this.compact = false,
  });

  final RoyaleCard Function(T payload) cardForPayload;
  final bool discardable;
  final String label;
  final String costLabel;
  final String tooltip;
  final ValueChanged<RoyaleCard> onDiscard;
  final bool compact;

  @override
  Widget build(BuildContext context) => DragTarget<T>(
    onWillAcceptWithDetails: (_) => true,
    onAcceptWithDetails: (details) {
      // The payload is deliberately opaque to the game view; the App
      // provides the selected card represented by the accepted payload.
      onDiscard(cardForPayload(details.data));
    },
    builder: (context, candidates, rejected) {
      final active = candidates.isNotEmpty;
      final accent = discardable
          ? const Color(0xFFB388FF)
          : Colors.white.withValues(alpha: 0.26);
      final background = active
          ? const Color(0xFF2A1748)
          : discardable
          ? const Color(0xFF21183A)
          : const Color(0xFF07111F);
      return Tooltip(
        message: '$tooltip · $costLabel',
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          width: compact ? 58 : 148,
          height: compact ? 46 : 54,
          padding: EdgeInsets.symmetric(
            horizontal: compact ? 7 : 12,
            vertical: compact ? 7 : 9,
          ),
          decoration: BoxDecoration(
            color: background.withValues(alpha: active ? 0.95 : 0.82),
            borderRadius: BorderRadius.circular(compact ? 16 : 18),
            border: Border.all(
              color: active ? const Color(0xFFFFD166) : accent,
              width: active ? 1.8 : 1.1,
            ),
          ),
          child: compact
              ? Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.delete_outline_rounded,
                      color: discardable ? Colors.white : Colors.white54,
                      size: 18,
                    ),
                    Text(
                      costLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: discardable ? Colors.white70 : Colors.white38,
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                )
              : Row(
                  children: [
                    Icon(
                      Icons.delete_outline_rounded,
                      color: discardable ? Colors.white : Colors.white54,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: discardable
                                  ? Colors.white
                                  : Colors.white54,
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          Text(
                            costLabel,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: discardable
                                  ? Colors.white70
                                  : Colors.white38,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
        ),
      );
    },
  );
}

/// Pure game card presentation. Localized strings and gameplay affordability
/// are supplied by the host so this package does not depend on App services.
class MiniRoyaleHandCard extends StatelessWidget {
  const MiniRoyaleHandCard({
    super.key,
    required this.card,
    required this.name,
    required this.playable,
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
  final String name;
  final bool playable;
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
    final cardColor = miniRoyaleHandCardColor(card.type);
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
                    Flexible(child: _pill(typeLabel, compact: compact)),
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
                if (_hasImage(card)) ...[
                  SizedBox(
                    width: double.infinity,
                    height: compact ? 40 : 72,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        if (_has(card.bgImageUrl))
                          Image.network(
                            card.bgImageUrl!,
                            fit: BoxFit.cover,
                            gaplessPlayback: true,
                            errorBuilder: (_, _, _) => const SizedBox.shrink(),
                          ),
                        if (_has(card.characterImageUrl))
                          Image.network(
                            card.characterImageUrl!,
                            fit: BoxFit.contain,
                            gaplessPlayback: true,
                            errorBuilder: (_, _, _) => const SizedBox.shrink(),
                          )
                        else if (!_has(card.bgImageUrl) && _has(card.imageUrl))
                          Image.network(
                            card.imageUrl!,
                            fit: BoxFit.contain,
                            gaplessPlayback: true,
                            errorBuilder: (_, _, _) => const SizedBox.shrink(),
                          ),
                      ],
                    ),
                  ),
                  SizedBox(height: compact ? 6 : 10),
                ],
                Text(
                  name,
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

  Widget _pill(String text, {required bool compact}) => Container(
    padding: EdgeInsets.symmetric(
      horizontal: compact ? 5 : 8,
      vertical: compact ? 3 : 5,
    ),
    decoration: BoxDecoration(
      color: Colors.white.withValues(alpha: 0.16),
      borderRadius: BorderRadius.circular(999),
    ),
    child: Text(
      text,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        color: Colors.white,
        fontWeight: FontWeight.w700,
        fontSize: compact ? 8 : 11,
      ),
    ),
  );

  bool _has(String? value) => value != null && value.isNotEmpty;
  bool _hasImage(RoyaleCard card) =>
      _has(card.bgImageUrl) ||
      _has(card.characterImageUrl) ||
      _has(card.imageUrl);
}
