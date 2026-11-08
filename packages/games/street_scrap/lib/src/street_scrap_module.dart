import 'dart:convert';
import 'dart:typed_data';

const streetScrapModuleId = 'game.street-scrap';
const streetScrapDisplayName = '街角拾荒';
const streetScrapDescription = '在街區翻找材料、修補生活用品，完成街坊委託。';
const streetScrapManifestVersion = 1;
const streetScrapPublisher = 'taiwan-brawl';
const streetScrapPackageVersion = '0.1.14';
const streetScrapMinimumShellVersion = '0.132.0';
const streetScrapHostApiRange = '>=1.0.0 <2.0.0';
const streetScrapSaveSchemaVersion = 1;
const streetScrapSupportedPlatforms = <String>[
  'web',
  'android',
  'ios',
  'windows',
  'macos',
  'linux',
];
const streetScrapRulesetVersion = 1;
const streetScrapContentResourceId = 'game.street-scrap.content.chapters-0-4';
const streetScrapChapter5ResourceId = 'game.street-scrap.content.chapter-5';
const streetScrapArtResourceId = 'game.street-scrap.art.wood-board';
const streetScrapArtResourceVersion = '0.1.0';
const streetScrapArtSchemaVersion = 1;
const streetScrapArtSha256 =
    '0a8dc05c643d47f6784f894bbf6e882a1f8da5444a8e391ced055302ca0e405f';
const streetScrapThreadSpoolArtResourceId =
    'game.street-scrap.art.thread-spool';
const streetScrapThreadSpoolArtResourceVersion = '0.1.0';
const streetScrapThreadSpoolArtSchemaVersion = 1;
const streetScrapThreadSpoolArtSha256 =
    '5c81e071f97c8518151125a9d6a9a8c3b4cb8586ae64b47da19f2002644a8825';
const streetScrapMaterialAtlasResourceId =
    'game.street-scrap.art.material-atlas';
const streetScrapMaterialAtlasResourceVersion = '0.3.0';
const streetScrapMaterialAtlasSchemaVersion = 1;
const streetScrapMaterialAtlasSha256 =
    'bc7a803a0ba9a0369c1837483b29a33e645fb8f465920082cdb50dabd006b50a';
const streetScrapMineralPackArtResourceId =
    'game.street-scrap.art.mineral-pack';
const streetScrapMineralPackArtResourceVersion = '0.1.0';
const streetScrapMineralPackArtSchemaVersion = 1;
const streetScrapMineralPackArtSha256 =
    '4468edcedc428ae28e353e1e7022cce65b06874de11decf11676147b8a6695fc';
const streetScrapWoodChipBundleArtResourceId =
    'game.street-scrap.art.wood-chip-bundle';
const streetScrapWoodChipBundleArtResourceVersion = '0.1.0';
const streetScrapWoodChipBundleArtSchemaVersion = 1;
const streetScrapWoodChipBundleArtSha256 =
    '69c8709f942293983b576eef9f84b85406eb07465c9448354db9b7c433be6bce';
const streetScrapFishingSceneArtResourceId =
    'game.street-scrap.art.fishing-scene';
const streetScrapFishingSceneArtResourceVersion = '0.1.0';
const streetScrapFishingSceneArtSchemaVersion = 1;
const streetScrapFishingSceneArtSha256 =
    'a0930a892db15773fffef56f8f09c1388f9ec7793737586b27dcc556484744a8';
const streetScrapToolAtlasResourceId = 'game.street-scrap.art.tool-atlas';
const streetScrapToolAtlasResourceVersion = '0.1.0';
const streetScrapToolAtlasSchemaVersion = 1;
const streetScrapToolAtlasSha256 =
    '2325de988608437758a4e3217410ddbb390a1fdef9f9cdf3f699a8f1ec05126e';
const streetScrapMaterialPackArtResourceId =
    'game.street-scrap.art.material-pack';
const streetScrapMaterialPackArtResourceVersion = '0.1.0';
const streetScrapMaterialPackArtSchemaVersion = 1;
const streetScrapMaterialPackArtSha256 =
    'ab4919e0b063b25a67cd7148493faa0ab397e80547740dcfa8f2c2879a5dbad9';
const streetScrapProtagonistArtResourceId = 'game.street-scrap.art.protagonist';
const streetScrapProtagonistArtResourceVersion = '0.1.0';
const streetScrapProtagonistArtSchemaVersion = 1;
const streetScrapProtagonistArtSha256 =
    'b8a9de25849909cdac062683f0da1772a336068e5c38f14ec08b82f43415243f';
const streetScrapActiveContentVersionKey = 'game.street-scrap.content.active';
const streetScrapContentSchemaVersion = 1;
const streetScrapContentResourceVersion = '0.1.33';
const streetScrapContentSha256 =
    'f4907d6e9b2336f473aede567f31401494bff75d1adfb0e374a33b48bbe799b1';
const streetScrapSaveCompatibleBaseContentVersions = <String, Set<String>>{
  '0.1.33': {'0.1.32', '0.1.31'},
};
const streetScrapChapter5ContentResourceVersion = '0.1.24';
const streetScrapChapter5ContentSha256 =
    '902a4b991849375924710a3fd390d506f27250007ce2ddb2bbb0ed7aae1f46b3';

/// The game module is code shipped with the App. Chapter content is an
/// independently versioned optional resource and is deliberately not bundled
/// into the base Flutter asset set.
class StreetScrapGameManifest {
  const StreetScrapGameManifest({
    this.moduleId = streetScrapModuleId,
    this.packageVersion = streetScrapPackageVersion,
    this.minimumShellVersion = streetScrapMinimumShellVersion,
    this.hostApiRange = streetScrapHostApiRange,
    this.saveSchemaVersion = streetScrapSaveSchemaVersion,
    this.rulesetVersion = streetScrapRulesetVersion,
  });

  final String moduleId;
  final String packageVersion;
  final String minimumShellVersion;
  final String hostApiRange;
  final int saveSchemaVersion;
  final int rulesetVersion;

