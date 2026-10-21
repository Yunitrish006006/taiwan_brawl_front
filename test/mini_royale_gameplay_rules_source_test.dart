import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taiwan_brawl/game_modules/mini_royale/gameplay_rules_source.dart';
import 'package:taiwan_brawl/services/game_resource_content_store.dart';
import 'package:taiwan_brawl_game_mini_royale/taiwan_brawl_game_mini_royale.dart';

class _RulesStore implements GameResourceContentStore {
  _RulesStore(this.bytes, this.version);
  final Uint8List? bytes;
  final String? version;

  @override
  Future<Uint8List?> readActive(String moduleId, String resourceId) async =>
      bytes;
  @override
  Future<String?> readActiveVersion(String moduleId, String resourceId) async =>
      version;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  const rulesJson = <String, dynamic>{
    'schemaVersion': 1,
    'rulesetId': 'mini-royale-ranked',
    'rulesetVersion': 1,
    'matchDurationMs': 240000,
    'towerHitPoints': 4000,
    'attackSpeedMultiplier': 1.25,
    'moveSpeedMultiplier': 0.7,
  };
  final bytes = Uint8List.fromList(utf8.encode(jsonEncode(rulesJson)));
  final digest = sha256.convert(bytes).toString();
  final contentDigest = miniRoyaleGameplayContentDigestForResources([
    (
      resourceId: miniRoyaleGameplayRulesResourceId,
      version: '1.2.0',
      sha256: digest,
    ),
  ]);
  MiniRoyaleGameplayRulesSource source(GameResourceContentStore store) =>
      GameResourceMiniRoyaleGameplayRulesSource(contentStore: store);

  test(
    'loads only the active rules version and digest pinned by the room',
    () async {
      final contract = {
        'rulesetId': 'mini-royale-ranked',
        'rulesetVersion': 1,
        'gameplayContentDigest': contentDigest,
        'gameplayResources': [
          {
            'resourceId': miniRoyaleGameplayRulesResourceId,
            'version': '1.2.0',
            'sha256': digest,
          },
        ],
      };
      final rules = await loadMiniRoyaleGameplayRules(
        source: source(_RulesStore(bytes, '1.2.0')),
        gameContract: contract,
      );
      expect(rules.toJson(), rulesJson);
      await expectLater(
        loadMiniRoyaleGameplayRules(
          source: source(_RulesStore(bytes, '1.2.0')),
          gameContract: {...contract, 'gameplayContentDigest': 'b' * 64},
        ),
        throwsFormatException,
      );
    },
  );

  test(
    'uses bundled rules only for the exact built-in room contract',
    () async {
      final rules = await loadMiniRoyaleGameplayRules(
        source: source(_RulesStore(null, null)),
        gameContract: {
          'rulesetId': 'mini-royale-ranked',
          'rulesetVersion': 1,
          'gameplayContentDigest': 'builtin-royale-rules-v1',
          'gameplayResources': const [],
        },
      );
      expect(rules, bundledMiniRoyaleGameplayRules);
      await expectLater(
        loadMiniRoyaleGameplayRules(
          source: source(_RulesStore(null, null)),
          gameContract: {
            'rulesetId': 'mini-royale-ranked',
            'rulesetVersion': 1,
            'gameplayContentDigest': 'a' * 64,
            'gameplayResources': const [],
          },
        ),
        throwsFormatException,
      );
    },
  );

  test('rejects a missing or malformed room contract resource list', () async {
    for (final contract in <Map<String, dynamic>?>[
      null,
      {'gameplayContentDigest': 'builtin-royale-rules-v1'},
      {
        'rulesetId': 'mini-royale-ranked',
        'rulesetVersion': 1,
        'gameplayContentDigest': 'builtin-royale-rules-v1',
        'gameplayResources': 'not-a-list',
      },
    ]) {
      await expectLater(
        loadMiniRoyaleGameplayRules(
          source: source(_RulesStore(null, null)),
          gameContract: contract,
        ),
        throwsFormatException,
      );
    }
  });

  test(
    'rejects a missing/different active version or tampered local bytes',
    () async {
      final contract = {
        'rulesetId': 'mini-royale-ranked',
        'rulesetVersion': 1,
        'gameplayContentDigest': contentDigest,
        'gameplayResources': [
          {
            'resourceId': miniRoyaleGameplayRulesResourceId,
            'version': '1.2.0',
            'sha256': digest,
          },
        ],
      };
      await expectLater(
        loadMiniRoyaleGameplayRules(
          source: source(_RulesStore(bytes, '1.1.0')),
          gameContract: contract,
        ),
        throwsFormatException,
      );
      await expectLater(
        loadMiniRoyaleGameplayRules(
          source: source(
            _RulesStore(Uint8List.fromList(utf8.encode('{}')), '1.2.0'),
          ),
          gameContract: contract,
        ),
        throwsFormatException,
      );
    },
  );
}
