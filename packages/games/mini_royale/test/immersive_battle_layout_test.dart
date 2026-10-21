import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taiwan_brawl_game_mini_royale/taiwan_brawl_game_mini_royale.dart';

void main() {
  testWidgets('renders the hand region selected by the current viewport', (
    tester,
  ) async {
    const sideHandKey = ValueKey('side-hand');
    const bottomHandKey = ValueKey('bottom-hand');

    Widget buildLayout() => const MaterialApp(
      home: Scaffold(
        body: MiniRoyaleImmersiveBattleLayout(
          fieldAspectRatio: 0.7,
          fieldBuilder: _field,
          topOverlay: SizedBox(height: 40),
          bottomHand: SizedBox(key: bottomHandKey, height: 80),
          sideHand: SizedBox(key: sideHandKey),
        ),
      ),
    );

    await tester.binding.setSurfaceSize(const Size(400, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(buildLayout());
    expect(find.byKey(bottomHandKey), findsOneWidget);
    expect(find.byKey(sideHandKey), findsNothing);

    await tester.binding.setSurfaceSize(const Size(1200, 900));
    await tester.pumpWidget(buildLayout());
    await tester.pumpAndSettle();
    expect(find.byKey(sideHandKey), findsOneWidget);
    expect(find.byKey(bottomHandKey), findsNothing);
  });

  test('uses bottom hand tray when the viewport is narrow', () {
    final metrics = MiniRoyaleImmersiveBattleMetrics.calculate(
      maxWidth: 400,
      maxHeight: 800,
      safeTop: 24,
      safeBottom: 16,
      fieldAspectRatio: 0.7,
    );

    expect(metrics.useSideHand, isFalse);
    expect(metrics.sideReservedWidth, 0);
    expect(metrics.topReservedHeight, 132);
    expect(metrics.bottomReservedHeight, 214);
    expect(metrics.fieldHeight, closeTo(454, 0.001));
    expect(metrics.fieldWidth, closeTo(317.8, 0.001));
  });

  test('reserves a side hand and fits the field on wide viewports', () {
    final metrics = MiniRoyaleImmersiveBattleMetrics.calculate(
      maxWidth: 1200,
      maxHeight: 900,
      safeTop: 20,
      safeBottom: 10,
      fieldAspectRatio: 0.7,
    );

    expect(metrics.useSideHand, isTrue);
    expect(metrics.sideHandWidth, 220);
    expect(metrics.sideReservedWidth, 242);
    expect(metrics.topReservedHeight, 128);
    expect(metrics.bottomReservedHeight, 20);
    expect(metrics.fieldHeight, closeTo(752, 0.001));
    expect(metrics.fieldWidth, closeTo(526.4, 0.001));
  });

  test('clamps tiny viewports and uses the package default field ratio', () {
    final metrics = MiniRoyaleImmersiveBattleMetrics.calculate(
      maxWidth: 300,
      maxHeight: 250,
      safeTop: 20,
      safeBottom: 10,
      fieldAspectRatio: 0,
    );

    expect(metrics.fieldWidth, 0);
    expect(metrics.fieldHeight, 0);
  });
}

Widget _field(BuildContext context, double width, double height) =>
    SizedBox(width: width, height: height);