  Map<String, Object> toJson() => {
    'moduleId': moduleId,
    'manifestVersion': streetScrapManifestVersion,
    'kind': 'game',
    'publisher': streetScrapPublisher,
    'displayName': streetScrapDisplayName,
    'description': streetScrapDescription,
    'packageVersion': packageVersion,
    'minimumShellVersion': minimumShellVersion,
    'hostApiRange': hostApiRange,
    'dataSchemaVersion': saveSchemaVersion,
    'platforms': streetScrapSupportedPlatforms,
    'dependencies': const <Object>[],
    'resources': [
      {
        'resourceId': streetScrapContentResourceId,
        'version': streetScrapContentResourceVersion,
        'kind': 'gameplayData',
        'sha256': streetScrapContentSha256,
        'affectsGameplay': true,
        'payloadSchemaVersion': streetScrapContentSchemaVersion,
        'required': false,
        'dependencies': const <Object>[],
        'platforms': streetScrapSupportedPlatforms,
        'displayNameKey': 'resource.streetScrap.core.name',
        'descriptionKey': 'resource.streetScrap.core.description',
      },
      {
        'resourceId': streetScrapChapter5ResourceId,
        'version': streetScrapChapter5ContentResourceVersion,
        'kind': 'gameplayData',
        'sha256': streetScrapChapter5ContentSha256,
        'affectsGameplay': true,
        'payloadSchemaVersion': streetScrapContentSchemaVersion,
        'required': false,
        'dependencies': [
          {
            'kind': 'resource',
            'id': streetScrapContentResourceId,
            'versionRange': '>=0.1.0 <0.2.0',
            'optional': false,
          },
        ],
        'platforms': streetScrapSupportedPlatforms,
        'displayNameKey': 'resource.streetScrap.chapter5.name',
        'descriptionKey': 'resource.streetScrap.chapter5.description',
      },
      {
        'resourceId': streetScrapArtResourceId,
        'version': streetScrapArtResourceVersion,
        'kind': 'presentation',
        'sha256': streetScrapArtSha256,
        'affectsGameplay': false,
        'payloadSchemaVersion': streetScrapArtSchemaVersion,
        'required': false,
        'dependencies': const <Object>[],
        'platforms': streetScrapSupportedPlatforms,
        'displayNameKey': 'resource.streetScrap.woodBoard.name',
        'descriptionKey': 'resource.streetScrap.art.description',
      },
      {
        'resourceId': streetScrapThreadSpoolArtResourceId,
        'version': streetScrapThreadSpoolArtResourceVersion,
        'kind': 'presentation',
        'sha256': streetScrapThreadSpoolArtSha256,
        'affectsGameplay': false,
        'payloadSchemaVersion': streetScrapThreadSpoolArtSchemaVersion,
        'required': false,
        'dependencies': const <Object>[],
        'platforms': streetScrapSupportedPlatforms,
        'displayNameKey': 'resource.streetScrap.threadSpool.name',
        'descriptionKey': 'resource.streetScrap.art.description',
      },
      {
        'resourceId': streetScrapMaterialAtlasResourceId,
        'version': streetScrapMaterialAtlasResourceVersion,
        'kind': 'presentation',
        'sha256': streetScrapMaterialAtlasSha256,
        'affectsGameplay': false,
        'payloadSchemaVersion': streetScrapMaterialAtlasSchemaVersion,
        'required': false,
        'dependencies': const <Object>[],
        'platforms': streetScrapSupportedPlatforms,
        'displayNameKey': 'resource.streetScrap.materialAtlas.name',
        'descriptionKey': 'resource.streetScrap.art.description',
      },
      {
        'resourceId': streetScrapToolAtlasResourceId,
        'version': streetScrapToolAtlasResourceVersion,
        'kind': 'presentation',
        'sha256': streetScrapToolAtlasSha256,
        'affectsGameplay': false,
        'payloadSchemaVersion': streetScrapToolAtlasSchemaVersion,
        'required': false,
        'dependencies': const <Object>[],
        'platforms': streetScrapSupportedPlatforms,
        'displayNameKey': 'resource.streetScrap.toolAtlas.name',
        'descriptionKey': 'resource.streetScrap.art.description',
      },
      {
        'resourceId': streetScrapMaterialPackArtResourceId,
        'version': streetScrapMaterialPackArtResourceVersion,
        'kind': 'presentation',
        'sha256': streetScrapMaterialPackArtSha256,
        'affectsGameplay': false,
        'payloadSchemaVersion': streetScrapMaterialPackArtSchemaVersion,
        'required': false,
        'dependencies': const <Object>[],
        'platforms': streetScrapSupportedPlatforms,
        'displayNameKey': 'resource.streetScrap.materialPack.name',
        'descriptionKey': 'resource.streetScrap.art.description',
      },
      {
        'resourceId': streetScrapMineralPackArtResourceId,
        'version': streetScrapMineralPackArtResourceVersion,
        'kind': 'presentation',
        'sha256': streetScrapMineralPackArtSha256,
        'affectsGameplay': false,
        'payloadSchemaVersion': streetScrapMineralPackArtSchemaVersion,
        'required': false,
        'dependencies': const <Object>[],
        'platforms': streetScrapSupportedPlatforms,
        'displayNameKey': 'resource.streetScrap.mineralPack.name',
        'descriptionKey': 'resource.streetScrap.art.description',
      },
      {
        'resourceId': streetScrapWoodChipBundleArtResourceId,
        'version': streetScrapWoodChipBundleArtResourceVersion,
        'kind': 'presentation',
        'sha256': streetScrapWoodChipBundleArtSha256,
        'affectsGameplay': false,
        'payloadSchemaVersion': streetScrapWoodChipBundleArtSchemaVersion,
        'required': false,
        'dependencies': const <Object>[],
        'platforms': streetScrapSupportedPlatforms,
        'displayNameKey': 'resource.streetScrap.woodChipBundle.name',
        'descriptionKey': 'resource.streetScrap.art.description',
      },
      {
        'resourceId': streetScrapFishingSceneArtResourceId,
        'version': streetScrapFishingSceneArtResourceVersion,
        'kind': 'presentation',
        'sha256': streetScrapFishingSceneArtSha256,
        'affectsGameplay': false,
        'payloadSchemaVersion': streetScrapFishingSceneArtSchemaVersion,
        'required': false,
        'dependencies': const <Object>[],
        'platforms': streetScrapSupportedPlatforms,
        'displayNameKey': 'resource.streetScrap.fishingScene.name',
        'descriptionKey': 'resource.streetScrap.art.description',
      },
      {
        'resourceId': streetScrapProtagonistArtResourceId,
        'version': streetScrapProtagonistArtResourceVersion,
        'kind': 'presentation',
        'sha256': streetScrapProtagonistArtSha256,
        'affectsGameplay': false,
        'payloadSchemaVersion': streetScrapProtagonistArtSchemaVersion,
        'required': false,
        'dependencies': const <Object>[],
        'platforms': streetScrapSupportedPlatforms,
        'displayNameKey': 'resource.streetScrap.protagonist.name',
        'descriptionKey': 'resource.streetScrap.art.description',
      },
    ],
    'supportedResourceSchemas': {
      streetScrapContentResourceId: streetScrapContentSchemaVersion,
      streetScrapChapter5ResourceId: streetScrapContentSchemaVersion,
      streetScrapArtResourceId: streetScrapArtSchemaVersion,
      streetScrapThreadSpoolArtResourceId:
          streetScrapThreadSpoolArtSchemaVersion,
      streetScrapMaterialAtlasResourceId: streetScrapMaterialAtlasSchemaVersion,
      streetScrapToolAtlasResourceId: streetScrapToolAtlasSchemaVersion,
      streetScrapMaterialPackArtResourceId:
          streetScrapMaterialPackArtSchemaVersion,
      streetScrapMineralPackArtResourceId:
          streetScrapMineralPackArtSchemaVersion,
      streetScrapWoodChipBundleArtResourceId:
          streetScrapWoodChipBundleArtSchemaVersion,
      streetScrapFishingSceneArtResourceId:
          streetScrapFishingSceneArtSchemaVersion,
      streetScrapProtagonistArtResourceId:
          streetScrapProtagonistArtSchemaVersion,
    },
    'saveSchemaVersion': saveSchemaVersion,
    'rulesetVersion': rulesetVersion,
    'optionalContentResourceId': streetScrapContentResourceId,
    'optionalContentSchemaVersion': streetScrapContentSchemaVersion,
    'optionalArtResourceId': streetScrapArtResourceId,
    'optionalArtResourceIds': [
      streetScrapArtResourceId,
      streetScrapThreadSpoolArtResourceId,
      streetScrapMaterialAtlasResourceId,
      streetScrapMineralPackArtResourceId,
      streetScrapWoodChipBundleArtResourceId,
      streetScrapToolAtlasResourceId,
      streetScrapMaterialPackArtResourceId,
      streetScrapFishingSceneArtResourceId,
      streetScrapProtagonistArtResourceId,
    ],
    'artRevision': streetScrapArtResourceVersion,
    'materialAtlasRevision': streetScrapMaterialAtlasResourceVersion,
  };
}

