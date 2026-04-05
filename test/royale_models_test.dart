import 'package:flutter_test/flutter_test.dart';

import 'package:front/models/royale_models.dart';

void main() {
  test('card localizedName falls back to English and legacy name', () {
    const card = RoyaleCard(
      id: 'punk',
      name: 'Legacy Name',
      nameZhHant: '八加九',
      nameEn: 'Delinquent',
      nameJa: '',
      imageUrl: null,
      imageVersion: 0,
      energyCost: 3,
      energyCostType: 'physical',
      type: 'melee',
      hp: 300,
      damage: 100,
      attackRange: 100,
      bodyRadius: 18,
      moveSpeed: 140,
      attackSpeed: 1,
      spawnCount: 1,
      spellRadius: 0,
      spellDamage: 0,
      targetRule: 'ground',
      effectKind: 'none',
      effectValue: 0,
    );

    expect(card.localizedName('zh-Hant'), '八加九');
    expect(card.localizedName('en'), 'Delinquent');
    expect(card.localizedName('ja'), 'Delinquent');
  });

  test('unit localizedName falls back to English and legacy name', () {
    const unit = RoyaleUnitView(
      id: 'u1',
      cardId: 'punk',
      name: 'Legacy Name',
      nameZhHant: '',
      nameEn: '',
      nameJa: 'ヤンキー',
      imageUrl: null,
      side: 'left',
      type: 'melee',
      progress: 500,
      lateralPosition: 500,
      hp: 300,
      maxHp: 300,
      attackRange: 118,
      bodyRadius: 18,
      effects: [],
    );

    expect(unit.localizedName('ja'), 'ヤンキー');
    expect(unit.localizedName('en'), 'Legacy Name');
    expect(unit.localizedName('zh-Hant'), 'Legacy Name');
  });
}
