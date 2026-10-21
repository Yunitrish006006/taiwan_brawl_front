import 'package:flutter/foundation.dart';

enum GamePlatform { web, android, ios, windows, macos, linux }

const gameHostApiVersion = '1.0.0';

const allGamePlatforms = <GamePlatform>[
  GamePlatform.web,
  GamePlatform.android,
  GamePlatform.ios,
  GamePlatform.windows,
  GamePlatform.macos,
  GamePlatform.linux,
];

GamePlatform? get currentGamePlatform {
  if (kIsWeb) return GamePlatform.web;
  return switch (defaultTargetPlatform) {
    TargetPlatform.android => GamePlatform.android,
    TargetPlatform.iOS => GamePlatform.ios,
    TargetPlatform.windows => GamePlatform.windows,
    TargetPlatform.macOS => GamePlatform.macos,
    TargetPlatform.linux => GamePlatform.linux,
    TargetPlatform.fuchsia => null,
  };
}

enum GameResourceKind { gameplayData, presentation, localization }

enum GameDependencyKind { module, resource }

class GameModuleDependency {
  const GameModuleDependency({
    required this.kind,
    required this.id,
    required this.versionRange,
    this.optional = false,
  });

  final GameDependencyKind kind;
  final String id;
  final String versionRange;
  final bool optional;

  factory GameModuleDependency.fromJson(Map<String, dynamic> json) =>
      GameModuleDependency(
        kind: GameDependencyKind.values.byName(json['kind'] as String),
        id: json['id'] as String,
        versionRange: json['versionRange'] as String,
        optional: json['optional'] as bool? ?? false,
      );

  Map<String, Object> toJson() => {
    'kind': kind.name,
    'id': id,
    'versionRange': versionRange,
    'optional': optional,
  };

  bool acceptsVersion(String version) {
    final match = RegExp(
      r'^>=(\d+\.\d+\.\d+) <(\d+\.\d+\.\d+)$',
    ).firstMatch(versionRange);
    return match != null &&
        _isSemanticVersion(version) &&
        _compareSemanticVersions(version, match.group(1)!) >= 0 &&
        _compareSemanticVersions(version, match.group(2)!) < 0;
  }

  void validate(String owner) {
    final validId = kind == GameDependencyKind.module
        ? RegExp(r'^game\.[a-z0-9]+(?:[.-][a-z0-9]+)*$').hasMatch(id)
        : RegExp(
            r'^game\.[a-z0-9]+(?:[.-][a-z0-9]+)*\.[a-z0-9][a-z0-9._-]*$',
          ).hasMatch(id);
    if (!validId || id == owner) {
      throw FormatException('Invalid ${kind.name} dependency ID: $id');
    }
    if (!RegExp(
      r'^>=(0|[1-9]\d*)\.(0|[1-9]\d*)\.(0|[1-9]\d*) <(0|[1-9]\d*)\.(0|[1-9]\d*)\.(0|[1-9]\d*)$',
    ).hasMatch(versionRange)) {
      throw FormatException('Invalid dependency version range: $versionRange');
    }
  }
}

enum GameResourceInstallStatus {
  queued,
  downloading,
  verifying,
  migrating,
  installed,
  removing,
  failed,
}

class GameMultiplayerManifest {
  const GameMultiplayerManifest({
    required this.protocolVersion,
    required this.compatibleProtocolRange,
    required this.rulesetId,
    required this.rulesetVersion,
    required this.gameplayContentDigest,
  });

  final int protocolVersion;
  final String compatibleProtocolRange;
  final String rulesetId;
  final int rulesetVersion;
  final String gameplayContentDigest;

  factory GameMultiplayerManifest.fromJson(Map<String, dynamic> json) =>
      GameMultiplayerManifest(
        protocolVersion: json['protocolVersion'] as int,
        compatibleProtocolRange: json['compatibleProtocolRange'] as String,
        rulesetId: json['rulesetId'] as String,
        rulesetVersion: json['rulesetVersion'] as int,
        gameplayContentDigest: json['gameplayContentDigest'] as String,
      );

  Map<String, Object> toJson() => {
    'protocolVersion': protocolVersion,
    'compatibleProtocolRange': compatibleProtocolRange,
    'rulesetId': rulesetId,
    'rulesetVersion': rulesetVersion,
    'gameplayContentDigest': gameplayContentDigest,
  };