int _orderRequirementQuantity(Object? rawGroup) {
  if (rawGroup is! List) return -1;
  var total = 0;
  for (final rawEntry in rawGroup) {
    if (rawEntry is! Map || rawEntry['quantity'] is! int) return -1;
    total += rawEntry['quantity'] as int;
  }
  return total;
}

/// Checks a downloaded content payload before the host activates it.
/// Semantic checks intentionally fail closed while complete gameplay and save
/// migration implementations are still being built.
void validateStreetScrapContentPayload(String source) {
  final decoded = jsonDecode(source);
  if (decoded is! Map<String, dynamic>) {
    throw const FormatException('Street Scrap content must be a JSON object.');
  }
  final scope = decoded['contentScope'] ?? 'aggregate';
  final expectedCounts = switch (scope) {
    'base' => (items: 98, recipes: 67, packing: 7),
    'aggregate' => (items: 111, recipes: 78, packing: 8),
    _ => null,
  };
  if (decoded['schemaVersion'] != streetScrapContentSchemaVersion ||
      decoded['gameId'] != streetScrapModuleId ||
      decoded['packId'] != streetScrapContentResourceId ||
      decoded['rulesetVersion'] != streetScrapRulesetVersion ||
      decoded['saveSchemaVersion'] != streetScrapSaveSchemaVersion ||
      decoded['optionalResource'] != true) {
    throw const FormatException(
      'Unsupported Street Scrap content identity or version.',
    );
  }
  final items = decoded['itemDefinitions'];
  final recipes = decoded['recipes'];
  final packing = decoded['packing'];
  final toolRepairs = decoded['toolRepairs'];
  final renewableSupplies = decoded['renewableSupplies'];
  if (expectedCounts == null ||
      items is! List ||
      recipes is! List ||
      packing is! List ||
      toolRepairs is! List ||
      renewableSupplies is! List ||
      items.length != expectedCounts.items ||
      recipes.length != expectedCounts.recipes ||
      packing.length != expectedCounts.packing ||
      (scope == 'base' &&
          [...items, ...recipes].any(
            (entry) =>
                entry is! Map || entry['phase'] is! int || entry['phase'] > 4,
          ))) {
    throw const FormatException('Street Scrap content is incomplete.');
  }
  final ids = <String>{};
  final gridIds = <String>{};
  final durableIds = <String>{};
  final phases = <String, int>{};
  for (final value in items) {
    if (value is! Map ||
        value['id'] is! String ||
        !ids.add(value['id'] as String)) {
      throw const FormatException('Street Scrap item IDs must be unique.');
    }
    final id = value['id'] as String;
    if (value['phase'] is! int ||
        (value['phase'] as int) < 0 ||
        (value['phase'] as int) > 5) {
      throw const FormatException('Street Scrap item phase is invalid.');
    }
    phases[id] = value['phase'] as int;
    if (value['location'] == 'grid' && value['footprint'] is List) {
      gridIds.add(id);
    }
    if (value['baseDurability'] is int &&
        (value['baseDurability'] as int) > 0) {
      durableIds.add(id);
    }
  }
  final renewableSupplyIds = <String>{};
  for (final source in renewableSupplies) {
    if (source is! Map ||
        source['item'] is! String ||
        !renewableSupplyIds.add(source['item'] as String) ||
        phases[source['item']] == null ||
        source['phase'] is! int ||
        (source['phase'] as int) < phases[source['item']]! ||
        (source['phase'] as int) > 5 ||
        (scope == 'base' && (source['phase'] as int) > 4) ||
        source['quantity'] is! int ||
        (source['quantity'] as int) < 1 ||
        source['stamina'] is! int ||
        (source['stamina'] as int) < 1 ||
        source['repeatable'] != true ||
        (gridIds.contains(source['item']) ==
            (source['item'] as String).startsWith('water.'))) {
      throw const FormatException(
        'Street Scrap renewable supplies are invalid.',
      );
    }
  }
  final repairIds = <String>{};
  for (final rule in toolRepairs) {
    if (rule is! Map ||
        rule['id'] is! String ||
        !repairIds.add(rule['id'] as String) ||
        rule['tool'] is! String ||
        !durableIds.contains(rule['tool']) ||
        rule['phase'] is! int ||
        (rule['phase'] as int) < 0 ||
        (rule['phase'] as int) > 5 ||
        phases[rule['tool']] == null ||
        phases[rule['tool']]! > (rule['phase'] as int) ||
        (scope == 'base' && (rule['phase'] as int) > 4) ||
        rule['restoreUses'] is! int ||
        (rule['restoreUses'] as int) < 1 ||
        rule['materialOptions'] is! List ||
        (rule['materialOptions'] as List).isEmpty) {
      throw const FormatException(
        'Street Scrap tool repair rules are invalid.',
      );
    }
    final options = rule['materialOptions'] as List;
    if (options.any(
      (option) =>
          option is! List ||
          option.isEmpty ||
          option.any((rawId) {
            if (rawId is! String) return true;
            final isContent = rawId.startsWith('content:');
            final id = isContent ? rawId.substring('content:'.length) : rawId;
            return phases[id] == null ||
                phases[id]! > (rule['phase'] as int) ||
                (isContent
                    ? !ids.contains(id) || gridIds.contains(id)
                    : !gridIds.contains(id));
          }) ||
          option.toSet().length != option.length,
    )) {
      throw const FormatException('Street Scrap repair materials are invalid.');
    }
  }
  final recipeIds = <String>{};
  for (final value in recipes) {
    if (value is! Map ||
        value['id'] is! String ||
        !recipeIds.add(value['id'] as String)) {
      throw const FormatException('Street Scrap recipe IDs must be unique.');
    }
    final station = value['station'];
    final operation = value['operation'];
    final inputGroups = value['inputGroups'];
    final outputs = value['outputs'];
    final failure = value['failure'];
    if (station is! String ||
        operation is! Map ||
        operation['id'] is! String ||
        operation['instructions'] is! String ||
        inputGroups is! List ||
        outputs is! List ||
        failure is! Map ||
        failure['outcome'] is! String ||
        !{
          'explicitOutcome',
          'reducedQualityOutput',
          'noPenalty',
        }.contains(failure['mode'])) {
      throw const FormatException(
        'Street Scrap recipe is missing an operation or failure outcome.',
      );
    }
    final checkpoints = operation['manualCheckpoints'];
    if (checkpoints != null &&
        (checkpoints is! List ||
            (checkpoints.isNotEmpty && checkpoints.length != 3) ||
            checkpoints.any(
              (checkpoint) =>
                  checkpoint is! Map ||
                  checkpoint['prompt'] is! String ||
                  (checkpoint['prompt'] as String).trim().isEmpty ||
                  checkpoint['options'] is! List ||
                  (checkpoint['options'] as List).length < 2 ||
                  (checkpoint['options'] as List).any(
                    (option) => option is! String || option.trim().isEmpty,
                  ) ||
                  checkpoint['correctOption'] is! int ||
                  checkpoint['correctOption'] < 0 ||
                  checkpoint['correctOption'] >=
                      (checkpoint['options'] as List).length,
            ))) {
      throw const FormatException(
        'Street Scrap manual checkpoints are invalid.',
      );
    }
    final failureResolution = value['failureResolution'];
    if (failureResolution != null &&
        (failureResolution is! Map ||
            failureResolution['mode'] != 'sameOutputsQualityLoss' ||
            failureResolution['qualityLoss'] is! int ||
            failureResolution['qualityLoss'] < 0 ||
            failureResolution['qualityLoss'] > 100 ||
            failureResolution['consumeSelectedInputs'] != true)) {
      throw const FormatException(
        'Street Scrap failure resolution is invalid.',
      );
    }
    final stateEffect = value['stateEffect'];
    if (stateEffect != null) {
      if (stateEffect is! Map ||
          (outputs.isNotEmpty &&
              stateEffect['type'] != 'transformContainers')) {
        throw const FormatException(
          'Street Scrap recipe state effect is invalid.',
        );
      }
      final backpackEffect =
          stateEffect['type'] == 'upgradeBackpack' &&
          stateEffect['fromItemId'] == 'bag.basic' &&
          stateEffect['toItemId'] == 'bag.reinforced' &&
          stateEffect['capacity'] == 24;
      final containerEffect =
          stateEffect['type'] == 'transformContainerContent' &&
          gridIds.contains(stateEffect['containerItemId']) &&
          ids.contains(stateEffect['fromContentItemId']) &&
          ids.contains(stateEffect['toContentItemId']) &&
          inputGroups.any(
            (group) =>
                group is List &&
                group.any(
                  (input) =>
                      input is Map &&
                      input['item'] == stateEffect['containerItemId'],
                ),
          );
      final rawContainerTransforms = stateEffect['containers'];
      final multipleContainerEffect =
          stateEffect['type'] == 'transformContainers' &&
          rawContainerTransforms is List &&
          rawContainerTransforms.isNotEmpty &&
          rawContainerTransforms.every(
            (entry) =>
                entry is Map &&
                (entry['optional'] == null || entry['optional'] is bool) &&
                gridIds.contains(entry['containerItemId']) &&
                (entry['requiredContentItemId'] == null ||
                    ids.contains(entry['requiredContentItemId'])) &&
                (entry['successContentItemId'] == null ||
                    ids.contains(entry['successContentItemId'])) &&
                (entry['failureContentItemId'] == null ||
                    ids.contains(entry['failureContentItemId'])) &&
                inputGroups.any(
                  (group) =>
                      group is List &&
                      group.any(
                        (input) =>
                            input is Map &&
                            (input['item'] == entry['containerItemId'] ||
                                (entry['optional'] == true &&
                                    entry['requiredContentItemId'] is String &&
                                    input['item'] ==
                                        entry['requiredContentItemId'])),
                      ),
                ),
          );
      final identityTransform =
          stateEffect['type'] == 'transformObject' &&
          ids.contains(stateEffect['fromItemId']) &&
          ids.contains(stateEffect['toItemId']) &&
          stateEffect['requireEmptyContainer'] == true &&
          (stateEffect['applyOnFailure'] == null ||
              stateEffect['applyOnFailure'] is bool) &&
          (stateEffect['clearContainerState'] == null ||
              stateEffect['clearContainerState'] is bool) &&
          (stateEffect['targetContainerState'] == null ||
              stateEffect['targetContainerState'] is Map) &&
          inputGroups.any(
            (group) =>
                group is List &&
                group.any(
                  (input) =>
                      input is Map &&
                      input['item'] == stateEffect['fromItemId'],
                ),
          );
      final retainedPack =
          stateEffect['type'] == 'packObjects' &&
          stateEffect['retainedInputIds'] is List &&
          (stateEffect['retainedInputIds'] as List).isNotEmpty &&
          (stateEffect['retainedInputIds'] as List).every(
            (id) => ids.contains(id),
          ) &&
          (value['identity'] as Map)['retainedInputIds'] is List &&
          _sameStringMultiset(
            (stateEffect['retainedInputIds'] as List).cast<String>(),
            ((value['identity'] as Map)['retainedInputIds'] as List)
                .cast<String>(),
          ) &&
          ids.contains(stateEffect['toItemId']) &&
          (stateEffect['requireEmptyContainerItems'] == null ||
              (stateEffect['requireEmptyContainerItems'] is List &&
                  (stateEffect['requireEmptyContainerItems'] as List).every(
                    (id) =>
                        (stateEffect['retainedInputIds'] as List).contains(id),
                  ))) &&
          stateEffect['packingRuleId'] is String &&
          packing.any(
            (rule) =>
                rule is Map &&
                rule['input'] == stateEffect['packingRuleId'] &&
                rule['output'] == stateEffect['toItemId'] &&
                rule['count'] ==
                    (stateEffect['retainedInputIds'] as List).length &&
                _sameStringMultiset(
                  (rule['inputItems'] as List? ??
                          List.filled(rule['count'] as int, rule['input']))
                      .cast<String>(),
                  (stateEffect['retainedInputIds'] as List).cast<String>(),
                ),
          ) &&
          inputGroups.any(
            (group) =>
                group is List &&
                (stateEffect['retainedInputIds'] as List).every(
                  (id) =>
                      group.any((input) => input is Map && input['item'] == id),
                ),
          );
      if (!backpackEffect &&
          !containerEffect &&
          !multipleContainerEffect &&
          !identityTransform &&
          !retainedPack) {
        throw const FormatException(
          'Street Scrap recipe state effect is invalid.',
        );
      }
    }
    for (final group in inputGroups) {
      if (group is! List || group.isEmpty) {
        throw const FormatException('Invalid recipe input group.');
      }
      for (final input in group) {
        if (input is! Map ||
            !ids.contains(input['item']) ||
            input['quantity'] is! int ||
            input['quantity'] < 1) {
          throw const FormatException(
            'Recipe input references an unknown item or quantity.',
          );
        }
      }
    }
    for (final output in outputs) {
      if (output is! Map ||
          !ids.contains(output['item']) ||
          output['quantity'] is! int ||
          output['quantity'] < 1) {
        throw const FormatException(
          'Recipe output references an unknown item or quantity.',
        );
      }
    }
    final failureOutputs = value['failureOutputs'];
    if (failureOutputs != null &&
        (failureOutputs is! List ||
            failureOutputs.isEmpty ||
            failureOutputs.any(
              (output) =>
                  output is! Map ||
                  !ids.contains(output['item']) ||
                  output['quantity'] is! int ||
                  output['quantity'] < 1,
            ))) {
      throw const FormatException('Street Scrap failure outputs are invalid.');
    }
  }

  for (final rule in packing) {
    if (rule is! Map ||
        !ids.contains(rule['input']) ||
        !ids.contains(rule['output']) ||
        rule['count'] is! int ||
        rule['count'] < 1 ||
        rule['manualUnpack'] != true ||
        (rule['inputItems'] != null &&
            (rule['inputItems'] is! List ||
                (rule['inputItems'] as List).length != rule['count'] ||
                (rule['inputItems'] as List).any((id) => !ids.contains(id))))) {
      throw const FormatException('Street Scrap packing rule is invalid.');
    }
  }

  final scavenging = decoded['scavenging'];
  final limits = decoded['limits'];
  if (scavenging is! Map ||
      limits is! Map ||
      scavenging['version'] != 4 ||
      scavenging['nodeCount'] != 3 ||
      scavenging['investigationsPerNode'] != 1 ||
      scavenging['movementCost'] is! int ||
      scavenging['movementCost'] < 0 ||
      scavenging['investigationCost'] is! int ||
      scavenging['investigationCost'] < 1 ||
      scavenging['fixedWrongQuantity'] is! int ||
      scavenging['fixedWrongQuantity'] < 1 ||
      limits['staminaMax'] is! int ||
      limits['staminaMax'] < 1) {
    throw const FormatException('Street Scrap scavenging rules are invalid.');
  }
  final weights = scavenging['surpriseWeights'];
  final pools = scavenging['surprisePools'];
  final phasePools = scavenging['phaseSurprisePools'];
  final locations = scavenging['fixedLocations'];
  final scrapQualities = scavenging['scrapQualities'];
  final intactQualities = scavenging['intactQualities'];
  const expectedSurpriseWeights = {
    'commonScraps': 50,
    'intactBase': 25,
    'containers': 15,
    'optionalSpecial': 10,
  };
  if (weights is! Map ||
      pools is! Map ||
      phasePools is! Map ||
      locations is! List ||
      locations.length < 3 ||
      scrapQualities is! List ||
      scrapQualities.isEmpty ||
      intactQualities is! List ||
      intactQualities.isEmpty ||
      weights.length != expectedSurpriseWeights.length ||
      expectedSurpriseWeights.entries.any(
        (entry) => weights[entry.key] != entry.value,
      ) ||
      weights.values.any((value) => value is! int || value < 0) ||
      weights.values.fold<int>(0, (sum, value) => sum + (value as int)) !=
          100 ||
      weights.keys.toSet().difference(pools.keys.toSet()).isNotEmpty ||
      pools.keys.toSet().difference(weights.keys.toSet()).isNotEmpty ||
      [
        ...scrapQualities,
        ...intactQualities,
      ].any((value) => value is! int || value < 0 || value > 100)) {
    throw const FormatException(
      'Street Scrap scavenging tables are malformed.',
    );
  }
  for (final entry in pools.entries) {
    final pool = entry.value;
    if (pool is! List ||
        (entry.key != 'optionalSpecial' && pool.isEmpty) ||
        pool.any(
          (id) =>
              id is! String ||
              (!gridIds.contains(id) &&
                  !(entry.key == 'optionalSpecial' && id == 'water.mineral')),
        )) {
      throw const FormatException(
        'Street Scrap surprise pool references invalid items.',
      );
    }
  }
  if (phasePools.length != 6 ||
      List<int>.generate(
        6,
        (index) => index,
      ).any((phase) => !phasePools.containsKey('$phase'))) {
    throw const FormatException(
      'Street Scrap phase surprise pools are malformed.',
    );
  }
  for (final phaseEntry in phasePools.entries) {
    final phase = int.tryParse(phaseEntry.key.toString());
    final scopedPools = phaseEntry.value;
    if (phase == null ||
        phase < 0 ||
        phase > 5 ||
        scopedPools is! Map ||
        scopedPools.keys
            .toSet()
            .difference(expectedSurpriseWeights.keys.toSet())
            .isNotEmpty ||
        expectedSurpriseWeights.keys
            .toSet()
            .difference(scopedPools.keys.toSet())
            .isNotEmpty) {
      throw const FormatException(
        'Street Scrap phase surprise pools are malformed.',
      );
    }
    for (final poolEntry in scopedPools.entries) {
      final pool = poolEntry.value;
      if (pool is! List ||
          (poolEntry.key != 'optionalSpecial' && pool.isEmpty) ||
          pool.any(
            (id) =>
                id is! String ||
                (!gridIds.contains(id) &&
                    !(poolEntry.key == 'optionalSpecial' &&
                        id == 'water.mineral')) ||
                phases[id] == null ||
                phases[id]! > phase,
          )) {
        throw const FormatException(
          'Street Scrap phase surprise pool references invalid items.',
        );
      }
    }
  }
  final phaseNodePairs = <String>{};
  for (final location in locations) {
    if (location is! Map ||
        location['id'] is! String ||
        location['nodeIndex'] is! int ||
        location['nodeIndex'] < 0 ||
        location['nodeIndex'] >= 3 ||
        location['phase'] is! int ||
        location['phase'] < 0 ||
        location['phase'] > 5 ||
        location['options'] is! List ||
        (location['options'] as List).isEmpty) {
      throw const FormatException('Street Scrap fixed location is malformed.');
    }
    final phaseNode = '${location['phase']}:${location['nodeIndex']}';
    if (!phaseNodePairs.add(phaseNode)) {
      throw const FormatException(
        'Street Scrap fixed locations duplicate a phase and node.',
      );
    }
    for (final option in location['options'] as List) {
      if (option is! Map ||
          !gridIds.contains(option['item']) ||
          option['label'] is! String ||
          (option['label'] as String).trim().isEmpty ||
          option['quantity'] is! int ||
          option['quantity'] < 1 ||
          !{'scrap', 'intact'}.contains(option['qualityType'] ?? 'scrap') ||
          phases[option['item']]! > (location['phase'] as int)) {
        throw const FormatException('Street Scrap fixed source is invalid.');
      }
    }
  }
  for (var node = 0; node < 3; node++) {
    if (!phaseNodePairs.contains('0:$node')) {
      throw const FormatException(
        'Street Scrap fixed route is missing a phase-zero node.',
      );
    }
  }
  final fishing = decoded['fishing'];
  if (fishing is! Map ||
      fishing['version'] != 1 ||
      fishing['castCost'] != 3 ||
      fishing['signalsPerCast'] != 3 ||
      fishing['successSignals'] != 2 ||
      fishing['perfectSignals'] != 3 ||
      fishing['guaranteeAfterFailures'] != 2 ||
      fishing['signalHoldMilliseconds'] != 2000 ||
      fishing['basePromptWidthPercent'] != 30 ||
      fishing['preciseQualityBonus'] != 8 ||
      fishing['freeNaturalBait'] != true ||
      fishing['loanerRodAvailable'] != true ||
      fishing['spots'] is! List ||
      fishing['failureRewards'] is! List ||
      (fishing['failureRewards'] as List).length != 2 ||
      (fishing['failureRewards'] as List).any(
        (id) => id is! String || !gridIds.contains(id),
      )) {
    throw const FormatException('Street Scrap fishing rules are invalid.');
  }
  final spots = fishing['spots'] as List;
  if (spots.isEmpty ||
      spots.any(
        (spot) =>
            spot is! Map ||
            spot['id'] is! String ||
            spot['phase'] is! int ||
            spot['name'] is! String ||
            spot['phase'] < 2 ||
            spot['phase'] > 5 ||
            (spot['failureRewards'] != null &&
                (spot['failureRewards'] is! List ||
                    (spot['failureRewards'] as List).length != 2 ||
                    (spot['failureRewards'] as List).toSet().length != 2 ||
                    (spot['failureRewards'] as List).any(
                      (id) => id is! String || !gridIds.contains(id),
                    ))),
      ) ||
      !spots.any(
        (spot) =>
            spot is Map && spot['id'] == 'dock_entrance' && spot['phase'] == 2,
      ) ||
      !spots.any(
        (spot) =>
            spot is Map &&
            spot['id'] == 'raft_point' &&
            spot['phase'] == 3 &&
            spot['failureRewards'] is List &&
            (spot['failureRewards'] as List).toSet().containsAll(const {
              'fish.bone',
              'wood.driftwood',
            }) &&
            (spot['failureRewards'] as List).length == 2,
      )) {
    throw const FormatException('Street Scrap fishing spots are malformed.');
  }
  final rawOrders = decoded['orders'] ?? const [];
  if (rawOrders is! List) {
    throw const FormatException('Street Scrap orders must be a list.');
  }
  final orderIds = <String>{};
  for (final order in rawOrders) {
    if (order is! Map ||
        order['id'] is! String ||
        (order['id'] as String).trim().isEmpty ||
        !orderIds.add(order['id'] as String) ||
        order['phase'] is! int ||
        order['phase'] < 0 ||
        order['phase'] > 5 ||
        order['acceptedItems'] is! List ||
        (order['acceptedItems'] as List).any(
          (id) => id is! String || !ids.contains(id),
        ) ||
        (order['requirementGroups'] != null &&
            (order['requirementGroups'] is! List ||
                (order['requirementGroups'] as List).isEmpty ||
                (order['requirementGroups'] as List).any(
                  (group) =>
                      group is! List ||
                      group.isEmpty ||
                      group.any(
                        (entry) =>
                            entry is! Map ||
                            !ids.contains(entry['item']) ||
                            !(order['acceptedItems'] as List).contains(
                              entry['item'],
                            ) ||
                            entry['quantity'] is! int ||
                            entry['quantity'] < 1,
                      ),
                ))) ||
        ((order['acceptedItems'] as List).isEmpty &&
            order['requirementGroups'] == null) ||
        ((order['rejectedItems'] ?? const []) is! List) ||
        ((order['rejectedItems'] ?? const []) as List).any(
          (id) => id is! String || !ids.contains(id),
        ) ||
        (order['quantity'] != null &&
            (order['quantity'] is! int || order['quantity'] < 1)) ||
        order['reward'] is! Map ||
        (order['reward'] as Map)['currency'] != 'exchangeTickets' ||
        (order['reward'] as Map)['quantity'] is! int ||
        (order['reward'] as Map)['quantity'] < 1 ||
        order['countsTowardCycle'] is! bool ||
        (order['returnContainer'] != null &&
            order['returnContainer'] is! bool) ||
        (order['consumeContainer'] != null &&
            order['consumeContainer'] is! bool) ||
        (order['containerItemId'] != null &&
            (order['containerItemId'] is! String ||
                !ids.contains(order['containerItemId']))) ||
        (order['returnContainer'] == true &&
            order['consumeContainer'] == true) ||
        (order['consumeContainer'] == true &&
            order['containerItemId'] == null) ||
        (order['containerItemId'] != null &&
            order['returnContainer'] != true &&
            order['consumeContainer'] != true) ||
        (order['returnContainer'] == true &&
            order['returnedContainerCleanliness'] != 'soiled') ||
        (order['returnContainer'] != true &&
            order['returnedContainerCleanliness'] != null) ||
        (order['returnContainer'] == true &&
            order['requirementGroups'] is List &&
            (order['requirementGroups'] as List).any(
              (group) =>
                  _orderRequirementQuantity(group) != (order['quantity'] ?? 1),
            )) ||
        (order['oncePerTutorial'] != null &&
            (order['oncePerTutorial'] is! String ||
                (order['oncePerTutorial'] as String).trim().isEmpty)) ||
        (order['completionGroupId'] != null &&
            (order['completionGroupId'] is! String ||
                (order['completionGroupId'] as String).trim().isEmpty)) ||
        (order['requiresAcceptance'] != null &&
            order['requiresAcceptance'] is! bool) ||
        (order['requiredSource'] != null &&
            (order['requiredSource'] is! String ||
                (order['requiredSource'] as String).trim().isEmpty)) ||
        (order['requiredRecipes'] != null &&
            (order['requiredRecipes'] is! List ||
                (order['requiredRecipes'] as List).isEmpty ||
                (order['requiredRecipes'] as List).any(
                  (recipe) => recipe is! String || !recipeIds.contains(recipe),
                ))) ||
        ((order['requiredSource'] != null ||
                order['requiredRecipes'] != null) &&
            order['requiresAcceptance'] != true) ||
        (order['requiresTutorial'] != null &&
            (order['requiresTutorial'] is! String ||
                (order['requiresTutorial'] as String).trim().isEmpty))) {
      throw const FormatException('Street Scrap order definition is invalid.');
    }
    final accepted = (order['acceptedItems'] as List).toSet();
    final rejected = ((order['rejectedItems'] ?? const []) as List).toSet();
    if (accepted.length != (order['acceptedItems'] as List).length ||
        rejected.length !=
            ((order['rejectedItems'] ?? const []) as List).length ||
        accepted.intersection(rejected).isNotEmpty) {
      throw const FormatException('Street Scrap order item lists conflict.');
    }
  }
}

