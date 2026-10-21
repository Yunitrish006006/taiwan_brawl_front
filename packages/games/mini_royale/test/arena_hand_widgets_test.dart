import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taiwan_brawl_game_mini_royale/taiwan_brawl_game_mini_royale.dart';

RoyaleCard _testCard() => RoyaleCard.fromJson({
  'id': 'hand-card',
  'name': 'Test Card',
  'type': 'tank',
  'energyCost': 1,
  'hp': 100,
  'damage': 20,
  'attackRange': 30,
  'moveSpeed': 10,
  'attackSpeed': 1,
  'spawnCount': 1,
  'spellRadius': 0,
  'spellDamage': 0,
  'targetRule': 'ground',
}, apiBaseUrl: 'https://game.example');

void main() {
  test('package derives localized hand-card semantics from card rules', () {
    final card = _testCard();
    expect(
      MiniRoyaleHandCardContent.typeLabel(card, (key) => '[$key]'),
      '[Tank]',
    );
    expect(
      MiniRoyaleHandCardContent.stats(card, (key) => '[$key]'),
      'HP 100 / DMG 20',
    );
    expect(miniRoyaleCardEnergyType(card), 'physical');
    expect(
      MiniRoyaleHandCardContent.energyLabel(
        card,
        shortEnergyLabel: (type) => type.toUpperCase(),
      ),
      'PHYSICAL 1',
    );

    final jobCard = RoyaleCard.fromJson({
      'id': 'job-card',
      'name': 'Job',
      'type': 'job',
      'effectKind': 'job_delivery',
      'effectValue': 1250,
      'hp': 0,
      'damage': 0,
      'attackRange': 0,
      'moveSpeed': 0,
      'attackSpeed': 1,
      'spawnCount': 1,
      'spellRadius': 0,
      'spellDamage': 0,
      'targetRule': 'ground',
    }, apiBaseUrl: 'https://game.example');
    expect(
      MiniRoyaleHandCardContent.stats(jobCard, (key) => '[$key]'),
      '[Delivery Gig] · [Base Pay] 1250',
    );
  });

  testWidgets('game package renders host-localized hand card data', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MiniRoyaleHandCard(
            card: _testCard(),
            name: '本地化卡名',
            playable: false,
            selectedOrder: 1,
            cardStats: 'HP 100 / DMG 20',
            typeLabel: '坦克',
            costLabel: '生 2',
            costIcon: Icons.bolt,
            costColor: Colors.cyan,
            insufficientLabel: '能量不足',
            compact: true,
          ),
        ),
      ),
    );

    expect(find.text('本地化卡名'), findsOneWidget);
    expect(find.text('坦克'), findsOneWidget);
    expect(find.text('能量不足'), findsOneWidget);
    expect(find.text('2'), findsOneWidget);
    expect(miniRoyaleHandCardColor('tank'), const Color(0xFF3557D6));
  });

  testWidgets('discard target projects host drag payload to its card', (
    tester,
  ) async {
    final card = _testCard();
    RoyaleCard? discarded;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              Draggable<int>(
                data: 7,
                feedback: const Material(child: Text('dragging')),
                child: const Text('drag source'),
              ),
              MiniRoyaleDiscardDropZone<int>(
                cardForPayload: (_) => card,
                discardable: true,
                label: '棄牌',
                costLabel: '生 1',
                tooltip: '拖曳至此棄牌',
                onDiscard: (value) => discarded = value,
              ),
            ],
          ),
        ),
      ),
    );

    final source = tester.getCenter(find.text('drag source'));
    final target = tester.getCenter(find.text('棄牌'));
    await tester.dragFrom(source, target - source);
    await tester.pumpAndSettle();
    expect(discarded, card);
  });
}
