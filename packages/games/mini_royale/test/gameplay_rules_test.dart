import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:taiwan_brawl_game_mini_royale/taiwan_brawl_game_mini_royale.dart';

void main() {
  const fixture = <String, dynamic>{
    'schemaVersion': 1,
    'rulesetId': 'mini-royale-ranked',
    'rulesetVersion': 1,
    'matchDurationMs': 210000,
    'towerHitPoints': 3000,
    'attackSpeedMultiplier': 1.18,
    'moveSpeedMultiplier': 0.58,
  };

  test('parses and serializes the bounded gameplay rules v1 schema', () {
    final rules = MiniRoyaleGameplayRules.fromJson(fixture);
    expect(rules.toJson(), fixture);
    expect(
      rules.matchDurationMs,
      bundledMiniRoyaleGameplayRules.matchDurationMs,
    );
    expect(rules.towerHitPoints, bundledMiniRoyaleGameplayRules.towerHitPoints);
    expect(
      rules.attackSpeedMultiplier,
      bundledMiniRoyaleGameplayRules.attackSpeedMultiplier,
    );
    expect(
      rules.moveSpeedMultiplier,
      bundledMiniRoyaleGameplayRules.moveSpeedMultiplier,
    );
  });

  test('rejects unknown, missing, and out-of-range gameplay values', () {
    expect(
      () => MiniRoyaleGameplayRules.fromJson({...fixture, 'script': 'run()'}),
      throwsFormatException,
    );
    expect(
      () => MiniRoyaleGameplayRules.fromJson(
        {...fixture}..remove('towerHitPoints'),
      ),
      throwsFormatException,
    );
    expect(
      () =>
          MiniRoyaleGameplayRules.fromJson({...fixture, 'matchDurationMs': 1}),
      throwsFormatException,
    );
    expect(
      () => MiniRoyaleGameplayRules.fromJson({...fixture, 'schemaVersion': 2}),
      throwsFormatException,
    );
  });

  test(
    'resource validator rejects malformed and executable payload data',
    () async {
      await validateMiniRoyaleGameplayRulesPayload(
        Uint8List.fromList(utf8.encode(jsonEncode(fixture))),
      );
      await expectLater(
        validateMiniRoyaleGameplayRulesPayload(
          Uint8List.fromList(
            utf8.encode(jsonEncode({...fixture, 'script': 'run()'})),
          ),
        ),
        throwsFormatException,
      );
    },
  );
}