bool _sameStringMultiset(List<String> a, List<String> b) {
  if (a.length != b.length) return false;
  final counts = <String, int>{};
  for (final value in a) {
    counts.update(value, (count) => count + 1, ifAbsent: () => 1);
  }
  for (final value in b) {
    final count = counts[value];
    if (count == null) return false;
    if (count == 1) {
      counts.remove(value);
    } else {
      counts[value] = count - 1;
    }
  }
  return counts.isEmpty;
}

void validateStreetScrapChapter5ContentPayload(String source) {
  final decoded = jsonDecode(source);
  final scavenging = decoded is Map ? decoded['scavenging'] : null;
  final phasePools = scavenging is Map
      ? scavenging['phaseSurprisePools']
      : null;
  final chapterItemIds = decoded is Map && decoded['itemDefinitions'] is List
      ? (decoded['itemDefinitions'] as List)
            .whereType<Map>()
            .map((item) => item['id'])
            .whereType<String>()
            .toSet()
      : <String>{};
  const phasePoolCategories = {
    'commonScraps',
    'intactBase',
    'containers',
    'optionalSpecial',
  };
  if (decoded is! Map<String, dynamic> ||
      decoded['schemaVersion'] != streetScrapContentSchemaVersion ||
      decoded['gameId'] != streetScrapModuleId ||
      decoded['packId'] != streetScrapChapter5ResourceId ||
      decoded['contentScope'] != 'chapter5' ||
      decoded['rulesetVersion'] != streetScrapRulesetVersion ||
      decoded['saveSchemaVersion'] != streetScrapSaveSchemaVersion ||
      decoded['optionalResource'] != true ||
      decoded['itemDefinitions'] is! List ||
      (decoded['itemDefinitions'] as List).length != 13 ||
      (decoded['itemDefinitions'] as List).any(
        (item) => item is! Map || item['phase'] != 5,
      ) ||
      decoded['recipes'] is! List ||
      (decoded['recipes'] as List).length != 11 ||
      (decoded['recipes'] as List).any(
        (recipe) => recipe is! Map || recipe['phase'] != 5,
      ) ||
      decoded['orders'] is! List ||
      (decoded['orders'] as List).length != 5 ||
      (decoded['orders'] as List).any(
        (order) => order is! Map || order['phase'] != 5,
      ) ||
      decoded['toolRepairs'] is! List ||
      (decoded['toolRepairs'] as List).any(
        (rule) => rule is! Map || rule['phase'] != 5,
      ) ||
      decoded['packing'] is! List ||
      (decoded['packing'] as List).length != 1 ||
      (decoded['packing'] as List).any(
        (rule) =>
            rule is! Map ||
            rule['input'] != 'tool.pot' ||
            rule['output'] != 'tool.cook_kit' ||
            rule['count'] != 2 ||
            rule['manualUnpack'] != true ||
            rule['inputItems'] is! List ||
            !_sameStringMultiset(
              (rule['inputItems'] as List).cast<String>(),
              const ['tool.pot', 'tool.stove'],
            ),
      ) ||
      scavenging is! Map ||
      scavenging['version'] != 4 ||
      phasePools is! Map ||
      phasePools.length != 6 ||
      List<int>.generate(
        6,
        (index) => index,
      ).any((phase) => !phasePools.containsKey('$phase')) ||
      phasePools.values.any(
        (rawPools) =>
            rawPools is! Map ||
            phasePoolCategories.difference(rawPools.keys.toSet()).isNotEmpty ||
            rawPools.keys.toSet().difference(phasePoolCategories).isNotEmpty ||
            rawPools.values.any(
              (rawItems) =>
                  rawItems is! List ||
                  rawItems.any((id) => !chapterItemIds.contains(id)),
            ),
      )) {
    throw const FormatException('Street Scrap chapter 5 content is invalid.');
  }
}

