import 'package:flutter_test/flutter_test.dart';
import 'package:taiwan_brawl_game_mini_royale/taiwan_brawl_game_mini_royale.dart';

void main() {
  test('nested Royale card assets use the injected API origin', () {
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
      'characterAssets': [
        {'assetId': 'idle-front-0', 'imageUrl': '/card-assets/card/idle.png'},
      ],
    }, apiBaseUrl: 'https://api.example.test');

    expect(card.imageUrl, 'https://api.example.test/card-images/card.png');
    expect(
      card.characterAssets.single.imageUrl,
      'https://api.example.test/card-assets/card/idle.png',
    );
  });
}
