import 'package:flutter_test/flutter_test.dart';

import 'package:taiwan_brawl/services/royale_battle_rules.dart';

void main() {
  test(
    'normalizeDropPoint converts normalized inputs into world coordinates',
    () {
      final leftPoint = normalizeDropPoint(
        'left',
        dropX: 0.5,
        dropY: 0.75,
        lanePosition: null,
      );
      expect(leftPoint.progress, 250);
      expect(leftPoint.lateralPosition, 500);

      final rightPoint = normalizeDropPoint(
        'right',
        dropX: 0.9,
        dropY: 0.2,
        lanePosition: null,
      );
      expect(rightPoint.progress, 580);
      expect(rightPoint.lateralPosition, 880);
    },
  );

  test('attack reach helpers include body radius', () {
    expect(
      effectiveAttackReachToUnit(
        attackRange: 100,
        bodyRadius: 18,
        targetBodyRadius: 24,
      ),
      142,
    );
    expect(effectiveAttackReachToTower(attackRange: 100, bodyRadius: 18), 148);
  });

  test('legal deploy points and lateral clamping use battlefield bounds', () {
    expect(isLegalDeployPoint(0.5, 0.7), isTrue);
    expect(isLegalDeployPoint(0.05, 0.7), isFalse);
    expect(sanitizeLateralPosition(-1), lateralMin.toDouble());
    expect(sanitizeLateralPosition(5000), lateralMax.toDouble());
  });
}