String mergeStreetScrapContentPayloads({
  required String base,
  String? chapter5,
}) {
  validateStreetScrapContentPayload(base);
  final merged = Map<String, dynamic>.from(jsonDecode(base) as Map);
  if (chapter5 != null) {
    validateStreetScrapChapter5ContentPayload(chapter5);
    final extension = Map<String, dynamic>.from(jsonDecode(chapter5) as Map);
    for (final key in [
      'itemDefinitions',
      'recipes',
      'toolRepairs',
      'renewableSupplies',
      'tutorialSeeds',
      'orders',
      'packing',
    ]) {
      merged[key] = [...(merged[key] as List), ...(extension[key] as List)];
    }
    for (final key in ['scavenging', 'fishing']) {
      final baseValue = Map<String, dynamic>.from(merged[key] as Map);
      final extensionValue = Map<String, dynamic>.from(extension[key] as Map);
      for (final table
          in key == 'scavenging' ? ['fixedLocations'] : ['spots']) {
        baseValue[table] = [
          ...(baseValue[table] as List),
          ...(extensionValue[table] as List),
        ];
      }
      if (key == 'scavenging') {
        for (final pool in (baseValue['surprisePools'] as Map).keys) {
          final basePools = Map<String, dynamic>.from(
            baseValue['surprisePools'] as Map,
          );
          final extensionPools = Map<String, dynamic>.from(
            extensionValue['surprisePools'] as Map,
          );
          basePools[pool] = [
            ...(basePools[pool] as List),
            ...(extensionPools[pool] as List),
          ];
          baseValue['surprisePools'] = basePools;
        }
        baseValue['itemLabels'] = {
          ...(baseValue['itemLabels'] as Map),
          ...(extensionValue['itemLabels'] as Map),
        };
        final basePhasePools = Map<String, dynamic>.from(
          baseValue['phaseSurprisePools'] as Map,
        );
        final extensionPhasePools = Map<String, dynamic>.from(
          extensionValue['phaseSurprisePools'] as Map,
        );
        for (final phase in basePhasePools.keys) {
          final basePools = Map<String, dynamic>.from(
            basePhasePools[phase] as Map,
          );
          final extensionPools = Map<String, dynamic>.from(
            extensionPhasePools[phase] as Map,
          );
          basePhasePools[phase] = {
            for (final category in basePools.keys)
              category: [
                ...(basePools[category] as List),
                ...(extensionPools[category] as List),
              ],
          };
        }
        baseValue['phaseSurprisePools'] = basePhasePools;
      }
      merged[key] = baseValue;
    }
    merged['declaredTerminalUses'] = {
      ...(merged['declaredTerminalUses'] as Map),
      ...(extension['declaredTerminalUses'] as Map),
    };
    merged['chapters'] = [0, 1, 2, 3, 4, 5];
  }
  merged['contentScope'] = chapter5 == null ? 'base' : 'aggregate';
  final result = jsonEncode(merged);
  validateStreetScrapContentPayload(result);
  return result;
}

