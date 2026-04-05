part of 'royale_arena_page.dart';

class _GlowOrb extends StatelessWidget {
  const _GlowOrb({required this.size, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(colors: [color, Colors.transparent]),
        ),
      ),
    );
  }
}

class _ArenaFriendInviteButton extends StatelessWidget {
  const _ArenaFriendInviteButton({
    required this.label,
    required this.onTap,
    required this.backgroundColor,
    required this.foregroundColor,
    this.isLoading = false,
  });

  final String label;
  final VoidCallback? onTap;
  final Color backgroundColor;
  final Color foregroundColor;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null && !isLoading;
    final effectiveForeground = enabled
        ? foregroundColor
        : foregroundColor.withValues(alpha: 0.45);

    return SizedBox(
      height: 32,
      child: Material(
        color: enabled
            ? backgroundColor
            : backgroundColor.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          onTap: enabled ? onTap : null,
          borderRadius: BorderRadius.circular(10),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Center(
              child: isLoading
                  ? SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          effectiveForeground,
                        ),
                      ),
                    )
                  : Text(
                      label,
                      style: TextStyle(
                        color: effectiveForeground,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

class _GlassPanel extends StatelessWidget {
  const _GlassPanel({
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.gradient,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final Gradient? gradient;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        gradient:
            gradient ??
            LinearGradient(
              colors: [
                Colors.white.withValues(alpha: 0.08),
                Colors.white.withValues(alpha: 0.04),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF020817).withValues(alpha: 0.36),
            blurRadius: 28,
            offset: const Offset(0, 18),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _SideBadge extends StatelessWidget {
  const _SideBadge({required this.side, required this.color});

  final String side;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 52,
      height: 52,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: [color, color.withValues(alpha: 0.7)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.26),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      alignment: Alignment.center,
      child: Text(
        side == 'left' ? 'L' : 'R',
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w800,
          fontSize: 18,
        ),
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.28)),
      ),
      child: Text(
        label,
        style: TextStyle(color: color, fontWeight: FontWeight.w700),
      ),
    );
  }
}

class _PlayerHudCard extends StatelessWidget {
  const _PlayerHudCard({
    required this.title,
    required this.subtitle,
    required this.hero,
    required this.physicalHealth,
    required this.spiritHealth,
    required this.physicalEnergy,
    required this.spiritEnergy,
    required this.money,
    required this.towerHp,
    required this.maxTowerHp,
    required this.color,
    required this.alignEnd,
    this.compact = false,
  });

  final String title;
  final String subtitle;
  final RoyaleHero hero;
  final RoyaleResourceState physicalHealth;
  final RoyaleResourceState spiritHealth;
  final RoyaleResourceState physicalEnergy;
  final RoyaleResourceState spiritEnergy;
  final RoyaleResourceState money;
  final int towerHp;
  final int maxTowerHp;
  final Color color;
  final bool alignEnd;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final progress = maxTowerHp == 0 ? 0.0 : towerHp / maxTowerHp;
    final locale = context.watch<LocaleProvider>().locale;
    return Container(
      padding: EdgeInsets.all(compact ? 12 : 16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: alignEnd
            ? CrossAxisAlignment.end
            : CrossAxisAlignment.start,
        children: [
          Text(
            subtitle,
            style: TextStyle(
              color: color.withValues(alpha: 0.9),
              fontWeight: FontWeight.w700,
              fontSize: compact ? 11 : 13,
            ),
          ),
          SizedBox(height: compact ? 2 : 4),
          Text(
            title,
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
            hero.localizedName(locale),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: const Color(0xFFFFD166),
              fontWeight: FontWeight.w800,
              fontSize: compact ? 11 : 13,
            ),
          ),
          SizedBox(height: compact ? 2 : 4),
          Text(
            hero.localizedBonusSummary(locale),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: alignEnd ? TextAlign.end : TextAlign.start,
            style: TextStyle(
              color: Colors.white70,
              fontSize: compact ? 10 : 12,
            ),
          ),
          SizedBox(height: compact ? 8 : 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: progress.clamp(0.0, 1.0),
              minHeight: compact ? 8 : 12,
              backgroundColor: Colors.white.withValues(alpha: 0.08),
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),
          SizedBox(height: compact ? 6 : 8),
          Text(
            '$towerHp / $maxTowerHp',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.86),
              fontSize: compact ? 11 : 13,
            ),
          ),
          SizedBox(height: compact ? 8 : 10),
          _ResourceStrip(
            label: context.watch<LocaleProvider>().translation.text(
              'Physical Health',
            ),
            value: physicalHealth.current,
            max: physicalHealth.max,
            color: const Color(0xFFFF7B7B),
            compact: compact,
            alignEnd: alignEnd,
          ),
          SizedBox(height: compact ? 6 : 8),
          _ResourceStrip(
            label: context.watch<LocaleProvider>().translation.text(
              'Spirit Health',
            ),
            value: spiritHealth.current,
            max: spiritHealth.max,
            color: const Color(0xFF7BDFF2),
            compact: compact,
            alignEnd: alignEnd,
          ),
          SizedBox(height: compact ? 6 : 8),
          _ResourceStrip(
            label: context.watch<LocaleProvider>().translation.text(
              'Physical Energy',
            ),
            value: physicalEnergy.current,
            max: physicalEnergy.max,
            color: const Color(0xFFFFB703),
            compact: compact,
            alignEnd: alignEnd,
          ),
          SizedBox(height: compact ? 6 : 8),
          _ResourceStrip(
            label: context.watch<LocaleProvider>().translation.text(
              'Spirit Energy',
            ),
            value: spiritEnergy.current,
            max: spiritEnergy.max,
            color: const Color(0xFF9B5DE5),
            compact: compact,
            alignEnd: alignEnd,
          ),
          SizedBox(height: compact ? 6 : 8),
          _ResourceStrip(
            label: context.watch<LocaleProvider>().translation.text('Money'),
            value: money.current,
            max: money.max,
            color: const Color(0xFF80ED99),
            compact: compact,
            alignEnd: alignEnd,
            footer:
                '+${money.regenPerSecond.toStringAsFixed(1)}/${context.watch<LocaleProvider>().translation.text('sec')}',
          ),
        ],
      ),
    );
  }
}

