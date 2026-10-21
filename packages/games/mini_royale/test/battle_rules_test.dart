import 'package:flutter_test/flutter_test.dart';
import 'package:taiwan_brawl_game_mini_royale/taiwan_brawl_game_mini_royale.dart';

void main() {
  test('Mini Royale package owns deploy and reach rules', () {
    expect(isLegalDeployPoint(0.5, 0.7), isTrue);
    expect(isLegalDeployPoint(-0.05, 0.7), isFalse);
    expect(
      effectiveAttackReachToUnit(
        attackRange: 100,
        bodyRadius: 18,
        targetBodyRadius: 24,
      ),
      142,
    );
  });

  test(
    'Mini Royale models resolve game assets from the injected API origin',
    () {
      final card = RoyaleCard.fromJson({
        'id': 'card-1',
        'name': 'Card',
        'type': 'melee',
        'hp': 100,
        'damage': 10,
        'attackRange': 100,
        'moveSpeed': 100,
        'attackSpeed': 1,
        'spawnCount': 1,
        'spellRadius': 0,
        'spellDamage': 0,
        'targetRule': 'ground',
        'imageUrl': '/card-images/card.png',
      }, apiBaseUrl: 'https://game-api.example');
      expect(card.imageUrl, 'https://game-api.example/card-images/card.png');
    },
  );
}