Future<void> validateStreetScrapContentBytes(Uint8List payload) async {
  validateStreetScrapContentPayload(
    utf8.decode(payload, allowMalformed: false),
  );
}

Future<void> validateStreetScrapChapter5ContentBytes(Uint8List payload) async {
  validateStreetScrapChapter5ContentPayload(
    utf8.decode(payload, allowMalformed: false),
  );
}

/// Presentation is optional and cannot change rules, item footprints, or saves.
/// Validate the PNG before the host atomically activates the art resource.
Future<void> validateStreetScrapArtBytes(
  Uint8List payload, {
  int maxBytes = 1024 * 1024,
  int maxWidth = 2048,
  int maxHeight = 2048,
}) async {
  const signature = [137, 80, 78, 71, 13, 10, 26, 10];
  if (payload.length < 24 || payload.length > maxBytes) {
    throw const FormatException('Street Scrap art resource must be a PNG.');
  }
  for (var index = 0; index < signature.length; index++) {
    if (payload[index] != signature[index]) {
      throw const FormatException('Street Scrap art resource must be a PNG.');
    }
  }
  final header = ByteData.view(
    payload.buffer,
    payload.offsetInBytes,
    payload.lengthInBytes,
  );
  final width = header.getUint32(16);
  final height = header.getUint32(20);
  if (width == 0 || height == 0 || width > maxWidth || height > maxHeight) {
    throw const FormatException(
      'Street Scrap art atlas dimensions are invalid.',
    );
  }
}