class _ElixirMeter extends StatelessWidget {
  const _ElixirMeter({
    required this.value,
    required this.maxValue,
    this.compact = false,
  });

  final double value;
  final double maxValue;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final active = value.floor();
    final meterCount = maxValue.ceil().clamp(4, 14);
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 10 : 12,
        vertical: compact ? 8 : 10,
      ),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.flash_on_rounded,
            color: const Color(0xFFB388FF),
            size: compact ? 16 : 20,
          ),
          SizedBox(width: compact ? 6 : 8),
          ...List.generate(meterCount, (index) {
            return Container(
              width: compact ? 7 : 10,
              height: compact ? 14 : 18,
              margin: EdgeInsets.only(
                right: index == meterCount - 1 ? 0 : (compact ? 3 : 4),
              ),
              decoration: BoxDecoration(
                color: index < active
                    ? const Color(0xFF9B5DE5)
                    : Colors.white.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(999),
              ),
            );
          }),
        ],
      ),
    );
  }
}

class _ResourceStrip extends StatelessWidget {
  const _ResourceStrip({
    required this.label,
    required this.value,
    required this.max,
    required this.color,
    required this.compact,
    required this.alignEnd,
    this.footer,
  });

  final String label;
  final double value;
  final double max;
  final Color color;
  final bool compact;
  final bool alignEnd;
  final String? footer;

  @override
  Widget build(BuildContext context) {
    final progress = max <= 0 ? 0.0 : (value / max).clamp(0.0, 1.0);
    return Column(
      crossAxisAlignment:
          alignEnd ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: alignEnd
              ? MainAxisAlignment.end
              : MainAxisAlignment.start,
          children: [
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.w700,
                  fontSize: compact ? 10 : 11,
                ),
              ),
            ),
            SizedBox(width: compact ? 6 : 8),
            Text(
              '${value.toStringAsFixed(1)} / ${max.toStringAsFixed(1)}',
              style: TextStyle(
                color: Colors.white70,
                fontSize: compact ? 10 : 11,
              ),
            ),
          ],
        ),
        SizedBox(height: compact ? 4 : 5),
        SizedBox(
          width: double.infinity,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: compact ? 5 : 6,
              backgroundColor: Colors.white.withValues(alpha: 0.08),
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),
        ),
        if (footer != null) ...[
          SizedBox(height: compact ? 3 : 4),
          Text(
            footer!,
            style: TextStyle(
              color: Colors.white54,
              fontSize: compact ? 9 : 10,
            ),
          ),
        ],
      ],
    );
  }
}

class _ArenaLegendChip extends StatelessWidget {
  const _ArenaLegendChip({
    required this.label,
    required this.color,
    this.compact = false,
  });

  final String label;
  final Color color;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 10 : 12,
        vertical: compact ? 6 : 8,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w700,
          fontSize: compact ? 11 : 13,
        ),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({
    required this.icon,
    required this.label,
    this.compact = false,
  });

  final IconData icon;
  final String label;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 10 : 12,
        vertical: compact ? 6 : 8,
      ),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: compact ? 14 : 16, color: Colors.white70),
          SizedBox(width: compact ? 4 : 6),
          Text(
            label,
            style: TextStyle(
              color: Colors.white,
              fontSize: compact ? 11 : 13,
            ),
          ),
        ],
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel({
    required this.label,
    required this.color,
    this.compact = false,
  });

  final String label;
  final Color color;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 8 : 10,
        vertical: compact ? 4 : 6,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.24)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w700,
          fontSize: compact ? 11 : 13,
        ),
      ),
    );
  }
}
