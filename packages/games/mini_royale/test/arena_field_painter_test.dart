import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taiwan_brawl_game_mini_royale/taiwan_brawl_game_mini_royale.dart';

void main() {
  testWidgets('package-owned arena painter renders the game field', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: SizedBox(
          width: 320,
          height: 500,
          child: CustomPaint(
            painter: MiniRoyaleArenaPainter(
              playerSide: 'left',
              arena: defaultArenaConfig,
            ),
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(
      const MiniRoyaleArenaPainter(
        playerSide: 'left',
        arena: defaultArenaConfig,
      ).shouldRepaint(
        const MiniRoyaleArenaPainter(
          playerSide: 'right',
          arena: defaultArenaConfig,
        ),
      ),
      isTrue,
    );
  });
}