Future<void> validateStreetScrapMaterialAtlasBytes(Uint8List payload) async {
  await validateStreetScrapArtBytes(
    payload,
    maxBytes: 2 * 1024 * 1024,
    maxWidth: 768,
    maxHeight: 2304,
  );
  final header = ByteData.view(
    payload.buffer,
    payload.offsetInBytes,
    payload.lengthInBytes,
  );
  if (header.getUint32(16) != 768 ||
      (header.getUint32(20) != 768 &&
          header.getUint32(20) != 1536 &&
          header.getUint32(20) != 2304)) {
    throw const FormatException(
      'Street Scrap material atlas must be a 768 by 768 4x4, 768 by 1536 4x8, or 768 by 2304 4x12 sheet.',
    );
  }
}

Future<void> validateStreetScrapToolAtlasBytes(Uint8List payload) async {
  await validateStreetScrapArtBytes(payload);
  final header = ByteData.view(
    payload.buffer,
    payload.offsetInBytes,
    payload.lengthInBytes,
  );
  if (header.getUint32(16) != 768 || header.getUint32(20) != 768) {
    throw const FormatException(
      'Street Scrap tool atlas must be a 768 by 768 4x4 sheet.',
    );
  }
}

Future<void> validateStreetScrapMaterialPackArtBytes(Uint8List payload) async {
  await validateStreetScrapArtBytes(payload, maxBytes: 2 * 1024 * 1024);
  final header = ByteData.view(
    payload.buffer,
    payload.offsetInBytes,
    payload.lengthInBytes,
  );
  if (header.getUint32(16) != 768 || header.getUint32(20) != 768) {
    throw const FormatException(
      'Street Scrap paper, plastic and fuel atlas must be a 768 by 768 4x4 sheet.',
    );
  }
}

