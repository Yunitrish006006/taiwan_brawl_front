import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:taiwan_brawl_game_mini_royale/taiwan_brawl_game_mini_royale.dart';

void main() {
  testWidgets('aim marker renders coordinates and can hide its label', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: MiniRoyaleAimMarker(point: Offset(0.5, 0.5), active: true),
        ),
      ),
    );
    expect(find.textContaining('x '), findsOneWidget);

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: MiniRoyaleAimMarker(
            point: Offset(0.5, 0.5),
            active: true,
            showLabel: false,
          ),
        ),
      ),
    );
    expect(find.textContaining('x '), findsNothing);
  });

  testWidgets('field label honors host-provided text', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: MiniRoyaleFieldLabel(label: 'Your zone', color: Colors.green),
        ),
      ),
    );
    expect(find.text('Your zone'), findsOneWidget);
  });

  testWidgets('tower token renders game status from host values', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: MiniRoyaleTowerToken(
            heroName: 'Archer',
            color: Colors.blue,
            towerHp: 60,
            maxTowerHp: 100,
          ),
        ),
      ),
    );

    expect(find.text('Archer'), findsOneWidget);
    expect(find.text('60'), findsOneWidget);
    expect(find.byIcon(Icons.castle_rounded), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('unit token renders health, effects, and fallback label', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: MiniRoyaleUnitToken(
            fallbackLabel: 'A',
            friendly: true,
            hp: 25,
            maxHp: 50,
            effectCount: 2,
          ),
        ),
      ),
    );

    expect(find.text('A'), findsOneWidget);
    expect(find.text('+2'), findsOneWidget);
    final healthBar = tester.widget<FractionallySizedBox>(
      find.byType(FractionallySizedBox),
    );
    expect(healthBar.widthFactor, 0.5);
    expect(tester.takeException(), isNull);
  });

  testWidgets('battlefield canvas owns scene painting and forwards taps', (
    tester,
  ) async {
    var tapped = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: MiniRoyaleBattlefieldCanvas(
              width: 280,
              height: 420,
              playerSide: 'left',
              arena: defaultArenaConfig,
              compact: false,
              fullscreen: false,
              highlightDropZone: false,
              enemyBaseLabel: 'Enemy Base',
              bridgeLabel: 'Central Bridge',
              deploymentZoneLabel: 'Your Zone',
              onHover: (_) {},
              onExit: (_) {},
              onTapDown: (_) => tapped = true,
              buildOverlays: (_) => const [
                Positioned(right: 8, top: 8, child: Text('Unit overlay')),
              ],
            ),
          ),
        ),
      ),
    );

    expect(find.text('Enemy Base'), findsOneWidget);
    expect(find.text('Central Bridge'), findsOneWidget);
    expect(find.text('Your Zone'), findsOneWidget);
    expect(find.text('Unit overlay'), findsOneWidget);
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is CustomPaint && widget.painter is MiniRoyaleArenaPainter,
      ),
      findsOneWidget,
    );
    await tester.tap(find.byType(MiniRoyaleBattlefieldCanvas));
    expect(tapped, isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('animated portrait is game-owned and falls back without frames', (
    tester,
  ) async {
    final cache = BattleAnimationCacheService(
      store: _TestAnimationStore(),
      remoteSource: _TestAnimationRemote(),
    );
    await tester.pumpWidget(
      ChangeNotifierProvider<BattleAnimationCacheService>.value(
        value: cache,
        child: const MaterialApp(
          home: Scaffold(
            body: MiniRoyaleAnimatedUnitPortrait(
              frames: [],
              eventFrames: [],
              eventKey: null,
              fallbackUrl: null,
              fallback: Text('unit fallback'),
            ),
          ),
        ),
      ),
    );

    expect(find.text('unit fallback'), findsOneWidget);
    expect(tester.takeException(), isNull);
    cache.dispose();
  });

  testWidgets('result overlay presents host text and forwards rematch action', (
    tester,
  ) async {
    var playedAgain = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Stack(
            children: [
              MiniRoyaleBattleResultOverlay(
                resultLabel: 'Victory',
                subtitle: 'Battle finished',
                actionLabel: 'Play Again',
                compact: true,
                isSubmitting: false,
                onPlayAgain: () => playedAgain = true,
              ),
            ],
          ),
        ),
      ),
    );

    expect(find.text('Victory'), findsOneWidget);
    expect(find.text('Battle finished'), findsOneWidget);
    await tester.tap(find.text('Play Again'));
    expect(playedAgain, isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('battlefield header selects instruction and forwards toggle', (
    tester,
  ) async {
    var toggled = false;
    const labels = MiniRoyaleBattlefieldLabels(
      releaseToDeployHere: 'Release compact',
      releaseToCastSelectionHere: 'Release full',
      tapToDeploySelection: 'Tap compact',
      precisionTapInstruction: 'Tap full',
      dragCardToArena: 'Drag compact',
      dragOrSelectCardsInstruction: 'Drag full',
      yourLeftBase: 'Left base',
      yourRightBase: 'Right base',
      collisionOverlayTooltip: 'Collision overlay',
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MiniRoyaleBattlefieldHeader(
            highlightDropZone: true,
            hasSelection: true,
            playerSide: 'left',
            compact: true,
            showCollisionRadius: false,
            labels: labels,
            onToggleCollisionRadius: () => toggled = true,
          ),
        ),
      ),
    );

    expect(find.text('Release compact'), findsOneWidget);
    expect(find.text('Left base'), findsNothing);
    await tester.tap(find.byTooltip('Collision overlay'));
    expect(toggled, isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('battlefield units own positioning and optional range overlays', (
    tester,
  ) async {
    final battle = RoyaleBattleView(
      timeRemainingMs: 0,
      yourMoney: 0,
      yourHand: const [],
      nextCardId: null,
      units: const [
        RoyaleUnitView(
          id: 'unit-1',
          cardId: 'card-1',
          name: 'Unit',
          nameZhHant: '單位',
          nameEn: 'Unit',
          nameJa: 'Unit',
          imageUrl: null,
          characterImageUrl: null,
          bgImageUrl: null,
          side: 'left',
          type: 'unit',
          progress: 10000,
          lateralPosition: 500,
          hp: 20,
          maxHp: 40,
          attackRange: 5000,
          bodyRadius: 1000,
          effects: ['shield'],
          statusEffects: [],
        ),
      ],
      events: const [],
      result: null,
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 300,
            height: 600,
            child: MiniRoyaleBattlefieldUnits(
              battle: battle,
              viewerSide: 'left',
              locale: 'zh-Hant',
              showCollisionRadii: true,
            ),
          ),
        ),
      ),
    );

    expect(find.byKey(const ValueKey('attack-range:unit-1')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('collision-radius:unit-1')),
      findsOneWidget,
    );
    expect(find.text('單'), findsOneWidget);
    expect(find.text('+1'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

class _TestAnimationRemote implements BattleAnimationRemoteSource {
  @override
  Future<Uint8List?> download(Uri uri) async => null;
  @override
  void dispose() {}
}

class _TestAnimationStore implements BattleAnimationCacheStore {
  @override
  Future<void> initialize() async {}
  @override
  Future<bool> readEnabled() async => false;
  @override
  Future<void> writeEnabled(bool value) async {}
  @override
  bool containsBytes(String cacheKey) => false;
  @override
  String? readBytes(String cacheKey) => null;
  @override
  Future<void> writeBytes(String cacheKey, String encodedBytes) async {}
  @override
  Future<void> deleteBytes(String cacheKey) async {}
  @override
  String? readMeta(String identity) => null;
  @override
  Future<void> writeMeta(String identity, String encodedMeta) async {}
  @override
  Future<void> deleteMeta(String identity) async {}
}
