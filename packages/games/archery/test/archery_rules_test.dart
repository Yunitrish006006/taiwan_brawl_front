import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:taiwan_brawl_game_archery/taiwan_brawl_game_archery.dart';

void main() {
  group('ArcheryRules', () {
    test('built-in tuning preserves the current gameplay constants', () {
      final rules = ArcheryRules.builtIn;

      expect(rules.bowSpeed(1, drawing: false), 0.012);
      expect(rules.bowSpeed(1, drawing: true), closeTo(0.0036, 1e-10));
      expect(rules.staminaDrain(1), 1.2);
      expect(rules.arrowRiseSpeed(1, 1), 0.07);
      expect(rules.scoreForDistance(0.04), 100);
      expect(rules.scoreForDistance(0.08), 60);
      expect(rules.scoreForDistance(0.15), 30);
      expect(rules.scoreForDistance(0.2), 0);
    });

    test('a valid resource changes the rules used by gameplay helpers', () {
      final json = ArcheryRules.builtIn.toJson()
        ..['version'] = 'season-2'
        ..['targetMovesAtScore'] = 300
        ..['staminaDrainBase'] = 2
        ..['scoreBands'] = [
          {'maxDistance': 0.2, 'score': 80},
        ];
      final rules = ArcheryRules.decode(jsonEncode(json));

      expect(rules.version, 'season-2');
      expect(rules.targetMovesAtScore, 300);
      expect(rules.staminaDrain(1), 2.2);
      expect(rules.scoreForDistance(0.1), 80);
      expect(rules.scoreForDistance(0.2), 0);
    });

    test('rejects unsupported schema and unsafe tuning', () {
      final unsupported = ArcheryRules.builtIn.toJson()..['schemaVersion'] = 2;
      expect(() => ArcheryRules.fromJson(unsupported), throwsFormatException);

      final unsafe = ArcheryRules.builtIn.toJson()
        ..['targetSpeedMultiplier'] = 1000;
      expect(() => ArcheryRules.fromJson(unsafe), throwsFormatException);
    });

    test(
      'resource validator accepts only gameplay-consumable payloads',
      () async {
        final valid = Uint8List.fromList(
          utf8.encode(jsonEncode(ArcheryRules.builtIn.toJson())),
        );
        await validateArcheryRulesPayload(valid);

        await expectLater(
          validateArcheryRulesPayload(Uint8List.fromList(utf8.encode('{}'))),
          throwsFormatException,
        );
      },
    );
  });
}
