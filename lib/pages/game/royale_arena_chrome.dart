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

class _DualEnergyMeter extends StatelessWidget {
  const _DualEnergyMeter({
    required this.physicalEnergy,
    required this.spiritEnergy,
    this.compact = false,
  });

  final RoyaleResourceState physicalEnergy;
  final RoyaleResourceState spiritEnergy;
  final bool compact;

  @override
  Widget build(BuildContext context) {
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
          _MiniEnergyBar(
            icon: Icons.bolt_rounded,
            value: physicalEnergy.current,
            maxValue: physicalEnergy.max,
            color: const Color(0xFF4FC3F7),
            compact: compact,
          ),
          SizedBox(width: compact ? 8 : 10),
          _MiniEnergyBar(
            icon: Icons.auto_awesome_rounded,
            value: spiritEnergy.current,
            maxValue: spiritEnergy.max,
            color: const Color(0xFFB388FF),
            compact: compact,
          ),
        ],
      ),
    );
  }
}

class _MiniEnergyBar extends StatelessWidget {
  const _MiniEnergyBar({
    required this.icon,
    required this.value,
    required this.maxValue,
    required this.color,
    required this.compact,
  });

  final IconData icon;
  final double value;
  final double maxValue;
  final Color color;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final active = value.floor();
    final meterCount = maxValue.ceil().clamp(3, 8);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: compact ? 14 : 16),
            SizedBox(width: compact ? 4 : 5),
            Text(
              '${value.toStringAsFixed(1)}/${maxValue.toStringAsFixed(1)}',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: compact ? 11 : 12,
              ),
            ),
          ],
        ),
        SizedBox(height: compact ? 4 : 5),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(meterCount, (index) {
            return Container(
              width: compact ? 6 : 8,
              height: compact ? 10 : 12,
              margin: EdgeInsets.only(
                right: index == meterCount - 1 ? 0 : (compact ? 2 : 3),
              ),
              decoration: BoxDecoration(
                color: index < active
                    ? color
                    : Colors.white.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(999),
              ),
            );
          }),
        ),
      ],
    );
  }
}

class _ArenaLegendChip extends StatelessWidget {
  const _ArenaLegendChip({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
          fontSize: 13,
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
            style: TextStyle(color: Colors.white, fontSize: compact ? 11 : 13),
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