  void validate() {
    if (protocolVersion < 1 || rulesetVersion < 1) {
      throw const FormatException('Multiplayer versions must be positive.');
    }
    if (!RegExp(r'^[a-z0-9]+(?:[.-][a-z0-9]+)*$').hasMatch(rulesetId)) {
      throw FormatException('Invalid multiplayer ruleset ID: $rulesetId');
    }
    final protocolRange = RegExp(
      r'^>=(\d+) <(\d+)$',
    ).firstMatch(compatibleProtocolRange);
    if (protocolRange == null) {
      throw const FormatException('Invalid compatible protocol range.');
    }
    final minimumProtocol = int.parse(protocolRange.group(1)!);
    final exclusiveMaximumProtocol = int.parse(protocolRange.group(2)!);
    if (minimumProtocol >= exclusiveMaximumProtocol ||
        protocolVersion < minimumProtocol ||
        protocolVersion >= exclusiveMaximumProtocol) {
      throw const FormatException(
        'Compatible protocol range must include the declared protocol version.',
      );
    }
    if (!RegExp(
      r'^(?:builtin-[a-z0-9-]+|[a-fA-F0-9]{64})$',
    ).hasMatch(gameplayContentDigest)) {
      throw const FormatException('Invalid gameplay content digest.');
    }
  }
}

class GameResourceManifest {
  const GameResourceManifest({
    required this.resourceId,
    required this.version,
    required this.kind,
    required this.sha256,
    required this.affectsGameplay,
    this.payloadSchemaVersion,
    this.downloadUrl,
    this.byteLength,
    this.signature,
    this.signingKeyId,
    this.required = false,
    this.dependencies = const [],
    this.activationGroup,
    this.platforms = allGamePlatforms,
  });

  final String resourceId;
  final String version;
  final GameResourceKind kind;
  final String sha256;
  final bool affectsGameplay;

  /// Decoder format for the downloaded payload, independent of resource semver
  /// and the game's local player-data schema.
  final int? payloadSchemaVersion;
  final String? downloadUrl;
  final int? byteLength;
  final String? signature;
  final String? signingKeyId;
  final bool required;
  final List<GameModuleDependency> dependencies;
  final String? activationGroup;
  final List<GamePlatform> platforms;

  factory GameResourceManifest.fromJson(
    Map<String, dynamic> json, {
    List<GamePlatform> defaultPlatforms = allGamePlatforms,
  }) {
    final kind = GameResourceKind.values.byName(json['kind'] as String);
    return GameResourceManifest(
      resourceId: json['resourceId'] as String,
      version: json['version'] as String,
      kind: kind,
      sha256: json['sha256'] as String,
      affectsGameplay: json['affectsGameplay'] as bool? ?? false,
      payloadSchemaVersion: json['payloadSchemaVersion'] as int?,
      downloadUrl: json['downloadUrl'] as String?,
      byteLength: json['byteLength'] as int?,
      signature: json['signature'] as String?,
      signingKeyId: json['signingKeyId'] as String?,
      required: json['required'] as bool? ?? false,
      dependencies: (json['dependencies'] as List<dynamic>? ?? const [])
          .map(
            (item) => GameModuleDependency.fromJson(
              Map<String, dynamic>.from(item as Map),
            ),
          )
          .toList(growable: false),
      activationGroup: json['activationGroup'] as String?,
      platforms: _parsePlatforms(json['platforms']) ?? defaultPlatforms,
    );
  }

  Map<String, Object?> toJson() => {
    'resourceId': resourceId,
    'version': version,
    'kind': kind.name,
    'sha256': sha256,
    'affectsGameplay': affectsGameplay,
    if (payloadSchemaVersion != null)
      'payloadSchemaVersion': payloadSchemaVersion,
    'required': required,
    'dependencies': dependencies
        .map((dependency) => dependency.toJson())
        .toList(),
    'activationGroup': activationGroup,
    'platforms': platforms.map((platform) => platform.name).toList(),
    if (downloadUrl != null) 'downloadUrl': downloadUrl,
    if (byteLength != null) 'byteLength': byteLength,
    if (signature != null) 'signature': signature,
    if (signingKeyId != null) 'signingKeyId': signingKeyId,
  };

