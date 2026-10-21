import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taiwan_brawl_game_mini_royale/taiwan_brawl_game_mini_royale.dart';

class _PresentationSource implements MiniRoyaleArenaPresentationSource {
  _PresentationSource(this.value);
  final String? value;

  @override
  Future<String?> readActivePresentationJson() async => value;
}

void main() {
  test('round-trips a versioned presentation pack', () {
    const presentation = MiniRoyaleArenaPresentation(
      fieldColors: [
        Color(0xFF010203),
        Color(0xFF112233),
        Color(0xFF445566),
        Color(0xFF778899),
      ],
    );
    final decoded = MiniRoyaleArenaPresentation.fromJson(presentation.toJson());
    expect(decoded.fieldColors, presentation.fieldColors);
    expect(
      miniRoyaleArenaPresentationResourceId,
      'game.mini-royale.arena-presentation',
    );
    expect(
      miniRoyaleSupportedResourceSchemas[miniRoyaleArenaPresentationResourceId],
      miniRoyaleArenaPresentationSchemaVersion,
    );
  });

  test(
    'resource validator checks presentation bytes before activation',
    () async {
      final valid = Uint8List.fromList(
        utf8.encode(
          '{"schemaVersion":1,"fieldColors":["#FF010203","#FF112233","#FF445566","#FF778899"]}',
        ),
      );
      await validateMiniRoyaleArenaPresentationPayload(valid);
      await expectLater(
        validateMiniRoyaleArenaPresentationPayload(
          Uint8List.fromList(utf8.encode('{"schemaVersion":2}')),
        ),
        throwsFormatException,
      );
    },
  );

  test(
    'uses the built-in palette when the optional resource is missing or invalid',
    () async {
      expect(
        await loadMiniRoyaleArenaPresentation(_PresentationSource(null)),
        MiniRoyaleArenaPresentation.fallback,
      );
      expect(
        await loadMiniRoyaleArenaPresentation(
          _PresentationSource('{"schemaVersion":99}'),
        ),
        MiniRoyaleArenaPresentation.fallback,
      );
    },
  );
}
