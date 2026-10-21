const archeryGameModuleId = 'game.archery';
const archeryGameManifestVersion = 1;
const archeryGameKind = 'game';
const archeryGamePublisher = 'taiwan-brawl';
const archeryGamePackageVersion = '0.1.0';
const archeryGameMinimumShellVersion = '0.132.0';
const archeryGameHostApiRange = '>=1.0.0 <2.0.0';
const archeryGameDataSchemaVersion = 1;
const archeryRulesResourceId = 'game.archery.rules';
const archeryGameSupportedPlatforms = <String>[
  'web',
  'android',
  'ios',
  'windows',
  'macos',
  'linux',
];

/// Payload schemas implemented by this package. Publishing remains separate
/// from declaring which resource contracts this bundled game can consume.
const archeryGameSupportedResourceSchemas = <String, int>{
  archeryRulesResourceId: 1,
};

/// Versioned identity owned by the bundled Archery game package.
class ArcheryGameModuleManifest {
  const ArcheryGameModuleManifest({
    required this.moduleId,
    required this.packageVersion,
    required this.minimumShellVersion,
    required this.dataSchemaVersion,
    this.platforms = archeryGameSupportedPlatforms,
  });

  final String moduleId;
  final String packageVersion;
  final String minimumShellVersion;
  final int dataSchemaVersion;
  final List<String> platforms;

  Map<String, Object> toJson() => {
    'moduleId': moduleId,
    'manifestVersion': archeryGameManifestVersion,
    'kind': archeryGameKind,
    'publisher': archeryGamePublisher,
    'packageVersion': packageVersion,
    'minimumShellVersion': minimumShellVersion,
    'hostApiRange': archeryGameHostApiRange,
    'dependencies': const <Object>[],
    'dataSchemaVersion': dataSchemaVersion,
    'platforms': platforms,
    'resources': const <Object>[],
  };
}

const archeryGameManifest = ArcheryGameModuleManifest(
  moduleId: archeryGameModuleId,
  packageVersion: archeryGamePackageVersion,
  minimumShellVersion: archeryGameMinimumShellVersion,
  dataSchemaVersion: archeryGameDataSchemaVersion,
  platforms: archeryGameSupportedPlatforms,
);