  void validate(
    String moduleId, {
    required List<GamePlatform> modulePlatforms,
  }) {
    if (!resourceId.startsWith('$moduleId.')) {
      throw FormatException('Resource $resourceId must be owned by $moduleId.');
    }
    if (!_isSemanticVersion(version)) {
      throw FormatException('Invalid resource version: $version');
    }
    if (!RegExp(r'^[a-fA-F0-9]{64}$').hasMatch(sha256)) {
      throw FormatException(
        'Resource $resourceId must declare a SHA-256 digest.',
      );
    }
    if (affectsGameplay && kind != GameResourceKind.gameplayData) {
      throw FormatException(
        'Only gameplay-data resources may affect multiplayer gameplay.',
      );
    }
    if (payloadSchemaVersion != null && payloadSchemaVersion! < 1) {
      throw FormatException(
        'Resource $resourceId payload schema version must be positive.',
      );
    }
    if (activationGroup != null &&
        !RegExp(r'^[a-z0-9]+(?:[.-][a-z0-9]+)*$').hasMatch(activationGroup!)) {
      throw FormatException('Invalid activation group: $activationGroup');
    }
    _validatePlatforms(platforms, 'Resource $resourceId');
    final dependencyIds = <String>{};
    for (final dependency in dependencies) {
      dependency.validate(moduleId);
      if (dependency.kind == GameDependencyKind.resource &&
          dependency.id == resourceId) {
        throw FormatException('Resource $resourceId cannot depend on itself.');
      }
      if (!dependencyIds.add('${dependency.kind.name}:${dependency.id}')) {
        throw FormatException('Duplicate dependency: ${dependency.id}');
      }
    }
    if (platforms.any((platform) => !modulePlatforms.contains(platform))) {
      throw FormatException(
        'Resource $resourceId targets a platform unsupported by $moduleId.',
      );
    }
    if (downloadUrl != null) {
      final uri = Uri.tryParse(downloadUrl!);
      if (uri == null || uri.scheme != 'https' || !uri.hasAuthority) {
        throw FormatException('Resource $resourceId must use an HTTPS URL.');
      }
      if (byteLength == null || byteLength! < 0) {
        throw FormatException(
          'Resource $resourceId must declare its byte length.',
        );
      }
      if (signature == null || signature!.isEmpty || signingKeyId == null) {
        throw FormatException(
          'Resource $resourceId must be signed by a named key.',
        );
      }
    }
  }
}

class GameModuleManifest {
  GameModuleManifest({
    required this.moduleId,
    required this.displayName,
    required this.description,
    required this.packageVersion,
    required this.minimumShellVersion,
    required this.dataSchemaVersion,
    this.manifestVersion = 1,
    this.kind = 'game',
    this.publisher = 'taiwan-brawl',
    this.hostApiRange = '>=1.0.0 <2.0.0',
    List<GameModuleDependency> dependencies = const [],
    this.multiplayer,
    Map<String, int> supportedResourceSchemas = const {},
    required List<GameResourceManifest> resources,
    List<GamePlatform> platforms = allGamePlatforms,
  }) : dependencies = List.unmodifiable(dependencies),
       resources = List.unmodifiable(resources),
       supportedResourceSchemas = Map.unmodifiable(supportedResourceSchemas),
       platforms = List.unmodifiable(platforms) {
    validate();
  }

  final String moduleId;
  final String displayName;
  final String description;
  final int manifestVersion;
  final String kind;
  final String publisher;
  final String packageVersion;
  final String minimumShellVersion;
  final String hostApiRange;
  final int dataSchemaVersion;
  final List<GameModuleDependency> dependencies;
  final GameMultiplayerManifest? multiplayer;

  /// Resource payload schemas implemented by the bundled game package.
  final Map<String, int> supportedResourceSchemas;
  final List<GameResourceManifest> resources;
  final List<GamePlatform> platforms;

  bool supportsHostApiVersion(String version) =>
      _versionRangeAccepts(hostApiRange, version);

  factory GameModuleManifest.fromJson(Map<String, dynamic> json) {
    final platforms = _parsePlatforms(json['platforms']) ?? allGamePlatforms;
    return GameModuleManifest(
      moduleId: json['moduleId'] as String,
      displayName: json['displayName'] as String,
      description: json['description'] as String,
      manifestVersion: json['manifestVersion'] as int? ?? 1,
      kind: json['kind'] as String? ?? 'game',
      publisher: json['publisher'] as String? ?? 'taiwan-brawl',
      packageVersion: json['packageVersion'] as String,
      minimumShellVersion: json['minimumShellVersion'] as String,
      hostApiRange: json['hostApiRange'] as String? ?? '>=1.0.0 <2.0.0',
      dataSchemaVersion: json['dataSchemaVersion'] as int,
      dependencies: (json['dependencies'] as List<dynamic>? ?? const [])
          .map(
            (item) => GameModuleDependency.fromJson(
              Map<String, dynamic>.from(item as Map),
            ),
          )
          .toList(growable: false),
      multiplayer: json['multiplayer'] == null
          ? null
          : GameMultiplayerManifest.fromJson(
              Map<String, dynamic>.from(json['multiplayer'] as Map),
            ),
      platforms: platforms,
      resources: (json['resources'] as List<dynamic>)
          .map(
            (item) => GameResourceManifest.fromJson(
              Map<String, dynamic>.from(item as Map),
              defaultPlatforms: platforms,
            ),
          )
          .toList(growable: false),
    );
  }

