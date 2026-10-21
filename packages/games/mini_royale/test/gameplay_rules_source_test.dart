import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taiwan_brawl_game_mini_royale/taiwan_brawl_game_mini_royale.dart';

class _RulesSource implements MiniRoyaleGameplayRulesSource {
  _RulesSource(this.bytes, this.version);

  final List<int>? bytes;
  final String? version;

  @override
  Future<List<int>?> readActiveBytes(String resourceId) async => bytes;

  @override
  Future<String?> readActiveVersion(String resourceId) async => version;
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
  final bytes = utf8.encode(jsonEncode(rulesJson));
  final digest = sha256.convert(bytes).toString();
  final contentDigest = miniRoyaleGameplayContentDigestForResources([
    (
      resourceId: miniRoyaleGameplayRulesResourceId,
      version: '1.2.0',
      sha256: digest,
    ),
  ]);

  test(
    'resolves only the active version and digest pinned by the room',
    () async {
      final rules = await loadMiniRoyaleGameplayRules(
        source: _RulesSource(bytes, '1.2.0'),
        gameContract: {
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
        },
      );
      expect(rules.toJson(), rulesJson);
    },
  );

  test('accepts built-in rules only for the exact bundled contract', () async {
    final contract = {
      'rulesetId': miniRoyaleManifest.rulesetId,
      'rulesetVersion': miniRoyaleManifest.rulesetVersion,
      'gameplayContentDigest': miniRoyaleManifest.gameplayContentDigest,
      'gameplayResources': const [],
    };
    expect(
      await loadMiniRoyaleGameplayRules(
        source: _RulesSource(null, null),
        gameContract: contract,
      ),
      bundledMiniRoyaleGameplayRules,
    );
    await expectLater(
      loadMiniRoyaleGameplayRules(
        source: _RulesSource(null, null),
        gameContract: {...contract, 'gameplayContentDigest': 'a' * 64},
      ),
      throwsFormatException,
    );
  });

  test(
    'rejects missing, unsupported, mismatched, and tampered resources',
    () async {
      final resourceContract = {
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
      final pinnedResource = Map<String, dynamic>.from(
        (resourceContract['gameplayResources'] as List).single as Map,
      );
      for (final invalidContract in <Map<String, dynamic>?>[
        null,
        {'gameplayResources': 'malformed'},
        {
          ...resourceContract,
          'gameplayResources': [
            {...pinnedResource, 'version': '2.0.0'},
          ],
        },
        {
          ...resourceContract,
          'gameplayResources': [
            {
              'resourceId': miniRoyaleGameplayRulesResourceId,
              'version': '1.2.0',
              'sha256': 'not-a-digest',
            },
          ],
        },
        {...resourceContract, 'gameplayContentDigest': 'a' * 64},
        {...resourceContract, 'gameplayContentDigest': null},
      ]) {
        await expectLater(
          loadMiniRoyaleGameplayRules(
            source: _RulesSource(bytes, '1.2.0'),
            gameContract: invalidContract,
          ),
          throwsFormatException,
        );
      }
      await expectLater(
        loadMiniRoyaleGameplayRules(
          source: _RulesSource(bytes, '1.1.0'),
          gameContract: resourceContract,
        ),
        throwsFormatException,
      );
      await expectLater(
        loadMiniRoyaleGameplayRules(
          source: _RulesSource(utf8.encode('{}'), '1.2.0'),
          gameContract: resourceContract,
        ),
        throwsFormatException,
      );
    },
  );
}