Future<void> validateStreetScrapFishingSceneArtBytes(Uint8List payload) async {
  await validateStreetScrapArtBytes(
    payload,
    maxBytes: 5 * 1024 * 1024,
    maxWidth: 4096,
    maxHeight: 2048,
  );
  final header = ByteData.view(
    payload.buffer,
    payload.offsetInBytes,
    payload.lengthInBytes,
  );
  final width = header.getUint32(16);
  final height = header.getUint32(20);
  final aspect = width / height;
  if (width != 2172 || height != 724 || aspect < 2.9 || aspect > 3.1) {
    throw const FormatException(
      'Street Scrap fishing scene must be a 2172 by 724 wide PNG.',
    );
  }
}

/// Decoded artwork from the optional, signed protagonist presentation pack.
class StreetScrapProtagonistArt {
  const StreetScrapProtagonistArt({
    required this.idlePng,
    required this.actionsPng,
  });

  final Uint8List idlePng;
  final Uint8List actionsPng;

  static StreetScrapProtagonistArt fromPayload(Uint8List payload) {
    if (payload.length > 3 * 1024 * 1024) {
      throw const FormatException(
        'Street Scrap protagonist pack is too large.',
      );
    }
    final decoded = jsonDecode(utf8.decode(payload, allowMalformed: false));
    if (decoded is! Map<String, dynamic> ||
        decoded['moduleId'] != streetScrapModuleId ||
        decoded['resourceId'] != streetScrapProtagonistArtResourceId ||
        decoded['version'] != streetScrapProtagonistArtResourceVersion ||
        decoded['schemaVersion'] != streetScrapProtagonistArtSchemaVersion ||
        decoded['idlePngBase64'] is! String ||
        decoded['actionsPngBase64'] is! String) {
      throw const FormatException('Street Scrap protagonist pack is invalid.');
    }
    final idlePng = Uint8List.fromList(
      base64Decode(decoded['idlePngBase64'] as String),
    );
    final actionsPng = Uint8List.fromList(
      base64Decode(decoded['actionsPngBase64'] as String),
    );
    _validateProtagonistPng(idlePng, expectedWidth: 1159, expectedHeight: 1358);
    _validateProtagonistPng(
      actionsPng,
      expectedWidth: 1884,
      expectedHeight: 835,
    );
    return StreetScrapProtagonistArt(idlePng: idlePng, actionsPng: actionsPng);
  }
}

void _validateProtagonistPng(
  Uint8List payload, {
  required int expectedWidth,
  required int expectedHeight,
}) {
  const signature = [137, 80, 78, 71, 13, 10, 26, 10];
  if (payload.length < 24 || payload.length > 2 * 1024 * 1024) {
    throw const FormatException('Street Scrap protagonist image is invalid.');
  }
  for (var index = 0; index < signature.length; index++) {
    if (payload[index] != signature[index]) {
      throw const FormatException('Street Scrap protagonist image is invalid.');
    }
  }
  final header = ByteData.view(
    payload.buffer,
    payload.offsetInBytes,
    payload.lengthInBytes,
  );
  if (header.getUint32(16) != expectedWidth ||
      header.getUint32(20) != expectedHeight) {
    throw const FormatException(
      'Street Scrap protagonist image dimensions changed.',
    );
  }
}

Future<void> validateStreetScrapProtagonistArtBytes(Uint8List payload) async {
  StreetScrapProtagonistArt.fromPayload(payload);
}
