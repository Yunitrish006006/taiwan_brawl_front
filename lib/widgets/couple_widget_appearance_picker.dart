import 'package:flutter/material.dart';
import '../services/couple_widget_bridge.dart';
import 'couples_text.dart';

enum CoupleWidgetPalette {
  rose(0xFFFFF0F4, 0xFFF9D9E3, 0xFF57263D),
  lavender(0xFFF3EFFF, 0xFFE2D9FA, 0xFF44305F),
  ocean(0xFFECF6FF, 0xFFD6E9FA, 0xFF234B66),
  mint(0xFFEAF7F1, 0xFFD2EBDF, 0xFF254C3F),
  sand(0xFFFFF7EA, 0xFFF2E4C9, 0xFF654D2C),
  midnight(0xFF263049, 0xFF161D30, 0xFFF2E8F0);

  const CoupleWidgetPalette(this.start, this.end, this.ink);
  final int start, end, ink;
  static CoupleWidgetPalette decode(String? id) =>
      values.firstWhere((p) => p.name == id, orElse: () => rose);
  LinearGradient get gradient => LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(start), Color(end)],
  );
}

abstract interface class CoupleWidgetAppearanceStore {
  Future<CoupleWidgetPalette> read();
  Future<void> write(CoupleWidgetPalette palette);
}

class NativeCoupleWidgetAppearanceStore implements CoupleWidgetAppearanceStore {
  const NativeCoupleWidgetAppearanceStore();
  @override
  Future<CoupleWidgetPalette> read() async => CoupleWidgetPalette.decode(
    await NativeCoupleWidgetBridge.channel.invokeMethod<String>(
      'readAppearance',
    ),
  );
  @override
  Future<void> write(CoupleWidgetPalette palette) => NativeCoupleWidgetBridge
      .channel
      .invokeMethod<void>('setAppearance', {'palette': palette.name});
}

class CoupleWidgetAppearancePicker extends StatefulWidget {
  const CoupleWidgetAppearancePicker({
    super.key,
    this.days,
    this.partnerName,
    this.store = const NativeCoupleWidgetAppearanceStore(),
  });
  final int? days;
  final String? partnerName;
  final CoupleWidgetAppearanceStore store;
  @override
  State<CoupleWidgetAppearancePicker> createState() => _AppearanceState();
}

class _AppearanceState extends State<CoupleWidgetAppearancePicker> {
  CoupleWidgetPalette _palette = CoupleWidgetPalette.rose;
  bool _busy = true, _failed = false;
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _busy = true;
      _failed = false;
    });
    try {
      final palette = await widget.store.read();
      if (mounted) setState(() => _palette = palette);
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _select(CoupleWidgetPalette palette) async {
    setState(() {
      _busy = true;
      _failed = false;
    });
    try {
      await widget.store.write(palette);
      if (mounted) setState(() => _palette = palette);
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    String text(String key) => couplesText(context, key);
    final label = widget.days == null
        ? text('couples.noPartner')
        : couplesText(context, 'couples.widgetDayCount', {'days': '${widget.days}'});
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(text('couples.appearanceHint')),
          const SizedBox(height: 12),
          Container(
            height: 132,
            width: double.infinity,
            decoration: BoxDecoration(
              gradient: _palette.gradient,
              borderRadius: BorderRadius.circular(28),
            ),
            clipBehavior: Clip.antiAlias,
            child: Stack(
              children: [
                Positioned(
                  top: -24,
                  right: -16,
                  child: ExcludeSemantics(
                    child: Container(
                      width: 104,
                      height: 104,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Color(_palette.ink).withValues(alpha: 0.05),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  top: 16,
                  right: 20,
                  child: ExcludeSemantics(
                    child: Icon(
                      Icons.favorite_border_rounded,
                      size: 20,
                      color: Color(_palette.ink).withValues(alpha: 0.45),
                    ),
                  ),
                ),
                Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 28),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (widget.partnerName != null && widget.days != null)
                          Text(
                            couplesText(context, 'couples.widgetPartnerLine', {
                              'name': widget.partnerName!,
                            }),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 14,
                              color: Color(_palette.ink),
                            ),
                          ),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            label,
                            style: TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.w600,
                              color: Color(_palette.ink),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final palette in CoupleWidgetPalette.values)
                ChoiceChip(
                  key: ValueKey('widget-palette-${palette.name}'),
                  avatar: DecoratedBox(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: palette.gradient,
                    ),
                    child: const SizedBox(width: 20, height: 20),
                  ),
                  label: Text(text('couples.palette.${palette.name}')),
                  selected: palette == _palette,
                  onSelected: _busy
                      ? null
                      : (selected) {
                          if (selected) _select(palette);
                        },
                ),
            ],
          ),
          if (_busy) const LinearProgressIndicator(),
          if (_failed) ...[
            Text(
              text('couples.appearanceFailed'),
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
            TextButton(
              onPressed: _busy ? null : _load,
              child: Text(text('couples.refresh')),
            ),
          ],
        ],
      ),
    );
  }
}