  Map<String, Object?> toJson() => {
    'moduleId': moduleId,
    'manifestVersion': manifestVersion,
    'kind': kind,
    'publisher': publisher,
    'displayName': displayName,
    'description': description,
    'packageVersion': packageVersion,
    'minimumShellVersion': minimumShellVersion,
    'hostApiRange': hostApiRange,
    'dependencies': dependencies
        .map((dependency) => dependency.toJson())
        .toList(),
    'dataSchemaVersion': dataSchemaVersion,
    'platforms': platforms.map((platform) => platform.name).toList(),
    if (multiplayer != null) 'multiplayer': multiplayer!.toJson(),
    'resources': resources.map((resource) => resource.toJson()).toList(),
  };

  void validate() {
    if (!RegExp(r'^game\.[a-z0-9]+(?:[.-][a-z0-9]+)*$').hasMatch(moduleId)) {
      throw FormatException('Invalid game module ID: $moduleId');
    }
    if (displayName.trim().isEmpty || description.trim().isEmpty) {
      throw FormatException('A game module must have a name and description.');
    }
    if (manifestVersion != 1 || kind != 'game' || publisher.trim().isEmpty) {
      throw const FormatException('Invalid game manifest identity.');
    }
    if (!_isSemanticVersion(packageVersion) ||
        !_isSemanticVersion(minimumShellVersion) ||
        !_isVersionRange(hostApiRange)) {
      throw const FormatException('Module and shell versions must be SemVer.');
    }
    if (dataSchemaVersion < 1) {
      throw const FormatException('Data schema versions start at 1.');
    }
    _validatePlatforms(platforms, 'Module $moduleId');
    final dependencyIds = <String>{};
    for (final dependency in dependencies) {
      dependency.validate(moduleId);
      if (!dependencyIds.add('${dependency.kind.name}:${dependency.id}')) {
        throw FormatException('Duplicate dependency: ${dependency.id}');
      }
    }
    multiplayer?.validate();
    final resourceIds = <String>{};
    for (final resource in resources) {
      resource.validate(moduleId, modulePlatforms: platforms);
      if (!resourceIds.add(resource.resourceId)) {
        throw FormatException('Duplicate resource ID: ${resource.resourceId}');
      }
    }
  }
}

List<GamePlatform>? _parsePlatforms(Object? jsonValue) {
  if (jsonValue == null) return null;
  if (jsonValue is! List) {
    throw const FormatException('Platforms must be a list.');
  }
  return jsonValue
      .map((value) {
        if (value is! String) {
          throw const FormatException('Invalid platform ID.');
        }
        return GamePlatform.values.byName(value);
      })
      .toList(growable: false);
}

void _validatePlatforms(List<GamePlatform> platforms, String owner) {
  if (platforms.isEmpty) {
    throw FormatException('$owner must support at least one platform.');
  }
  if (platforms.toSet().length != platforms.length) {
    throw FormatException('$owner declares a duplicate platform.');
  }
}

class GameModuleCatalog {
  GameModuleCatalog(Iterable<GameModuleManifest> manifests)
    : manifests = List.unmodifiable(manifests) {
    final ids = <String>{};
    for (final manifest in this.manifests) {
      manifest.validate();
      if (!ids.add(manifest.moduleId)) {
        throw FormatException('Duplicate game module ID: ${manifest.moduleId}');
      }
    }
    _byId = Map.unmodifiable({
      for (final manifest in this.manifests) manifest.moduleId: manifest,
    });
  }

  final List<GameModuleManifest> manifests;
  late final Map<String, GameModuleManifest> _byId;

  GameModuleManifest? operator [](String moduleId) => _byId[moduleId];
}

class GameResourceInstallRecord {
  const GameResourceInstallRecord({
    required this.moduleId,
    required this.resourceId,
    required this.version,
    required this.sha256,
    required this.status,
    this.downloadedBytes = 0,
    this.totalBytes,
    this.payloadSchemaVersion,
  });

  final String moduleId;
  final String resourceId;
  final String version;
  final String sha256;
  final GameResourceInstallStatus status;
  final int downloadedBytes;
  final int? totalBytes;
  final int? payloadSchemaVersion;

