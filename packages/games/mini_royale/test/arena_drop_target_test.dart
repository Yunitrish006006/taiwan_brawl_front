import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taiwan_brawl_game_mini_royale/taiwan_brawl_game_mini_royale.dart';

void main() {
  testWidgets('accepts allowed payloads and reports battlefield drops', (
    tester,
  ) async {
    String? dropped;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              const Draggable<String>(
                data: 'deploy',
                feedback: Material(child: Text('deploying')),
                child: Text('card'),
              ),
              MiniRoyaleBattlefieldDropTarget<String>(
                canAccept: (payload) => payload == 'deploy',
                onAccept: (details) => dropped = details.data,
                onMove: (_) {},
                onLeave: () {},
                builder: (context, highlighted) => Container(
                  key: const ValueKey('battlefield'),
                  width: 240,
                  height: 180,
                  color: highlighted ? Colors.amber : Colors.green,
                ),
              ),
            ],
          ),
        ),
      ),
    );

    await tester.drag(find.text('card'), const Offset(0, 160));
    await tester.pumpAndSettle();

    expect(dropped, 'deploy');
  });
}
