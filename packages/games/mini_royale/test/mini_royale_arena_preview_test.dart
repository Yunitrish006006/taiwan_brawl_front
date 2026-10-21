import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taiwan_brawl_game_mini_royale/taiwan_brawl_game_mini_royale.dart';

Widget _preview() => MaterialApp(
  home: Scaffold(
    body: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 860),
        child: MiniRoyaleArenaPreview(
          arena: defaultArenaConfig,
          playerSide: 'left',
          mapTypeLabel: 'Random Map',
          arenaName: 'Classic Bridge',
          bridgeLabel: 'Bridge',
          arenaLabel: 'Arena',
        ),
      ),
    ),
  ),
);

void main() {
  testWidgets('game-owned arena preview renders map metadata and field', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(420, 800);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpWidget(_preview());

    expect(find.text('Random Map'), findsOneWidget);
    expect(find.text('Classic Bridge'), findsOneWidget);
    expect(find.text('Bridge x1'), findsOneWidget);
    expect(find.text('1000 x 1000 Arena'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('mini-royale-arena-preview-compact')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('game-owned arena preview adapts to a wide lobby layout', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(820, 800);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpWidget(_preview());

    expect(
      find.byKey(const ValueKey('mini-royale-arena-preview-wide')),
      findsOneWidget,
    );
    expect(find.text('Classic Bridge'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