  Map<String, Object?> toJson() => {
    'moduleId': moduleId,
    'resourceId': resourceId,
    'version': version,
    'sha256': sha256,
    'status': status.name,
    'downloadedBytes': downloadedBytes,
    'totalBytes': totalBytes,
    if (payloadSchemaVersion != null)
      'payloadSchemaVersion': payloadSchemaVersion,
  };

  factory GameResourceInstallRecord.fromJson(Map<String, Object?> json) {
    return GameResourceInstallRecord(
      moduleId: json['moduleId']! as String,
      resourceId: json['resourceId']! as String,
      version: json['version']! as String,
      sha256: json['sha256']! as String,
      status: GameResourceInstallStatus.values.byName(
        json['status']! as String,
      ),
      downloadedBytes: json['downloadedBytes'] as int? ?? 0,
      totalBytes: json['totalBytes'] as int?,
      payloadSchemaVersion: json['payloadSchemaVersion'] as int?,
    );
  }
}

final _semanticVersionPattern = RegExp(
  r'^(0|[1-9]\d*)\.(0|[1-9]\d*)\.(0|[1-9]\d*)(?:-((?:0|[1-9]\d*|[0-9A-Za-z-]*[A-Za-z-][0-9A-Za-z-]*)(?:\.(?:0|[1-9]\d*|[0-9A-Za-z-]*[A-Za-z-][0-9A-Za-z-]*))*))?(?:\+([0-9A-Za-z-]+(?:\.[0-9A-Za-z-]+)*))?$',
);

bool _isSemanticVersion(String value) =>
    _semanticVersionPattern.hasMatch(value);

bool _isVersionRange(String value) {
  final match = RegExp(
    r'^>=(0|[1-9]\d*)\.(0|[1-9]\d*)\.(0|[1-9]\d*) <(0|[1-9]\d*)\.(0|[1-9]\d*)\.(0|[1-9]\d*)$',
  ).firstMatch(value);
  if (match == null) return false;
  final minimum = [for (var i = 1; i <= 3; i++) match.group(i)!];
  final maximum = [for (var i = 4; i <= 6; i++) match.group(i)!];
  for (var i = 0; i < minimum.length; i++) {
    final comparison = _compareNumericIdentifiers(minimum[i], maximum[i]);
    if (comparison != 0) return comparison < 0;
  }
  return false;
}

bool _versionRangeAccepts(String range, String version) {
  final match = RegExp(
    r'^>=(\d+\.\d+\.\d+) <(\d+\.\d+\.\d+)$',
  ).firstMatch(range);
  return match != null &&
      _isSemanticVersion(version) &&
      _compareSemanticVersions(version, match.group(1)!) >= 0 &&
      _compareSemanticVersions(version, match.group(2)!) < 0;
}

int _compareSemanticVersions(String left, String right) {
  final leftVersion = _semanticVersionPattern.firstMatch(left);
  final rightVersion = _semanticVersionPattern.firstMatch(right);
  if (leftVersion == null || rightVersion == null) return -1;
  for (var index = 1; index <= 3; index++) {
    final comparison = _compareNumericIdentifiers(
      leftVersion.group(index)!,
      rightVersion.group(index)!,
    );
    if (comparison != 0) return comparison;
  }
  final leftPrerelease = leftVersion.group(4)?.split('.');
  final rightPrerelease = rightVersion.group(4)?.split('.');
  if (leftPrerelease == null || rightPrerelease == null) {
    if (leftPrerelease == null && rightPrerelease == null) return 0;
    return leftPrerelease == null ? 1 : -1;
  }
  final numericIdentifier = RegExp(r'^\d+$');
  for (var index = 0; index < leftPrerelease.length; index++) {
    if (index == rightPrerelease.length) return 1;
    final leftIdentifier = leftPrerelease[index];
    final rightIdentifier = rightPrerelease[index];
    final leftIsNumeric = numericIdentifier.hasMatch(leftIdentifier);
    final rightIsNumeric = numericIdentifier.hasMatch(rightIdentifier);
    if (leftIsNumeric && rightIsNumeric) {
      final comparison = _compareNumericIdentifiers(
        leftIdentifier,
        rightIdentifier,
      );
      if (comparison != 0) return comparison;
    } else if (leftIsNumeric != rightIsNumeric) {
      return leftIsNumeric ? -1 : 1;
    } else {
      final comparison = leftIdentifier.compareTo(rightIdentifier);
      if (comparison != 0) return comparison;
    }
  }
  return leftPrerelease.length.compareTo(rightPrerelease.length);
}

int _compareNumericIdentifiers(String left, String right) {
  if (left.length != right.length) return left.length.compareTo(right.length);
  return left.compareTo(right);
}
