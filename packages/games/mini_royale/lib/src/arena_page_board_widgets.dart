part of 'mini_royale_arena_page.dart';

class _TowerTargetOverlay extends StatelessWidget {
  const _TowerTargetOverlay({
    required this.color,
    required this.bodyDiameter,
    this.threatDiameter,
    this.emphasized = false,
  });

  final Color color;
  final double bodyDiameter;
  final double? threatDiameter;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    var markerDiameter = bodyDiameter + 10;
    if (markerDiameter < 16) {
      markerDiameter = 16;
    } else if (markerDiameter > 24) {
      markerDiameter = 24;
    }
    final ringDiameter = markerDiameter + 10;

    return IgnorePointer(
      child: SizedBox(
        width: (threatDiameter ?? ringDiameter) + 28,
        height: (threatDiameter ?? ringDiameter) + 28,
        child: Stack(
          alignment: Alignment.center,
          children: [
            if (threatDiameter != null && threatDiameter! > 0)
              Container(
                width: threatDiameter,
                height: threatDiameter,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: color.withValues(alpha: emphasized ? 0.09 : 0.05),
                  border: Border.all(
                    color: color.withValues(alpha: emphasized ? 0.34 : 0.18),
                    width: emphasized ? 1.8 : 1.2,
                  ),
                ),
              ),
            Container(
              width: ringDiameter,
              height: ringDiameter,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF07111F).withValues(alpha: 0.14),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.34),
                  width: 1.1,
                ),
              ),
            ),
            Container(
              width: markerDiameter,
              height: markerDiameter,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: color.withValues(alpha: emphasized ? 0.26 : 0.18),
                border: Border.all(
                  color: color.withValues(alpha: 0.96),
                  width: 2.1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: color.withValues(alpha: emphasized ? 0.28 : 0.16),
                    blurRadius: emphasized ? 16 : 10,
                  ),
                ],
              ),
            ),
            Container(
              width: 2,
              height: ringDiameter + 10,
              color: color.withValues(alpha: 0.7),
            ),
            Container(
              width: ringDiameter + 10,
              height: 2,
              color: color.withValues(alpha: 0.7),
            ),
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.white.withValues(alpha: 0.5),
                    blurRadius: 8,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TowerToken extends StatelessWidget {
  const _TowerToken({
    required this.heroName,
    required this.color,
    required this.towerHp,
    required this.maxTowerHp,
    this.compact = false,
  });

  final String heroName;
  final Color color;
  final int towerHp;
  final int maxTowerHp;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return MiniRoyaleTowerToken(
      heroName: heroName,
      color: color,
      towerHp: towerHp,
      maxTowerHp: maxTowerHp,
      compact: compact,
    );
  }
}
