import 'dart:convert';

import 'gameplay_rules.dart';

/// Stable identity and compatibility contract owned by Mini Royale.
const miniRoyaleModuleId = 'game.mini-royale';
const miniRoyaleManifestVersion = 1;
const miniRoyaleKind = 'game';
const miniRoyalePublisher = 'taiwan-brawl';
const miniRoyalePackageVersion = '0.1.0';
const miniRoyaleMinimumShellVersion = '0.132.0';
const miniRoyaleHostApiRange = '>=1.0.0 <2.0.0';
const miniRoyaleDataSchemaVersion = 1;
const miniRoyaleSupportedPlatforms = <String>[
  'web',
  'android',
  'ios',
  'windows',
  'macos',
  'linux',
];

/// Consumer schemas implemented by this package. Download metadata and
/// signatures remain owned by the remote signed catalog.
const miniRoyaleSupportedResourceSchemas = <String, int>{
  'game.mini-royale.arena-presentation': 1,
  miniRoyaleGameplayRulesResourceId: 1,
};

class MiniRoyaleModuleManifest {
  const MiniRoyaleModuleManifest({
    required this.moduleId,
    required this.packageVersion,
    required this.minimumShellVersion,
    required this.dataSchemaVersion,
    required this.protocolVersion,
    required this.compatibleProtocolRange,
    required this.rulesetId,
    required this.rulesetVersion,
    required this.gameplayContentDigest,
    this.platforms = miniRoyaleSupportedPlatforms,
  });

  final String moduleId;
  final String packageVersion;
  final String minimumShellVersion;
  final int dataSchemaVersion;
  final int protocolVersion;
  final String compatibleProtocolRange;
  final String rulesetId;
  final int rulesetVersion;
  final String gameplayContentDigest;
  final List<String> platforms;

  Map<String, Object> toJson() => {
    'moduleId': moduleId,
    'manifestVersion': miniRoyaleManifestVersion,
    'kind': miniRoyaleKind,
    'publisher': miniRoyalePublisher,
    'packageVersion': packageVersion,
    'minimumShellVersion': minimumShellVersion,
    'hostApiRange': miniRoyaleHostApiRange,
    'dependencies': const <Object>[],
    'dataSchemaVersion': dataSchemaVersion,
    'platforms': platforms,
    'multiplayer': {
      'protocolVersion': protocolVersion,
      'compatibleProtocolRange': compatibleProtocolRange,
      'rulesetId': rulesetId,
      'rulesetVersion': rulesetVersion,
      'gameplayContentDigest': gameplayContentDigest,
    },
  };
}

/// The server mirrors this contract and rejects joins that do not match.
final miniRoyaleGameContract = Map<String, Object>.unmodifiable({
  'gameId': miniRoyaleManifest.moduleId,
  'moduleVersion': miniRoyaleManifest.packageVersion,
  'protocolVersion': miniRoyaleManifest.protocolVersion,
  'compatibleProtocolRange': miniRoyaleManifest.compatibleProtocolRange,
  'rulesetId': miniRoyaleManifest.rulesetId,
  'rulesetVersion': miniRoyaleManifest.rulesetVersion,
  'gameplayContentDigest': miniRoyaleManifest.gameplayContentDigest,
  'gameplayResources': const <Object>[],
});

const miniRoyaleManifest = MiniRoyaleModuleManifest(
  moduleId: miniRoyaleModuleId,
  packageVersion: miniRoyalePackageVersion,
  minimumShellVersion: miniRoyaleMinimumShellVersion,
  dataSchemaVersion: miniRoyaleDataSchemaVersion,
  protocolVersion: 1,
  compatibleProtocolRange: '>=1 <2',
  rulesetId: 'mini-royale-ranked',
  rulesetVersion: 1,
  gameplayContentDigest: 'builtin-royale-rules-v1',
  platforms: miniRoyaleSupportedPlatforms,
);

bool isCompatibleMiniRoyaleContract(
  Map<String, Object?> candidate, [
  Map<String, Object>? required,
]) {
  required ??= miniRoyaleGameContract;
  final candidateVersion = candidate['moduleVersion'];
  final requiredVersion = required['moduleVersion'];
  final candidateProtocol = candidate['protocolVersion'];
  final requiredProtocol = required['protocolVersion'];
  final candidateRange = candidate['compatibleProtocolRange'];
  final requiredRange = required['compatibleProtocolRange'];
  if (candidate['gameId'] != required['gameId'] ||
      candidateVersion is! String ||
      !_isSemver(candidateVersion) ||
      requiredVersion is! String ||
      !_isSemver(requiredVersion) ||
      candidateProtocol is! int ||
      requiredProtocol is! int ||
      candidateRange is! String ||
      requiredRange is! String ||
      !_includesProtocol(candidateRange, candidateProtocol) ||
      !_includesProtocol(requiredRange, requiredProtocol) ||
      !_includesProtocol(requiredRange, candidateProtocol) ||
      !_includesProtocol(candidateRange, requiredProtocol)) {
    return false;
  }

  for (final key in ['rulesetId', 'rulesetVersion', 'gameplayContentDigest']) {
    if (candidate[key] != required[key]) return false;
  }
  return _canonicalJson(candidate['gameplayResources']) ==
      _canonicalJson(required['gameplayResources']);
}

bool _isSemver(String value) => RegExp(
  r'^(0|[1-9]\d*)\.(0|[1-9]\d*)\.(0|[1-9]\d*)(?:-[0-9A-Za-z.-]+)?(?:\+[0-9A-Za-z.-]+)?$',
).hasMatch(value);

bool _includesProtocol(String range, int version) {
  final match = RegExp(r'^>=(\d+) <(\d+)$').firstMatch(range);
  if (match == null) return false;
  final minimum = int.parse(match.group(1)!);
  final maximum = int.parse(match.group(2)!);
  return minimum >= 1 &&
      minimum < maximum &&
      version >= minimum &&
      version < maximum;
}

String _canonicalJson(Object? value) {
  Object? canonicalize(Object? current) {
    if (current is Map) {
      final entries = current.entries.toList()
        ..sort(
          (left, right) => left.key.toString().compareTo(right.key.toString()),
        );
      return {
        for (final entry in entries)
          entry.key.toString(): canonicalize(entry.value),
      };
    }
    if (current is Iterable) {
      return current.map(canonicalize).toList(growable: false);
    }
    return current;
  }

  return jsonEncode(canonicalize(value));
}
