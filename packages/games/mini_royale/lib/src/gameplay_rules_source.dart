import 'dart:convert';

import 'package:crypto/crypto.dart';

import 'gameplay_rules.dart';
import 'mini_royale_module.dart';

typedef MiniRoyaleGameplayResourceIdentity = ({
  String resourceId,
  String version,
  String sha256,
});

/// Computes the same canonical digest used by the room authority for its
/// sorted set of gameplay-affecting resource identities.
String miniRoyaleGameplayContentDigestForResources(
  Iterable<MiniRoyaleGameplayResourceIdentity> resources,
) {
  final sorted = resources.toList()
    ..sort((left, right) => left.resourceId.compareTo(right.resourceId));
  if (sorted.isEmpty) return miniRoyaleManifest.gameplayContentDigest;
  return sha256
      .convert(
        utf8.encode(
          [
            miniRoyaleManifest.gameplayContentDigest,
            ...sorted.map(
              (resource) =>
                  '${resource.resourceId}@${resource.version}:${resource.sha256.toLowerCase()}',
            ),
          ].join('\n'),
        ),
      )
      .toString();
}

/// Platform-neutral access to the locally active, verified Mini Royale pack.
abstract interface class MiniRoyaleGameplayRulesSource {
  Future<String?> readActiveVersion(String resourceId);
  Future<List<int>?> readActiveBytes(String resourceId);
}

/// Resolves the game rules pinned by the authoritative room contract.
/// Contract validation and payload decoding belong to Mini Royale; the App
/// supplies only the local content-store adapter.
Future<MiniRoyaleGameplayRules> loadMiniRoyaleGameplayRules({
  required MiniRoyaleGameplayRulesSource source,
  required Map<String, dynamic>? gameContract,
}) async {
  if (gameContract == null) {
    throw const FormatException(
      'The room is missing its authoritative game contract.',
    );
  }
  final resources = gameContract['gameplayResources'];
  if (resources is! List) {
    throw const FormatException(
      'The room gameplay resource list is missing or malformed.',
    );
  }
  if (resources.isEmpty) {
    if (gameContract['gameplayContentDigest'] !=
            miniRoyaleManifest.gameplayContentDigest ||
        gameContract['rulesetId'] != miniRoyaleManifest.rulesetId ||
        gameContract['rulesetVersion'] != miniRoyaleManifest.rulesetVersion) {
      throw const FormatException(
        'The room contract does not match bundled gameplay rules.',
      );
    }
    return bundledMiniRoyaleGameplayRules;
  }
  if (resources.length != 1 || resources.single is! Map) {
    throw const FormatException(
      'Unsupported gameplay resource set for host simulation.',
    );
  }
  final resource = Map<String, dynamic>.from(resources.single as Map);
  final resourceId = resource['resourceId'];
  final version = resource['version'];
  final digest = resource['sha256'];
  if (resourceId != miniRoyaleGameplayRulesResourceId ||
      version is! String ||
      digest is! String ||
      !RegExp(r'^[a-fA-F0-9]{64}$').hasMatch(digest)) {
    throw const FormatException(
      'The room references an unsupported Mini Royale rules resource.',
    );
  }

  final expectedContentDigest = miniRoyaleGameplayContentDigestForResources([
    (resourceId: resourceId, version: version, sha256: digest),
  ]);
  final contentDigest = gameContract['gameplayContentDigest'];
  if (contentDigest is! String ||
      contentDigest.toLowerCase() != expectedContentDigest) {
    throw const FormatException(
      'The room gameplay resource list does not match its content digest.',
    );
  }

  if (await source.readActiveVersion(resourceId as String) != version) {
    throw const FormatException(
      'The room rules version is not installed on this device.',
    );
  }
  final bytes = await source.readActiveBytes(resourceId);
  if (bytes == null ||
      sha256.convert(bytes).toString() != digest.toLowerCase()) {
    throw const FormatException(
      'The installed room rules failed their digest check.',
    );
  }
  final decoded = jsonDecode(utf8.decode(bytes, allowMalformed: false));
  if (decoded is! Map<String, dynamic>) {
    throw const FormatException(
      'The installed room rules are not a JSON object.',
    );
  }
  final rules = MiniRoyaleGameplayRules.fromJson(decoded);
  if (rules.rulesetId != gameContract['rulesetId'] ||
      rules.rulesetVersion != gameContract['rulesetVersion']) {
    throw const FormatException(
      'The installed rules do not match the room ruleset.',
    );
  }
  return rules;
}
