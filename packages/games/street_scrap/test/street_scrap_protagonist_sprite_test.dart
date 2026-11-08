import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taiwan_brawl_game_street_scrap/src/street_scrap_protagonist_sprite.dart';
import 'package:taiwan_brawl_game_street_scrap/street_scrap_content.dart';

void main() {
  testWidgets('uses the lightweight painter until optional art is installed', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Center(child: StreetScrapProtagonistSprite(pose: 0, height: 180)),
      ),
    );

    final sprite = find.byType(StreetScrapProtagonistSprite);
    expect(
      find.descendant(of: sprite, matching: find.byType(CustomPaint)),
      findsOneWidget,
    );
    expect(find.byType(Image), findsNothing);
  });

  testWidgets('renders installed idle and action art from memory', (
    tester,
  ) async {
    final onePixelPng = Uint8List.fromList(
      base64Decode(
        'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAIAAACQd1PeAAAADUlEQVR4nGP4z8AAAAMBAQDJ/pLvAAAAAElFTkSuQmCC',
      ),
    );
    final art = StreetScrapProtagonistArt(
      idlePng: onePixelPng,
      actionsPng: onePixelPng,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Center(
          child: StreetScrapProtagonistSprite(pose: 0, height: 180, art: art),
        ),
      ),
    );
    expect(find.byType(Image), findsOneWidget);
    expect(tester.widget<Image>(find.byType(Image)).image, isA<MemoryImage>());

    await tester.pumpWidget(
      MaterialApp(
        home: Center(
          child: StreetScrapProtagonistSprite(pose: 1, height: 180, art: art),
        ),
      ),
    );
    expect(find.byType(Image), findsOneWidget);
    expect(tester.widget<Image>(find.byType(Image)).fit, BoxFit.cover);
    expect(tester.takeException(), isNull);
  });
}
