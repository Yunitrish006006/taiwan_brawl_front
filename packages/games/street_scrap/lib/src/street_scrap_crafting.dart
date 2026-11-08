import 'dart:collection';
import 'dart:convert';

import 'street_scrap_module.dart';
import 'street_scrap_inventory.dart';
import 'street_scrap_progress.dart';

/// Returns the exact content snapshot identity used by manual craft records.
/// When multiple optional gameplay packs are installed, this is the aggregate
/// active version rather than the base pack version alone.
String streetScrapCraftContentVersion(Map<String, String> contentVersions) =>
    contentVersions[streetScrapActiveContentVersionKey] ??
    contentVersions[streetScrapContentResourceId] ??
    '';

class StreetScrapFailureResolution {
  const StreetScrapFailureResolution({
    required this.mode,
    required this.qualityLoss,
  });
  final String mode;
  final int qualityLoss;
}

class StreetScrapCraftResult {
  const StreetScrapCraftResult({
    required this.succeeded,
    required this.outputIds,
    required this.quality,
    required this.masteryUnlocked,
  });
  final bool succeeded;
  final List<String> outputIds;
  final int quality;
  final bool masteryUnlocked;

  Map<String, Object?> toJson() => {
    'succeeded': succeeded,
    'outputIds': outputIds,
    'quality': quality,
    'masteryUnlocked': masteryUnlocked,
  };
}

/// Content-backed crafting catalog. A recipe can be executed only when its
/// required failure branch and identity behavior are machine-readable.
class StreetScrapRecipeCatalog {
  StreetScrapRecipeCatalog._(Map<String, StreetScrapRecipe> recipes)
    : recipes = UnmodifiableMapView(recipes);

  factory StreetScrapRecipeCatalog.fromRecipes(
    Iterable<StreetScrapRecipe> source, {
    int expectedCount = 78,
  }) {
    final recipes = <String, StreetScrapRecipe>{};
    for (final recipe in source) {
      if (recipes.containsKey(recipe.id)) {
        throw FormatException('Duplicate recipe ${recipe.id}.');
      }
      recipes[recipe.id] = recipe;
    }
    if (recipes.length != expectedCount) {
      throw const FormatException('Street Scrap recipe catalog is incomplete.');
    }
    return StreetScrapRecipeCatalog._(recipes);
  }

  factory StreetScrapRecipeCatalog.fromContentPayload(String source) {
    validateStreetScrapContentPayload(source);
    final payload = jsonDecode(source) as Map<String, dynamic>;
    final itemIds = (payload['itemDefinitions'] as List)
        .map((item) => (item as Map)['id'] as String)
        .toSet();
    final parsed = <String, StreetScrapRecipe>{};
    for (final raw in payload['recipes'] as List) {
      if (raw is! Map) throw const FormatException('Malformed recipe.');
      final recipe = StreetScrapRecipe.fromJson(raw, itemIds: itemIds);
      if (parsed.containsKey(recipe.id)) {
        throw FormatException('Duplicate recipe ${recipe.id}.');
      }
      parsed[recipe.id] = recipe;
    }
    final packingRules = payload['packing'] as List;
    for (final recipe in parsed.values.where(
      (recipe) => recipe.supportsRetainedPacking,
    )) {
      final effect = recipe.stateEffect!;
      if (!packingRules.any(
        (rule) =>
            rule is Map &&
            rule['input'] == effect['packingRuleId'] &&
            rule['output'] == effect['toItemId'],
      )) {
        throw FormatException(
          'Recipe ${recipe.id} references an unknown packing rule.',
        );
      }
    }
    return StreetScrapRecipeCatalog.fromRecipes(
      parsed.values,
      expectedCount: payload['contentScope'] == 'base' ? 67 : 78,
    );
  }

  final Map<String, StreetScrapRecipe> recipes;

  StreetScrapRecipe? operator [](String id) => recipes[id];

  List<StreetScrapRecipe> availableAtPhase(int phase) {
    if (phase < 0 || phase > 5) throw RangeError.range(phase, 0, 5, 'phase');
    return List.unmodifiable(
      recipes.values.where((recipe) => recipe.phase <= phase),
    );
  }
}

class StreetScrapRecipeInput {
  const StreetScrapRecipeInput({required this.itemId, required this.quantity});
  final String itemId;
  final int quantity;
}

class StreetScrapManualCheckpoint {
  StreetScrapManualCheckpoint({
    required this.prompt,
    required List<String> options,
    required this.correctOption,
  }) : options = List.unmodifiable(options);
  final String prompt;
  final List<String> options;
  final int correctOption;
}

class StreetScrapRecipeQualityRule {
  StreetScrapRecipeQualityRule({
    required List<String> primaryInputs,
    required this.loss,
    required this.mode,
    required this.masteryRevision,
  }) : primaryInputs = List.unmodifiable(primaryInputs);

  final List<String> primaryInputs;
  final int loss;
  final String mode;
  final int masteryRevision;
}

class StreetScrapRecipe {
  StreetScrapRecipe({
    required this.id,
    required this.phase,
    required this.station,
    required this.operationId,
    required this.durationSeconds,
    required this.instructions,
    required List<List<StreetScrapRecipeInput>> inputGroups,
    required List<String> reusableTools,
    required List<StreetScrapRecipeInput> outputs,
    List<StreetScrapRecipeInput> failureOutputs = const [],
    Map<String, Map<String, Object?>> outputContainerStates = const {},
    required this.quality,
    required List<String> retainedInputIds,
    this.traitResolution = const {
      'inherit': [],
      'polarity': {},
      'success': {},
      'precise': {},
      'failure': {},
    },
    List<Map<String, Object?>> qualityTraitEffects = const [],
    required this.failureMode,
    required this.failureOutcome,
    this.failureResolution,
    this.manualCheckpoints = const [],
    Map<String, Object?>? stateEffect,
  }) : inputGroups = List.unmodifiable(
         inputGroups.map(
           (group) => List<StreetScrapRecipeInput>.unmodifiable(group),
         ),
       ),
       reusableTools = List.unmodifiable(reusableTools),
       outputs = List.unmodifiable(outputs),
       failureOutputs = List.unmodifiable(failureOutputs),
       outputContainerStates = UnmodifiableMapView({
         for (final entry in outputContainerStates.entries)
           entry.key: Map<String, Object?>.unmodifiable(entry.value),
       }),
       stateEffect = stateEffect == null
           ? null
           : UnmodifiableMapView(Map.of(stateEffect)),
       retainedInputIds = List.unmodifiable(retainedInputIds),
       qualityTraitEffects = List.unmodifiable(
         qualityTraitEffects.map(
           (effect) => Map<String, Object?>.unmodifiable(effect),
         ),
       );

  final String id;
  final int phase;
  final String station;
  final String operationId;
  final int durationSeconds;
  final String instructions;

  /// Each inner list is a jointly required set; outer groups represent
  /// alternatives. This preserves the content schema's recipe semantics.
  final List<List<StreetScrapRecipeInput>> inputGroups;
  final List<String> reusableTools;
  final List<StreetScrapRecipeInput> outputs;
  final List<StreetScrapRecipeInput> failureOutputs;
  final Map<String, Map<String, Object?>> outputContainerStates;
  final StreetScrapRecipeQualityRule quality;
  final List<String> retainedInputIds;
  final Map<String, Object?> traitResolution;
  final List<Map<String, Object?>> qualityTraitEffects;
  final String failureMode;
  final String failureOutcome;
  final StreetScrapFailureResolution? failureResolution;
  final List<StreetScrapManualCheckpoint> manualCheckpoints;
  final Map<String, Object?>? stateEffect;

  bool get supportsIdentityTransform =>
      stateEffect?['type'] == 'transformObject' &&
      stateEffect?['fromItemId'] is String &&
      stateEffect?['toItemId'] is String &&
      stateEffect?['requireEmptyContainer'] == true &&
      (stateEffect?['applyOnFailure'] == null ||
          stateEffect?['applyOnFailure'] is bool) &&
      (stateEffect?['clearContainerState'] == null ||
          stateEffect?['clearContainerState'] is bool) &&
      (stateEffect?['targetContainerState'] == null ||
          stateEffect?['targetContainerState'] is Map) &&
      retainedInputIds.length == 1 &&
      retainedInputIds.single == stateEffect?['fromItemId'] &&
      outputs.isEmpty;

  bool get supportsRetainedPacking =>
      stateEffect?['type'] == 'packObjects' &&
      stateEffect?['retainedInputIds'] is List &&
      (stateEffect!['retainedInputIds']! as List).isNotEmpty &&
      stateEffect?['toItemId'] is String &&
      stateEffect?['packingRuleId'] is String &&
      retainedInputIds.length ==
          (stateEffect!['retainedInputIds']! as List).length &&
      retainedInputIds.toSet().length == retainedInputIds.length &&
      retainedInputIds.toSet().containsAll(
        (stateEffect!['retainedInputIds']! as List).cast<String>(),
      ) &&
      (stateEffect?['requireEmptyContainerItems'] == null ||
          (stateEffect!['requireEmptyContainerItems']! as List).every(
            (id) => retainedInputIds.contains(id),
          )) &&
      outputs.isEmpty;

  factory StreetScrapRecipe.fromJson(Map raw, {required Set<String> itemIds}) {
    String readString(Object? value, String field) {
      if (value is! String || value.trim().isEmpty) {
        throw FormatException('Recipe $field must be a non-empty string.');
      }
      return value;
    }

    int readInt(Object? value, String field, {int minimum = 0}) {
      if (value is! int || value < minimum) {
        throw FormatException('Recipe $field is invalid.');
      }
      return value;
    }

    List<StreetScrapRecipeInput> readItems(Object? value, String field) {
      if (value is! List) {
        throw FormatException('Recipe $field must be a list.');
      }
      return List.unmodifiable(
        value.map((entry) {
          if (entry is! Map ||
              entry['item'] is! String ||
              !itemIds.contains(entry['item'])) {
            throw FormatException('Recipe $field references an unknown item.');
          }
          return StreetScrapRecipeInput(
            itemId: entry['item'] as String,
            quantity: readInt(entry['quantity'], '$field quantity', minimum: 1),
          );
        }),
      );
    }

    final id = readString(raw['id'], 'id');
    final operation = raw['operation'];
    final quality = raw['quality'];
    final identity = raw['identity'];
    final failure = raw['failure'];
    if (operation is! Map ||
        quality is! Map ||
        identity is! Map ||
        failure is! Map ||
        raw['inputGroups'] is! List ||
        raw['reusableTools'] is! List) {
      throw FormatException('Recipe $id is missing required policy fields.');
    }
    final groups = (raw['inputGroups'] as List).map((group) {
      final inputs = readItems([
        ...(group is List ? group : const []),
      ], 'inputGroups');
      if (inputs.isEmpty) {
        throw FormatException('Recipe $id has an empty input group.');
      }
      return inputs;
    }).toList();
    if (groups.isEmpty) throw FormatException('Recipe $id has no input group.');
    final primary = quality['primaryInputs'];
    final retained = identity['retainedInputIds'];
    final tools = raw['reusableTools'] as List;
    if (primary is! List ||
        retained is! List ||
        primary.any((item) => item is! String || !itemIds.contains(item)) ||
        retained.any((item) => item is! String || !itemIds.contains(item)) ||
        tools.any((item) => item is! String || !itemIds.contains(item))) {
      throw FormatException(
        'Recipe $id references an unknown tool or identity.',
      );
    }
    final outputs = readItems(raw['outputs'], 'outputs');
    final rawOutputContainerStates = raw['outputContainerStates'];
    final outputContainerStates = <String, Map<String, Object?>>{};
    if (rawOutputContainerStates != null) {
      if (rawOutputContainerStates is! Map ||
          rawOutputContainerStates.entries.any((entry) {
            final state = entry.value;
            return entry.key is! String ||
                !outputs.any((output) => output.itemId == entry.key) ||
                state is! Map ||
                state.entries.any(
                  (stateEntry) =>
                      stateEntry.key != 'cleanliness' ||
                      !const {
                        'clean',
                        'soiled',
                        'utility',
                      }.contains(stateEntry.value),
                );
          })) {
        throw FormatException('Recipe $id has invalid output container state.');
      }
      for (final entry in rawOutputContainerStates.entries) {
        outputContainerStates[entry.key as String] = Map<String, Object?>.from(
          entry.value as Map,
        );
      }
    }
    final rawStateEffect = raw['stateEffect'];
    if (rawStateEffect != null) {
      if (rawStateEffect is! Map ||
          (outputs.isNotEmpty &&
              rawStateEffect['type'] != 'transformContainers')) {
        throw FormatException('Recipe $id has an invalid saved-state effect.');
      }
      final type = rawStateEffect['type'];
      final validBackpack =
          type == 'upgradeBackpack' &&
          rawStateEffect['fromItemId'] == 'bag.basic' &&
          rawStateEffect['toItemId'] == 'bag.reinforced' &&
          rawStateEffect['capacity'] == 24;
      final validContainer =
          type == 'transformContainerContent' &&
          rawStateEffect['containerItemId'] is String &&
          rawStateEffect['fromContentItemId'] is String &&
          rawStateEffect['toContentItemId'] is String &&
          itemIds.contains(rawStateEffect['containerItemId']) &&
          itemIds.contains(rawStateEffect['fromContentItemId']) &&
          itemIds.contains(rawStateEffect['toContentItemId']) &&
          _validContainerTraitResolution(
            rawStateEffect['contentTraitResolution'],
          ) &&
          groups.any(
            (group) => group.any(
              (input) => input.itemId == rawStateEffect['containerItemId'],
            ),
          );
      final rawContainerTransforms = rawStateEffect['containers'];
      final validMultipleContainers =
          type == 'transformContainers' &&
          rawContainerTransforms is List &&
          rawContainerTransforms.isNotEmpty &&
          rawContainerTransforms.every(
            (entry) =>
                entry is Map &&
                (entry['optional'] == null || entry['optional'] is bool) &&
                itemIds.contains(entry['containerItemId']) &&
                (entry['requiredContentItemId'] == null ||
                    itemIds.contains(entry['requiredContentItemId'])) &&
                (entry['successContentItemId'] == null ||
                    itemIds.contains(entry['successContentItemId'])) &&
                (entry['failureContentItemId'] == null ||
                    itemIds.contains(entry['failureContentItemId'])) &&
                _validContainerTraitResolution(
                  entry['contentTraitResolution'],
                ) &&
                groups.any(
                  (group) => group.any(
                    (input) =>
                        input.itemId == entry['containerItemId'] ||
                        (entry['optional'] == true &&
                            entry['requiredContentItemId'] is String &&
                            input.itemId == entry['requiredContentItemId']),
                  ),
                ),
          );
      final validObjectTransform =
          type == 'transformObject' &&
          itemIds.contains(rawStateEffect['fromItemId']) &&
          itemIds.contains(rawStateEffect['toItemId']) &&
          rawStateEffect['requireEmptyContainer'] == true &&
          (rawStateEffect['clearContainerState'] == null ||
              rawStateEffect['clearContainerState'] is bool) &&
          (rawStateEffect['applyOnFailure'] == null ||
              rawStateEffect['applyOnFailure'] is bool) &&
          (rawStateEffect['targetContainerState'] == null ||
              rawStateEffect['targetContainerState'] is Map) &&
          retained.length == 1 &&
          retained.single == rawStateEffect['fromItemId'] &&
          groups.any(
            (group) => group.any(
              (input) => input.itemId == rawStateEffect['fromItemId'],
            ),
          );
      final rawPackedIds = rawStateEffect['retainedInputIds'];
      final rawEmptyContainers = rawStateEffect['requireEmptyContainerItems'];
      final validRetainedPacking =
          type == 'packObjects' &&
          rawPackedIds is List &&
          rawPackedIds.isNotEmpty &&
          rawPackedIds.every((id) => id is String && itemIds.contains(id)) &&
          rawStateEffect['toItemId'] is String &&
          itemIds.contains(rawStateEffect['toItemId']) &&
          rawStateEffect['packingRuleId'] is String &&
          itemIds.contains(rawStateEffect['packingRuleId']) &&
          retained.length == rawPackedIds.length &&
          retained.toSet().containsAll(rawPackedIds.cast<String>()) &&
          (rawEmptyContainers == null ||
              rawEmptyContainers is List &&
                  rawEmptyContainers.every(
                    (id) => id is String && rawPackedIds.contains(id),
                  )) &&
          groups.any(
            (group) =>
                group.any((input) => rawPackedIds.contains(input.itemId)),
          );
      if (!validBackpack &&
          !validContainer &&
          !validMultipleContainers &&
          !validObjectTransform &&
          !validRetainedPacking) {
        throw FormatException('Recipe $id has an invalid saved-state effect.');
      }
    }
    final failureOutputs = raw['failureOutputs'] == null
        ? const <StreetScrapRecipeInput>[]
        : readItems(raw['failureOutputs'], 'failure outputs');
    final rawCheckpoints = operation['manualCheckpoints'] ?? const [];
    if (rawCheckpoints is! List ||
        (rawCheckpoints.isNotEmpty && rawCheckpoints.length != 3)) {
      throw FormatException('Recipe $id has malformed manual checkpoints.');
    }
    final checkpoints = <StreetScrapManualCheckpoint>[];
    for (final checkpoint in rawCheckpoints) {
      if (checkpoint is! Map ||
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
              (checkpoint['options'] as List).length) {
        throw FormatException('Recipe $id has an invalid manual checkpoint.');
      }
      checkpoints.add(
        StreetScrapManualCheckpoint(
          prompt: checkpoint['prompt'] as String,
          options: (checkpoint['options'] as List).cast<String>(),
          correctOption: checkpoint['correctOption'] as int,
        ),
      );
    }
    final phase = readInt(raw['phase'], 'phase');
    if (phase > 5) {
      throw FormatException('Recipe $id phase exceeds supported range.');
    }
    final loss = readInt(quality['loss'], 'quality loss');
    if (loss > 100) {
      throw FormatException('Recipe $id quality loss exceeds 100.');
    }
    final qualityMode = readString(quality['mode'], 'quality mode');
    if (!{
          'weighted-primary',
          'capped-at-primary',
          'preserve-primary',
        }.contains(qualityMode) ||
        (primary.isEmpty && qualityMode != 'preserve-primary') ||
        primary.any(
          (item) => !groups.any(
            (group) => group.any((input) => input.itemId == item),
          ),
        )) {
      throw FormatException(
        'Recipe $id has invalid primary-input quality rules.',
      );
    }
    final traitResolution = raw['traitResolution'];
    final rawQualityTraitEffects = raw['qualityTraitEffects'];
    final polarity = traitResolution is Map
        ? traitResolution['polarity']
        : null;
    bool validTraitMap(Object? value) {
      if (value is! Map || polarity is! Map) return false;
      return value.entries.every(
            (entry) =>
                entry.key is String &&
                (entry.key as String).trim().isNotEmpty &&
                entry.value is bool &&
                polarity.containsKey(entry.key),
          ) &&
          const ['positive', 'negative'].every(
            (kind) =>
                value.keys
                    .where((traitId) => polarity[traitId] == kind)
                    .length <=
                1,
          );
    }

    if (rawQualityTraitEffects is! List ||
        rawQualityTraitEffects.any((effect) {
          if (effect is! Map ||
              effect['inputItemId'] is! String ||
              !groups.any(
                (group) =>
                    group.any((input) => input.itemId == effect['inputItemId']),
              ) ||
              effect['traitId'] is! String ||
              (effect['traitId'] as String).trim().isEmpty ||
              !const {'positive', 'negative'}.contains(effect['polarity']) ||
              effect['modifier'] is! int ||
              effect['modifier'] == 0 ||
              (effect['polarity'] == 'positive' && effect['modifier'] < 0) ||
              (effect['polarity'] == 'negative' && effect['modifier'] > 0)) {
            return true;
          }
          return false;
        }) ||
        traitResolution is! Map ||
        traitResolution['inherit'] is! List ||
        polarity is! Map ||
        polarity.entries.any(
          (entry) =>
              entry.key is! String ||
              !const {'positive', 'negative'}.contains(entry.value),
        ) ||
        !validTraitMap(traitResolution['success']) ||
        !validTraitMap(traitResolution['precise']) ||
        !validTraitMap(traitResolution['failure']) ||
        (traitResolution['inherit'] as List).any((rule) {
          if (rule is! Map ||
              rule['inputItemId'] is! String ||
              !primary.contains(rule['inputItemId']) ||
              rule['map'] is! Map ||
              !(rule['map'] as Map).entries.every(
                (entry) =>
                    entry.key is String &&
                    (entry.key as String).trim().isNotEmpty &&
                    entry.value is String &&
                    (entry.value as String).trim().isNotEmpty &&
                    polarity.containsKey(entry.value),
              )) {
            return true;
          }
          return false;
        })) {
      throw FormatException('Recipe $id has invalid trait resolution rules.');
    }
    return StreetScrapRecipe(
      id: id,
      phase: phase,
      station: readString(raw['station'], 'station'),
      operationId: readString(operation['id'], 'operation id'),
      durationSeconds: readInt(
        operation['durationSeconds'],
        'duration',
        minimum: 1,
      ),
      instructions: readString(operation['instructions'], 'instructions'),
      inputGroups: groups,
      reusableTools: tools.cast<String>(),
      outputs: outputs,
      failureOutputs: failureOutputs,
      outputContainerStates: outputContainerStates,
      quality: StreetScrapRecipeQualityRule(
        primaryInputs: primary.cast<String>(),
        loss: loss,
        mode: qualityMode,
        masteryRevision: readInt(
          quality['masteryRevision'],
          'mastery revision',
          minimum: 1,
        ),
      ),
      retainedInputIds: retained.cast<String>(),
      traitResolution: Map<String, Object?>.from(traitResolution),
      qualityTraitEffects: [
        for (final effect in rawQualityTraitEffects)
          Map<String, Object?>.from(effect as Map),
      ],
      failureMode: readString(failure['mode'], 'failure mode'),
      failureOutcome: readString(failure['outcome'], 'failure outcome'),
      failureResolution: _readFailureResolution(raw['failureResolution'], id),
      manualCheckpoints: checkpoints,
      stateEffect: rawStateEffect == null
          ? null
          : Map<String, Object?>.from(rawStateEffect as Map),
    );
  }

  static bool _validContainerTraitResolution(Object? value) {
    if (value == null) return true;
    if (value is! Map ||
        value.keys.any(
          (key) => !const {'success', 'precise', 'failure'}.contains(key),
        )) {
      return false;
    }
    return value.values.every(
      (traits) =>
          traits is Map &&
          traits.entries.every(
            (entry) =>
                entry.key is String &&
                (entry.key as String).trim().isNotEmpty &&
                entry.value is bool,
          ),
    );
  }

  static StreetScrapFailureResolution? _readFailureResolution(
    Object? raw,
    String id,
  ) {
    if (raw == null) return null;
    if (raw is! Map ||
        raw['mode'] != 'sameOutputsQualityLoss' ||
        raw['qualityLoss'] is! int ||
        raw['qualityLoss'] < 0 ||
        raw['qualityLoss'] > 100 ||
        raw['consumeSelectedInputs'] != true) {
      throw FormatException(
        'Recipe $id has an invalid structured failure resolution.',
      );
    }
    return StreetScrapFailureResolution(
      mode: raw['mode'] as String,
      qualityLoss: raw['qualityLoss'] as int,
    );
  }
}

double streetScrapHeatTargetWidthMultiplier(
  StreetScrapRecipe recipe,
  Iterable<StreetScrapObject> inputs,
) {
  if (!const {'heat', 'cook'}.contains(recipe.operationId)) return 1;
  return inputs.any(
        (item) =>
            item.itemId.startsWith('fuel.') && item.traits['even_burn'] == true,
      )
      ? 1.1
      : 1;
}

/// Runs one confirmed, one-batch craft as an atomic save command. The content
/// package must explicitly define a machine-readable failure resolution before
/// a manual miss may consume anything.
class StreetScrapCrafting {
  /// Returns the recipe ingredient represented by an object. A filled vessel
  /// may satisfy an ingredient only when the recipe declares that exact
  /// vessel/content pairing in its container state effect.
  static String inputItemIdForObject(
    StreetScrapRecipe recipe,
    StreetScrapObject item,
  ) {
    for (final change in _containerChanges(recipe.stateEffect)) {
      if (item.itemId == change['containerItemId'] &&
          item.containerState['contentItemId'] ==
              change['requiredContentItemId'] &&
          change['requiredContentItemId'] is String &&
          recipe.inputGroups.any(
            (group) => group.any(
              (input) => input.itemId == change['requiredContentItemId'],
            ),
          )) {
        return change['requiredContentItemId']! as String;
      }
    }
    return item.itemId;
  }

  static List<Map<String, Object?>> applicableQualityTraitEffects(
    StreetScrapRecipe recipe,
    List<StreetScrapObject> inputs,
  ) {
    final applicable = <Map<String, Object?>>[];
    for (final effect in recipe.qualityTraitEffects) {
      final traitId = effect['traitId']! as String;
      final inputItemId = effect['inputItemId']! as String;
      final found = inputs.any((item) {
        if (item.itemId != inputItemId &&
            item.containerState['contentItemId'] != inputItemId) {
          return false;
        }
        if (item.traits[traitId] == true) return true;
        final contentTraits = item.containerState['contentTraits'];
        return contentTraits is Map && contentTraits[traitId] == true;
      });
      if (found) applicable.add(effect);
    }
    applicable.sort((a, b) {
      final polarity = (a['polarity']! as String).compareTo(
        b['polarity']! as String,
      );
      if (polarity != 0) return polarity;
      return (a['traitId']! as String).compareTo(b['traitId']! as String);
    });
    final usedPolarities = <String>{};
    final selected = <Map<String, Object?>>[];
    for (final effect in applicable) {
      final polarity = effect['polarity']! as String;
      if (usedPolarities.add(polarity)) {
        selected.add(effect);
      }
    }
    return List.unmodifiable(selected);
  }

  static int _qualityTraitModifier(
    StreetScrapRecipe recipe,
    List<StreetScrapObject> inputs,
  ) => applicableQualityTraitEffects(
    recipe,
    inputs,
  ).fold(0, (modifier, effect) => modifier + (effect['modifier']! as int));

  static Map<String, Object?> _resolveOutputTraits({
    required StreetScrapRecipe recipe,
    required List<StreetScrapObject> inputs,
    required bool succeeded,
    required bool precise,
  }) {
    final traits = <String, Object?>{};
    final rules = recipe.traitResolution['inherit']! as List;
    for (final rawRule in rules) {
      final rule = rawRule as Map;
      final inputItemId = rule['inputItemId']! as String;
      final mapping = rule['map']! as Map;
      for (final input in inputs.where((item) => item.itemId == inputItemId)) {
        for (final entry in mapping.entries) {
          final value = input.traits[entry.key];
          if (value is bool) {
            final target = entry.value! as String;
            if (traits.containsKey(target) && traits[target] != value) {
              throw StateError('craftTraitTransferConflict');
            }
            traits[target] = value;
          }
        }
      }
    }
    final outcome = !succeeded
        ? 'failure'
        : precise
        ? 'precise'
        : 'success';
    final resultTraits = recipe.traitResolution[outcome]! as Map;
    for (final entry in resultTraits.entries) {
      final value = entry.value! as bool;
      traits[entry.key! as String] = value;
    }
    final polarity = recipe.traitResolution['polarity']! as Map;
    if (traits.keys.any((traitId) => !polarity.containsKey(traitId)) ||
        const ['positive', 'negative'].any(
          (kind) =>
              traits.keys.where((traitId) => polarity[traitId] == kind).length >
              1,
        )) {
      throw StateError('craftTraitPolarityLimitExceeded');
    }
    return Map.unmodifiable(traits);
  }

  const StreetScrapCrafting._();

  static bool isConfirmationOnlyRecipe(StreetScrapRecipe recipe) =>
      recipe.manualCheckpoints.isEmpty &&
      const {
        'ss.recipe.unpick_cloth',
        'ss.recipe.join_thread',
        'ss.recipe.fish_pack',
      }.contains(recipe.id);

  static Future<StreetScrapCommandResult> beginManual({
    required StreetScrapSession session,
    required StreetScrapInventoryCatalog inventoryCatalog,
    required StreetScrapRecipe recipe,
    required Map<String, StreetScrapGridSpec> grids,
    required String gridId,
    required int inputGroupIndex,
    required List<String> inputInstanceIds,
    required List<String> toolInstanceIds,
    required String operationId,
    required String commandId,
    required int expectedRevision,
    required String contentVersion,
  }) {
    if (recipe.manualCheckpoints.length != 3) {
      throw StateError('craftManualCheckpointsUnavailable');
    }
    if (recipe.failureResolution == null ||
        (recipe.outputs.isEmpty && recipe.stateEffect == null) ||
        (recipe.retainedInputIds.isNotEmpty &&
            !recipe.supportsIdentityTransform &&
            !recipe.supportsRetainedPacking) ||
        (recipe.outputs.isEmpty &&
            recipe.quality.mode == 'preserve-primary' &&
            !recipe.supportsIdentityTransform &&
            !recipe.supportsRetainedPacking)) {
      throw StateError('craftOperationPolicyIncomplete');
    }
    if (contentVersion.trim().isEmpty ||
        (session.contentVersions[streetScrapActiveContentVersionKey] ??
                session.contentVersions[streetScrapContentResourceId]) !=
            contentVersion) {
      throw StateError('craftOperationIncompatible');
    }
    return session.apply(
      commandId: commandId,
      expectedRevision: expectedRevision,
      reduce: (state) {
        _requireRecipePhaseUnlocked(state, recipe);
        if (state['craftOperation'] != null) {
          throw StateError('craftOperationActive');
        }
        if (inputGroupIndex < 0 ||
            inputGroupIndex >= recipe.inputGroups.length) {
          throw RangeError.index(
            inputGroupIndex,
            recipe.inputGroups,
            'inputGroupIndex',
          );
        }
        if (operationId.trim().isEmpty) {
          throw ArgumentError.value(operationId, 'operationId');
        }
        final inventory = _inventoryFromState(state, inventoryCatalog, grids);
        _preview(
          state,
          inventory,
          inventoryCatalog,
          recipe,
          grids,
          gridId,
          inputGroupIndex,
          inputInstanceIds,
          toolInstanceIds,
          operationId,
        );
        return StreetScrapReduction(
          state: {
            ...state,
            'craftOperation': {
              'operationId': operationId,
              'recipeId': recipe.id,
              'contentVersion': contentVersion,
              'masteryRevision': recipe.quality.masteryRevision,
              'gridId': gridId,
              'inputGroupIndex': inputGroupIndex,
              'inputInstanceIds': List<String>.unmodifiable(inputInstanceIds),
              'toolInstanceIds': List<String>.unmodifiable(toolInstanceIds),
              'lockedInstanceIds': List<String>.unmodifiable({
                ...inputInstanceIds,
                ...toolInstanceIds,
              }),
              'answers': const <int>[],
              'status': 'inProgress',
            },
          },
          result: {'operationId': operationId, 'status': 'inProgress'},
        );
      },
    );
  }

  /// Persists one answer before exposing the next checkpoint. After the third
  /// answer, settlement uses a stable receipt ID and then clears the lock in a
  /// separate idempotent command; reopening can safely finish that sequence.
  static Future<StreetScrapCommandResult?> answerManualCheckpoint({
    required StreetScrapSession session,
    required StreetScrapInventoryCatalog inventoryCatalog,
    required StreetScrapRecipe recipe,
    required Map<String, StreetScrapGridSpec> grids,
    required String operationId,
    required int optionIndex,
    required int expectedRevision,
  }) async {
    final operation = _requireOperation(
      session.snapshot.state,
      operationId,
      recipe,
      session,
    );
    final answers = (operation['answers'] as List).cast<int>();
    if (answers.length >= recipe.manualCheckpoints.length) {
      return _settleSavedManual(
        session,
        inventoryCatalog,
        recipe,
        grids,
        operation,
      );
    }
    final checkpoint = recipe.manualCheckpoints[answers.length];
    if (optionIndex < 0 || optionIndex >= checkpoint.options.length) {
      throw RangeError.index(optionIndex, checkpoint.options, 'optionIndex');
    }
    final nextAnswers = [...answers, optionIndex];
    await session.apply(
      commandId: 'checkpoint-$operationId-${answers.length}',
      expectedRevision: expectedRevision,
      reduce: (state) {
        final latest = _requireOperation(state, operationId, recipe, session);
        final currentAnswers = (latest['answers'] as List).cast<int>();
        if (currentAnswers.length != answers.length) {
          throw StateError('craftCheckpointChanged');
        }
        return StreetScrapReduction(
          state: {
            ...state,
            'craftOperation': {
              ...latest,
              'answers': nextAnswers,
              'status': nextAnswers.length == recipe.manualCheckpoints.length
                  ? 'readyToSettle'
                  : 'inProgress',
            },
          },
          result: {
            'operationId': operationId,
            'savedCheckpoint': nextAnswers.length,
          },
        );
      },
    );
    if (nextAnswers.length < recipe.manualCheckpoints.length) return null;
    return _settleSavedManual(
      session,
      inventoryCatalog,
      recipe,
      grids,
      _requireOperation(session.snapshot.state, operationId, recipe, session),
    );
  }

  static Future<StreetScrapCommandResult?> resumeManual({
    required StreetScrapSession session,
    required StreetScrapInventoryCatalog inventoryCatalog,
    required StreetScrapRecipe recipe,
    required Map<String, StreetScrapGridSpec> grids,
  }) {
    final raw = session.snapshot.state['craftOperation'];
    if (raw == null) return Future.value(null);
    if (raw is! Map || raw['status'] != 'readyToSettle') {
      return Future.value(null);
    }
    final operation = _requireOperation(
      session.snapshot.state,
      raw['operationId'] as String,
      recipe,
      session,
    );
    return _settleSavedManual(
      session,
      inventoryCatalog,
      recipe,
      grids,
      operation,
    );
  }

  static Future<void> cancelManual({
    required StreetScrapSession session,
    required String operationId,
    required int expectedRevision,
  }) async {
    await session.apply(
      commandId: 'cancel-craft-$operationId',
      expectedRevision: expectedRevision,
      reduce: (state) {
        final operation = state['craftOperation'];
        if (operation is! Map || operation['operationId'] != operationId) {
          throw StateError('craftOperationMissing');
        }
        final answers = operation['answers'];
        if (answers is! List || answers.isNotEmpty) {
          throw StateError('craftAlreadyIrreversible');
        }
        return StreetScrapReduction(
          state: {...state}..remove('craftOperation'),
          result: {'operationId': operationId, 'cancelled': true},
        );
      },
    );
  }

  static Future<StreetScrapCommandResult> _settleSavedManual(
    StreetScrapSession session,
    StreetScrapInventoryCatalog inventoryCatalog,
    StreetScrapRecipe recipe,
    Map<String, StreetScrapGridSpec> grids,
    Map operation,
  ) async {
    final answers = (operation['answers'] as List).cast<int>();
    if (answers.length != recipe.manualCheckpoints.length) {
      throw StateError('craftOperationIncomplete');
    }
    var points = 0;
    for (var i = 0; i < answers.length; i++) {
      if (answers[i] == recipe.manualCheckpoints[i].correctOption) points++;
    }
    final operationId = operation['operationId'] as String;
    final result = await craft(
      session: session,
      inventoryCatalog: inventoryCatalog,
      recipe: recipe,
      grids: grids,
      gridId: operation['gridId'] as String,
      inputGroupIndex: operation['inputGroupIndex'] as int,
      inputInstanceIds: (operation['inputInstanceIds'] as List).cast<String>(),
      toolInstanceIds: (operation['toolInstanceIds'] as List).cast<String>(),
      commandId: 'settle-craft-$operationId',
      expectedRevision: session.snapshot.revision,
      manual: true,
      manualPoints: points,
      operationId: operationId,
      outputInstanceId: (index) => '$operationId-output-$index',
    );
    await session.apply(
      commandId: 'clear-craft-$operationId',
      expectedRevision: session.snapshot.revision,
      reduce: (state) {
        final current = state['craftOperation'];
        if (current == null) return StreetScrapReduction(state: state);
        if (current is! Map || current['operationId'] != operationId) {
          throw StateError('craftOperationChanged');
        }
        return StreetScrapReduction(
          state: {...state}..remove('craftOperation'),
          result: {'operationId': operationId, 'settled': true},
        );
      },
    );
    return result;
  }

  static Map<String, Object?> _requireOperation(
    Map<String, Object?> state,
    String operationId,
    StreetScrapRecipe recipe,
    StreetScrapSession session,
  ) {
    _requireRecipePhaseUnlocked(state, recipe);
    final raw = state['craftOperation'];
    if (raw is! Map ||
        raw['operationId'] != operationId ||
        raw['recipeId'] != recipe.id ||
        raw['masteryRevision'] != recipe.quality.masteryRevision ||
        raw['contentVersion'] !=
            (session.contentVersions[streetScrapActiveContentVersionKey] ??
                session.contentVersions[streetScrapContentResourceId]) ||
        raw['answers'] is! List ||
        (raw['answers'] as List).any((answer) => answer is! int)) {
      throw StateError('craftOperationIncompatible');
    }
    return Map<String, Object?>.from(raw);
  }

  static void _requireRecipePhaseUnlocked(
    Map<String, Object?> state,
    StreetScrapRecipe recipe,
  ) {
    final rawChapter = state['chapter'] ?? 0;
    if (rawChapter is! int || rawChapter < 0 || rawChapter > 5) {
      throw const FormatException('Malformed Street Scrap chapter progress.');
    }
    if (recipe.phase > rawChapter) throw StateError('recipePhaseLocked');
    if (recipe.phase >= 1 && recipe.station == 'recycler') {
      final rawStations = state['unlockedStations'];
      if (rawStations != null &&
          (rawStations is! List ||
              rawStations.any((entry) => entry is! String))) {
        throw const FormatException('Malformed unlocked stations.');
      }
      if (rawStations is! List ||
          !rawStations.cast<String>().contains('recycler')) {
        throw StateError('recipeStationLocked');
      }
    }
    final rawTasks = state['tutorialTasks'];
    if (rawTasks != null && rawTasks is! Map) {
      throw const FormatException('Malformed tutorial task progress.');
    }
    if (rawChapter >= 1 && rawTasks is Map && rawTasks['q1.01'] == true) {
      if (recipe.id == 'ss.recipe.join_thread' &&
          rawTasks['q1.02.unpicked'] != true) {
        throw StateError('q1.02UnpickFirst');
      }
      if (recipe.id == 'ss.recipe.sew_strip' &&
          (rawTasks['q1.02.unpicked'] != true ||
              rawTasks['q1.02.threadReady'] != true)) {
        throw StateError('q1.02PrepareThreadFirst');
      }
    }
    if (recipe.id == 'ss.recipe.fillet_fish' &&
        (rawTasks is! Map || rawTasks['q2.02'] != true)) {
      throw StateError('q2.02FishRequired');
    }
    if (_isChapterFourSoupRecipe(recipe.id) &&
        (rawTasks is! Map || rawTasks['q4.01'] != true)) {
      throw StateError('q4.01WaterRequired');
    }
    if (recipe.id == 'ss.recipe.press_rod' &&
        (rawTasks is! Map || rawTasks['q3.01.kitClaimed'] != true)) {
      throw StateError('q3.01WoodKitRequired');
    }
    if (recipe.id == 'ss.recipe.nail_board' &&
        (rawTasks is! Map || rawTasks['q3.02.kitClaimed'] != true)) {
      throw StateError('q3.02NailKitRequired');
    }
    if (recipe.id == 'ss.recipe.wooden_crate' &&
        (rawTasks is! Map || rawTasks['q3.04.kitClaimed'] != true)) {
      throw StateError('q3.04CrateKitRequired');
    }
    if (recipe.id == 'ss.recipe.upgrade_bag' &&
        (rawTasks is! Map || rawTasks['q3.04'] != true)) {
      throw StateError('q3.05CrateAccessRequired');
    }
  }

  static void _requireSampleSorted(
    Map<String, Object?> state,
    StreetScrapObject item,
  ) {
    if (item.source != 'tutorial:recycling-sample') return;
    final category = item.itemId.split('.').first;
    final rawClassifications = state['recyclingClassifications'];
    if (rawClassifications != null && rawClassifications is! Map) {
      throw const FormatException('Malformed recycling classifications.');
    }
    if (rawClassifications is! Map ||
        rawClassifications[item.instanceId] != category) {
      throw StateError('recyclingSampleMustBeSorted');
    }
  }

  static const _questSupplyRecipeIds = <String, Set<String>>{
    'tutorial:q1.02-rag': {'ss.recipe.unpick_cloth', 'ss.recipe.sew_strip'},
    'tutorial:q1.02-thread': {'ss.recipe.join_thread'},
    'tutorial:q3.01-kit': {'ss.recipe.press_rod'},
    'tutorial:q3.02-kit': {'ss.recipe.nail_board'},
    'tutorial:q3.04-kit': {'ss.recipe.wooden_crate'},
    'tutorial:q4.01-filter-kit': {'ss.recipe.filter_turbid'},
    'tutorial:q4.02-soup-kit': {'ss.recipe.soup_basic'},
  };

  static bool isQuestSupplyAllowedForRecipe(
    StreetScrapRecipe recipe,
    StreetScrapObject item,
  ) {
    final allowedRecipeIds = _questSupplyRecipeIds[item.source];
    return allowedRecipeIds == null || allowedRecipeIds.contains(recipe.id);
  }

  static void _requireQuestSupplyPurpose(
    StreetScrapRecipe recipe,
    StreetScrapObject item,
  ) {
    if (isQuestSupplyAllowedForRecipe(recipe, item)) return;
    if (item.source == 'tutorial:q1.02-rag' &&
        recipe.id != 'ss.recipe.unpick_cloth' &&
        recipe.id != 'ss.recipe.sew_strip') {
      throw StateError('q1.02SupplyReserved');
    }
    if (item.source == 'tutorial:q1.02-thread' &&
        recipe.id != 'ss.recipe.join_thread') {
      throw StateError('q1.02SupplyReserved');
    }
    if (item.source == 'tutorial:q3.01-kit' &&
        recipe.id != 'ss.recipe.press_rod') {
      throw StateError('q3.01SupplyReserved');
    }
    if (item.source == 'tutorial:q3.02-kit' &&
        recipe.id != 'ss.recipe.nail_board') {
      throw StateError('q3.02SupplyReserved');
    }
    if (item.source == 'tutorial:q3.04-kit' &&
        recipe.id != 'ss.recipe.wooden_crate') {
      throw StateError('q3.04SupplyReserved');
    }
    if (item.source == 'tutorial:q4.01-filter-kit' &&
        recipe.id != 'ss.recipe.filter_turbid') {
      throw StateError('q4.01SupplyReserved');
    }
    if (item.source == 'tutorial:q4.02-soup-kit' &&
        recipe.id != 'ss.recipe.soup_basic') {
      throw StateError('q4.02SupplyReserved');
    }
  }

  static Map<String, Object?> _provenanceInput(StreetScrapObject item) => {
    'instanceId': item.instanceId,
    'itemId': item.itemId,
    'source': item.source,
    'quality': item.quality,
    'traits': item.traits,
    if (item.acquiredRevision != null)
      'acquiredRevision': item.acquiredRevision,
    if (item.provenance.isNotEmpty)
      'parentEventIds': [
        for (final event in item.provenance)
          if (event['eventId'] is String) event['eventId'],
      ],
  };

  static Map<String, Object?> _provenanceEvent({
    required String eventId,
    required String kind,
    required String recipeId,
    required int revision,
    required String outcome,
    required List<StreetScrapObject> inputs,
  }) => {
    'eventId': eventId,
    'kind': kind,
    'recipeId': recipeId,
    'revision': revision,
    'outcome': outcome,
    'inputs': inputs.map(_provenanceInput).toList(growable: false),
  };

  static List<Map<String, Object?>> _lineageFor(
    Iterable<StreetScrapObject> inputs,
    Map<String, Object?> event,
  ) {
    final events = <String, Map<String, Object?>>{};
    for (final input in inputs) {
      for (final prior in input.provenance) {
        final eventId = prior['eventId'];
        if (eventId is String) events.putIfAbsent(eventId, () => prior);
      }
    }
    events[event['eventId']! as String] = event;
    return List.unmodifiable(events.values);
  }

  static StreetScrapInventory _inventoryFromState(
    Map<String, Object?> state,
    StreetScrapInventoryCatalog catalog,
    Map<String, StreetScrapGridSpec> grids,
  ) {
    final raw = state['inventory'];
    if (raw == null) return catalog.emptyInventory(grids: grids);
    if (raw is! Map) {
      throw const FormatException('Malformed Street Scrap inventory.');
    }
    return catalog.inventoryFromJson(
      grids: grids,
      json: Map<String, Object?>.from(raw),
    );
  }

  static void _preview(
    Map<String, Object?> state,
    StreetScrapInventory inventory,
    StreetScrapInventoryCatalog catalog,
    StreetScrapRecipe recipe,
    Map<String, StreetScrapGridSpec> grids,
    String gridId,
    int groupIndex,
    List<String> inputIds,
    List<String> toolIds,
    String previewPrefix,
  ) {
    if (inputIds.toSet().length != inputIds.length ||
        inputIds.any(toolIds.contains) ||
        toolIds.toSet().length != toolIds.length) {
      throw StateError('duplicateCraftSelection');
    }
    final expected = <String, int>{};
    for (final input in recipe.inputGroups[groupIndex]) {
      expected.update(
        input.itemId,
        (count) => count + input.quantity,
        ifAbsent: () => input.quantity,
      );
    }
    final actual = <String, int>{};
    for (final id in inputIds) {
      final item = inventory.objects[id];
      if (item == null ||
          item.containerContents.isNotEmpty ||
          inventory.placements[id]?.gridId != gridId) {
        throw StateError('craftInputUnavailable');
      }
      _requireSampleSorted(state, item);
      _requireQuestSupplyPurpose(recipe, item);
      final inputItemId = inputItemIdForObject(recipe, item);
      actual.update(inputItemId, (count) => count + 1, ifAbsent: () => 1);
    }
    if (!_sameCounts(expected, actual)) throw StateError('craftInputMismatch');
    final containerChanges = _containerChanges(recipe.stateEffect);
    for (final change in containerChanges) {
      final vessels = inputIds
          .map((id) => inventory.objects[id]!)
          .where(
            (item) =>
                item.itemId == change['containerItemId'] &&
                item.containerState['contentItemId'] ==
                    change['requiredContentItemId'],
          )
          .toList(growable: false);
      if (vessels.isEmpty && change['optional'] == true) continue;
      if (vessels.length != 1) throw StateError('craftContainerSelection');
      final vessel = vessels.single;
      if (vessel.containerState['contentItemId'] !=
          change['requiredContentItemId']) {
        throw StateError('craftContainerContentMismatch');
      }
    }
    final requiredTools = <String, int>{};
    for (final id in recipe.reusableTools) {
      requiredTools.update(id, (count) => count + 1, ifAbsent: () => 1);
    }
    final actualTools = <String, int>{};
    for (final id in toolIds) {
      final item = inventory.objects[id];
      if (item == null ||
          item.containerContents.isNotEmpty ||
          inventory.placements[id]?.gridId != gridId ||
          (item.toolDurability != null && item.toolDurability! <= 0)) {
        throw StateError('craftToolUnavailable');
      }
      actualTools.update(item.itemId, (count) => count + 1, ifAbsent: () => 1);
    }
    if (!_sameCounts(requiredTools, actualTools)) {
      throw StateError('craftToolsMismatch');
    }
    if ((recipe.retainedInputIds.isNotEmpty &&
            !recipe.supportsIdentityTransform &&
            !recipe.supportsRetainedPacking) ||
        (recipe.outputs.isEmpty && recipe.stateEffect == null) ||
        (recipe.outputs.isEmpty &&
            recipe.quality.mode == 'preserve-primary' &&
            !recipe.supportsIdentityTransform &&
            !recipe.supportsRetainedPacking)) {
      throw StateError('craftOperationPolicyIncomplete');
    }
    final retainedIds = inputIds
        .where(
          (id) =>
              recipe.retainedInputIds.contains(inventory.objects[id]!.itemId),
        )
        .toSet();
    final retainsObjects =
        recipe.supportsIdentityTransform || recipe.supportsRetainedPacking;
    if ((retainsObjects &&
            retainedIds.length != recipe.retainedInputIds.length) ||
        (!retainsObjects && retainedIds.isNotEmpty)) {
      throw StateError('craftRetainedInputInvalid');
    }
    final requireEmptyItems = recipe.stateEffect?['requireEmptyContainerItems'];
    if (retainsObjects &&
        retainedIds.any((id) {
          final item = inventory.objects[id]!;
          return item.containerContents.isNotEmpty ||
              (requireEmptyItems is List &&
                  requireEmptyItems.contains(item.itemId) &&
                  item.containerState['contentItemId'] != null);
        })) {
      throw StateError('craftRetainedInputInvalid');
    }
    final selectedObjects = inputIds
        .map((id) => inventory.objects[id]!)
        .toList(growable: false);
    final previewEvent = _provenanceEvent(
      eventId: 'preview:${recipe.id}:$previewPrefix',
      kind: recipe.supportsIdentityTransform ? 'transform' : 'craft',
      recipeId: recipe.id,
      revision: 0,
      outcome: 'preview',
      inputs: selectedObjects,
    );
    final consumedIds = inputIds
        .where((id) => !retainedIds.contains(id))
        .toList(growable: false);
    var afterConsumption = inventory.consumeFromGrid(consumedIds, gridId);
    if (recipe.supportsIdentityTransform) {
      final original = afterConsumption.objects[retainedIds.first]!;
      afterConsumption = afterConsumption.transformObjectType(
        instanceId: retainedIds.first,
        fromItemId: recipe.stateEffect!['fromItemId']! as String,
        toItemId: recipe.stateEffect!['toItemId']! as String,
        quality: 50,
        toolDurability: catalog.upgradedDurability(
          original,
          targetItemId: recipe.stateEffect!['toItemId']! as String,
          targetQuality: 50,
        ),
        clearContainerState: recipe.stateEffect!['clearContainerState'] == true,
        containerState: recipe.stateEffect!['targetContainerState'] is Map
            ? Map<String, Object?>.from(
                recipe.stateEffect!['targetContainerState']! as Map,
              )
            : null,
        provenance: _lineageFor(selectedObjects, previewEvent),
      );
    } else if (recipe.supportsRetainedPacking) {
      afterConsumption = afterConsumption.pack(
        ruleId: recipe.stateEffect!['packingRuleId']! as String,
        inputInstanceIds: retainedIds.toList(),
        source: 'crafted:${recipe.id}',
        containerInstanceId: '$previewPrefix:retained-pack',
        provenanceEvent: previewEvent,
        provenanceInputs: selectedObjects,
      );
      afterConsumption = afterConsumption.placeFirstFit(
        '$previewPrefix:retained-pack',
        gridId,
      );
    }
    final possibleOutputs = [
      recipe.outputs,
      if (recipe.failureOutputs.isNotEmpty) recipe.failureOutputs,
    ];
    for (var branch = 0; branch < possibleOutputs.length; branch++) {
      var simulated = afterConsumption;
      var index = 0;
      final outputGroup = possibleOutputs[branch];
      for (final output in outputGroup) {
        for (var n = 0; n < output.quantity; n++) {
          final object = catalog.createObject(
            instanceId: '$previewPrefix-preview-$branch-$index',
            itemId: output.itemId,
            source: 'craft-preview',
            quality: 50,
            traits: _resolveOutputTraits(
              recipe: recipe,
              inputs: selectedObjects,
              succeeded: branch == 0,
              precise: false,
            ),
          );
          simulated = simulated.addAndPlaceFirstFit(object, gridId);
          index++;
        }
      }
    }
    if (grids[gridId] == null) throw StateError('Unknown grid.');
  }

  static Future<StreetScrapCommandResult> craft({
    required StreetScrapSession session,
    required StreetScrapInventoryCatalog inventoryCatalog,
    required StreetScrapRecipe recipe,
    required Map<String, StreetScrapGridSpec> grids,
    required String gridId,
    required int inputGroupIndex,
    required List<String> inputInstanceIds,
    required List<String> toolInstanceIds,
    required String commandId,
    required int expectedRevision,
    required bool manual,
    required int manualPoints,
    String? operationId,
    required String Function(int index) outputInstanceId,
  }) {
    if (manualPoints < 0 || manualPoints > 3) {
      throw RangeError.range(manualPoints, 0, 3, 'manualPoints');
    }
    if (manual && recipe.manualCheckpoints.length != 3) {
      throw StateError('craftManualCheckpointsUnavailable');
    }
    if (inputGroupIndex < 0 || inputGroupIndex >= recipe.inputGroups.length) {
      throw RangeError.index(
        inputGroupIndex,
        recipe.inputGroups,
        'inputGroupIndex',
      );
    }
    return session.apply(
      commandId: commandId,
      expectedRevision: expectedRevision,
      reduce: (state) {
        _requireRecipePhaseUnlocked(state, recipe);
        final activeOperation = state['craftOperation'];
        if (activeOperation != null &&
            (activeOperation is! Map ||
                activeOperation['operationId'] != operationId)) {
          throw StateError('craftOperationActive');
        }
        final rawInventory = state['inventory'];
        final inventory = rawInventory == null
            ? inventoryCatalog.emptyInventory(grids: grids)
            : rawInventory is Map
            ? inventoryCatalog.inventoryFromJson(
                grids: grids,
                json: Map<String, Object?>.from(rawInventory),
              )
            : throw const FormatException('Malformed Street Scrap inventory.');
        final mastery = _readMastery(state['mastery']);
        if (!manual &&
            !isConfirmationOnlyRecipe(recipe) &&
            mastery[recipe.id] != recipe.quality.masteryRevision) {
          throw StateError('recipeNotMastered');
        }
        final group = recipe.inputGroups[inputGroupIndex];
        final expectedCounts = <String, int>{};
        for (final input in group) {
          expectedCounts.update(
            input.itemId,
            (value) => value + input.quantity,
            ifAbsent: () => input.quantity,
          );
        }
        if (inputInstanceIds.toSet().length != inputInstanceIds.length ||
            inputInstanceIds.any((id) => toolInstanceIds.contains(id))) {
          throw StateError('duplicateCraftSelection');
        }
        final selected = <StreetScrapObject>[];
        for (final id in inputInstanceIds) {
          final item = inventory.objects[id];
          final placement = inventory.placements[id];
          if (item == null ||
              item.containerContents.isNotEmpty ||
              placement?.gridId != gridId) {
            throw StateError('craftInputUnavailable');
          }
          _requireSampleSorted(state, item);
          _requireQuestSupplyPurpose(recipe, item);
          selected.add(item);
        }
        final actualCounts = <String, int>{};
        for (final item in selected) {
          actualCounts.update(
            inputItemIdForObject(recipe, item),
            (value) => value + 1,
            ifAbsent: () => 1,
          );
        }
        if (!_sameCounts(expectedCounts, actualCounts)) {
          throw StateError('craftInputMismatch');
        }

        final expectedTools = recipe.reusableTools.toSet();
        if (toolInstanceIds.toSet().length != toolInstanceIds.length) {
          throw StateError('duplicateCraftTool');
        }
        final actualTools = <String>{};
        for (final id in toolInstanceIds) {
          final item = inventory.objects[id];
          final placement = inventory.placements[id];
          if (item == null ||
              item.containerContents.isNotEmpty ||
              placement?.gridId != gridId ||
              (item.toolDurability != null && item.toolDurability! <= 0)) {
            throw StateError('craftToolUnavailable');
          }
          actualTools.add(item.itemId);
        }
        if (actualTools.length != toolInstanceIds.length ||
            !_sameSet(expectedTools, actualTools)) {
          throw StateError('craftToolsMismatch');
        }

        final succeeded = !manual || manualPoints >= 2;
        if (!succeeded && recipe.failureResolution == null) {
          throw StateError('craftFailureNotStructured');
        }
        final retainedItems = selected
            .where((item) => recipe.retainedInputIds.contains(item.itemId))
            .toList(growable: false);
        if ((recipe.retainedInputIds.isNotEmpty &&
                (!recipe.supportsIdentityTransform &&
                        !recipe.supportsRetainedPacking ||
                    retainedItems.length != recipe.retainedInputIds.length)) ||
            ((recipe.supportsIdentityTransform ||
                    recipe.supportsRetainedPacking) &&
                retainedItems.any((item) {
                  final requireEmptyItems =
                      recipe.stateEffect?['requireEmptyContainerItems'];
                  return item.containerContents.isNotEmpty ||
                      (requireEmptyItems is List &&
                          requireEmptyItems.contains(item.itemId) &&
                          item.containerState['contentItemId'] != null);
                }))) {
          throw StateError('craftRetainedInputInvalid');
        }
        if ((recipe.outputs.isEmpty && recipe.stateEffect == null) ||
            (recipe.outputs.isEmpty &&
                recipe.quality.mode == 'preserve-primary' &&
                !recipe.supportsIdentityTransform &&
                !recipe.supportsRetainedPacking)) {
          throw StateError('craftStateTransformationNotSupported');
        }
        var qualityTotal = 0;
        var primaryCount = 0;
        for (final item in selected.where(
          (item) => recipe.quality.primaryInputs.contains(item.itemId),
        )) {
          final effect = recipe.stateEffect;
          qualityTotal +=
              _containerChanges(
                effect,
              ).any((change) => item.itemId == change['containerItemId'])
              ? item.containerState['contentQuality'] as int? ?? item.quality
              : item.quality;
          primaryCount++;
        }
        if (primaryCount == 0) throw StateError('craftPrimaryInputMissing');
        final preserveContainerQuality =
            recipe.stateEffect?['preserveContainerContentQuality'] == true;
        var quality =
            (qualityTotal / primaryCount).round() -
            (preserveContainerQuality ? 0 : recipe.quality.loss);
        if (!preserveContainerQuality) {
          if (manual && succeeded && manualPoints == 3) quality += 8;
          if (!succeeded) quality -= recipe.failureResolution!.qualityLoss;
          quality += _qualityTraitModifier(recipe, selected);
        }
        quality = quality.clamp(0, 100).toInt();

        final containerChanges = _containerChanges(recipe.stateEffect);
        final vesselByChange = <Map<String, Object?>, StreetScrapObject>{};
        for (final change in containerChanges) {
          final vessels = selected
              .where((item) => item.itemId == change['containerItemId'])
              .where(
                (item) =>
                    item.containerState['contentItemId'] ==
                    change['requiredContentItemId'],
              )
              .toList(growable: false);
          if (vessels.isEmpty && change['optional'] == true) continue;
          if (vessels.length != 1) throw StateError('craftContainerSelection');
          final vessel = vessels.single;
          vesselByChange[change] = vessel;
        }
        final vesselIds = vesselByChange.values
            .map((item) => item.instanceId)
            .toSet();
        final consumedIds = inputInstanceIds
            .where(
              (id) =>
                  !vesselIds.contains(id) &&
                  !retainedItems.any((item) => item.instanceId == id),
            )
            .toList();
        var next = inventory.consumeFromGrid(consumedIds, gridId);
        if ((recipe.supportsIdentityTransform ||
                recipe.supportsRetainedPacking) &&
            (succeeded || recipe.stateEffect!['applyOnFailure'] != false)) {
          final effect = recipe.stateEffect!;
          final targetId = effect['toItemId']! as String;
          if (recipe.supportsIdentityTransform) {
            final sourceId = effect['fromItemId']! as String;
            final original = retainedItems.single;
            if (original.itemId != sourceId ||
                (effect['requireEmptyContainer'] == true &&
                    (original.containerState['contentItemId'] != null ||
                        original.containerContents.isNotEmpty))) {
              throw StateError('craftRetainedInputInvalid');
            }
            final event = _provenanceEvent(
              eventId:
                  'transform:${original.instanceId}:${expectedRevision + 1}:${recipe.id}',
              kind: 'transform',
              recipeId: recipe.id,
              revision: expectedRevision + 1,
              outcome: succeeded ? 'success' : 'failure',
              inputs: selected,
            );
            next = next.transformObjectType(
              instanceId: original.instanceId,
              fromItemId: sourceId,
              toItemId: targetId,
              quality: quality,
              toolDurability: inventoryCatalog.upgradedDurability(
                original,
                targetItemId: targetId,
                targetQuality: quality,
              ),
              clearContainerState: effect['clearContainerState'] == true,
              containerState: effect['targetContainerState'] is Map
                  ? Map<String, Object?>.from(
                      effect['targetContainerState']! as Map,
                    )
                  : null,
              provenance: _lineageFor(selected, event),
            );
          } else {
            final instanceId = outputInstanceId(0);
            final event = _provenanceEvent(
              eventId: 'craft:$instanceId',
              kind: 'craft',
              recipeId: recipe.id,
              revision: expectedRevision + 1,
              outcome: succeeded ? 'success' : 'failure',
              inputs: selected,
            );
            next = next.pack(
              ruleId: effect['packingRuleId']! as String,
              inputInstanceIds: retainedItems
                  .map((item) => item.instanceId)
                  .toList(growable: false),
              source: 'crafted:${recipe.id}',
              containerInstanceId: instanceId,
              provenanceEvent: event,
              provenanceInputs: selected,
            );
            next = next.placeFirstFit(instanceId, gridId);
          }
        } else if (recipe.supportsIdentityTransform &&
            !succeeded &&
            recipe.stateEffect!['applyOnFailure'] == false) {
          final original = retainedItems.single;
          final event = _provenanceEvent(
            eventId:
                'transform:${original.instanceId}:${expectedRevision + 1}:${recipe.id}',
            kind: 'transform',
            recipeId: recipe.id,
            revision: expectedRevision + 1,
            outcome: 'failure',
            inputs: selected,
          );
          next = next.appendProvenanceEvent(
            instanceId: original.instanceId,
            event: event,
            relatedInputs: selected,
          );
        }
        for (final entry in vesselByChange.entries) {
          final change = entry.key;
          final vessel = entry.value;
          final resultItemId = succeeded
              ? change['successContentItemId']
              : change['failureContentItemId'];
          final keepExistingContent =
              resultItemId == vessel.containerState['contentItemId'];
          final nextState = Map<String, Object?>.of(vessel.containerState);
          if (resultItemId == null) {
            for (final key in [
              'contentItemId',
              'contentQuality',
              'contentSource',
              'contentTraits',
              'requiresBoiling',
            ]) {
              nextState.remove(key);
            }
          } else {
            nextState['contentItemId'] = resultItemId;
            if (!keepExistingContent) {
              if (change['preserveContainerContentQuality'] != true) {
                nextState['contentQuality'] = quality;
              }
              if (change['preserveContainerContentSource'] != true) {
                nextState['contentSource'] = 'crafted:${recipe.id}';
              }
              if (change['preserveContainerContentTraits'] != true) {
                nextState['contentTraits'] = const <String, Object?>{};
              }
              final rawTraitResolution = change['contentTraitResolution'];
              if (rawTraitResolution is Map) {
                final outcome = !succeeded
                    ? 'failure'
                    : manual && manualPoints == 3
                    ? 'precise'
                    : 'success';
                final emitted = rawTraitResolution[outcome];
                if (emitted is Map) {
                  final traits = Map<String, Object?>.from(
                    nextState['contentTraits'] is Map
                        ? nextState['contentTraits']! as Map
                        : const {},
                  );
                  traits.addAll(Map<String, Object?>.from(emitted));
                  nextState['contentTraits'] = traits;
                }
              }
              nextState['requiresBoiling'] =
                  (succeeded
                          ? change['successRequiresBoiling']
                          : change['failureRequiresBoiling'])
                      as bool? ??
                  false;
            }
          }
          final cleanliness = succeeded
              ? change['successCleanliness']
              : change['failureCleanliness'];
          if (cleanliness != null) nextState['cleanliness'] = cleanliness;
          next = next.withContainerState(vessel.instanceId, nextState);
        }
        if (const {
          'ss.recipe.filter_turbid',
          'ss.recipe.filter_dirty',
        }.contains(recipe.id)) {
          for (final toolId in toolInstanceIds) {
            final tool = next.objects[toolId]!;
            next = next.withToolDurability(
              toolId,
              (tool.toolDurability! - 1).clamp(0, tool.toolDurability!),
            );
          }
        }
        Map<String, Object?>? nextBagEquipment;
        int? nextBackpackCapacity;
        if (recipe.stateEffect case final effect?
            when effect['type'] == 'upgradeBackpack') {
          final rawBag = state['bagEquipment'];
          if (rawBag != null && rawBag is! Map) {
            throw const FormatException('Malformed backpack equipment state.');
          }
          final currentCapacity = state['backpackCapacity'] as int? ?? 16;
          final bag = rawBag is Map
              ? Map<String, Object?>.from(rawBag)
              : <String, Object?>{
                  'instanceId': 'starter-bag',
                  'itemId': effect['fromItemId'],
                  'capacity': currentCapacity,
                };
          if (bag['itemId'] != effect['fromItemId'] ||
              currentCapacity >= (effect['capacity'] as int)) {
            throw StateError('backpackAlreadyUpgraded');
          }
          nextBackpackCapacity = effect['capacity'] as int;
          nextBagEquipment = {
            ...bag,
            'itemId': effect['toItemId'],
            'capacity': nextBackpackCapacity,
          };
          final newGrids = {
            ...grids,
            'backpack': StreetScrapGridSpec(
              id: 'backpack',
              width: nextBackpackCapacity ~/ 4,
              height: 4,
            ),
          };
          next = StreetScrapInventory(
            catalog: inventoryCatalog,
            grids: newGrids,
            objects: next.objects,
            placements: next.placements,
            storage: next.storage,
          );
        }
        final ids = <String>[];
        ids.addAll(retainedItems.map((item) => item.instanceId));
        var sequence = 0;
        final selectedOutputs = succeeded || recipe.failureOutputs.isEmpty
            ? recipe.outputs
            : recipe.failureOutputs;
        for (final output in selectedOutputs) {
          for (var n = 0; n < output.quantity; n++) {
            final instanceId = outputInstanceId(sequence++);
            final item = inventoryCatalog.createObject(
              instanceId: instanceId,
              itemId: output.itemId,
              source: 'crafted:${recipe.id}',
              acquiredRevision: expectedRevision + 1,
              quality: quality,
              provenance: _lineageFor(
                selected,
                _provenanceEvent(
                  eventId: 'craft:$instanceId',
                  kind: 'craft',
                  recipeId: recipe.id,
                  revision: expectedRevision + 1,
                  outcome: succeeded ? 'success' : 'failure',
                  inputs: selected,
                ),
              ),
              traits: _resolveOutputTraits(
                recipe: recipe,
                inputs: selected,
                succeeded: succeeded,
                precise: manual && succeeded && manualPoints == 3,
              ),
              containerState:
                  recipe.outputContainerStates[output.itemId] ?? const {},
            );
            next = next.addAndPlaceFirstFit(item, gridId);
            ids.add(instanceId);
          }
        }
        final nextMastery = Map<String, int>.of(mastery);
        final masteryUnlocked =
            manual &&
            succeeded &&
            mastery[recipe.id] != recipe.quality.masteryRevision;
        if (manual && succeeded) {
          nextMastery[recipe.id] = recipe.quality.masteryRevision;
        }
        final rawTasks = state['tutorialTasks'];
        if (rawTasks != null && rawTasks is! Map) {
          throw const FormatException('Malformed tutorial task progress.');
        }
        final tasks = <String, Object?>{
          if (rawTasks is Map) ...Map<String, Object?>.from(rawTasks),
        };
        final rawCompletionCounts =
            state['recipeCompletionCounts'] ?? const <String, Object?>{};
        if (rawCompletionCounts is! Map ||
            rawCompletionCounts.entries.any(
              (entry) =>
                  entry.key is! String ||
                  entry.value is! int ||
                  entry.value < 0,
            )) {
          throw const FormatException('Malformed recipe completion history.');
        }
        final recipeCompletionCounts = Map<String, Object?>.from(
          rawCompletionCounts,
        );
        recipeCompletionCounts[recipe.id] =
            (recipeCompletionCounts[recipe.id] as int? ?? 0) + 1;
        if (succeeded) {
          if (recipe.id == 'ss.recipe.unpick_cloth') {
            tasks['q1.02.unpicked'] = true;
          }
          if (recipe.id == 'ss.recipe.join_thread' &&
              tasks['q1.02.unpicked'] == true) {
            tasks['q1.02.threadReady'] = true;
          }
        }
        if (recipe.id == 'ss.recipe.sew_strip' &&
            tasks['q1.02.unpicked'] == true &&
            tasks['q1.02.threadReady'] == true) {
          // The sewing failure policy still yields a usable repair strip, at
          // reduced quality, so the lesson is complete after either result.
          tasks['q1.02.sewn'] = true;
        }
        final q102Complete =
            tasks['q1.02.unpicked'] == true &&
            tasks['q1.02.threadReady'] == true &&
            tasks['q1.02.sewn'] == true;
        if (q102Complete) tasks['q1.02'] = true;
        final completesFishFilletLesson =
            recipe.id == 'ss.recipe.fillet_fish' &&
            rawTasks is Map &&
            rawTasks['q2.02'] == true;
        if (completesFishFilletLesson) {
          tasks['q2.03'] = true;
        }
        if (recipe.id == 'ss.recipe.press_rod' &&
            tasks['q3.01.kitClaimed'] == true) {
          tasks['q3.01'] = true;
        }
        if (recipe.id == 'ss.recipe.nail_board' &&
            tasks['q3.02.kitClaimed'] == true) {
          tasks['q3.02'] = true;
        }
        if (recipe.id == 'ss.recipe.wooden_crate' &&
            tasks['q3.04.kitClaimed'] == true) {
          tasks['q3.04.crateCrafted'] = true;
        }
        if (recipe.id == 'ss.recipe.upgrade_bag' &&
            recipe.stateEffect != null) {
          tasks['q3.05'] = true;
        }
        if (recipe.id == 'ss.recipe.filter_turbid' && succeeded) {
          tasks['q4.01'] = true;
        }
        if (_isChapterFourSoupRecipe(recipe.id) && succeeded) {
          tasks['q4.02'] = true;
        }
        final currentChapter = state['chapter'] as int? ?? 0;
        final chapter =
            recipe.id == 'ss.recipe.fillet_fish' &&
                rawTasks is Map &&
                rawTasks['q2.02'] == true &&
                currentChapter < 3
            ? 3
            : state['chapter'];
        return StreetScrapReduction(
          state: {
            ...state,
            'chapter': ?chapter,
            if (completesFishFilletLesson) 'q2.03Choice': 'fillet',
            'inventory': next.toJson(),
            'bagEquipment': ?nextBagEquipment,
            'backpackCapacity': ?nextBackpackCapacity,
            'mastery': nextMastery,
            'tutorialTasks': tasks,
            'recipeCompletionCounts': recipeCompletionCounts,
          },
          result: StreetScrapCraftResult(
            succeeded: succeeded,
            outputIds: List.unmodifiable(ids),
            quality: quality,
            masteryUnlocked: masteryUnlocked,
          ).toJson(),
        );
      },
    );
  }

  static Map<String, int> _readMastery(Object? raw) {
    if (raw == null) return {};
    if (raw is! Map ||
        raw.entries.any(
          (entry) =>
              entry.key is! String || entry.value is! int || entry.value < 1,
        )) {
      throw const FormatException('Malformed Street Scrap recipe mastery.');
    }
    return {
      for (final entry in raw.entries) entry.key as String: entry.value as int,
    };
  }

  static List<Map<String, Object?>> _containerChanges(
    Map<String, Object?>? effect,
  ) {
    if (effect?['type'] == 'transformContainerContent') {
      return [
        {
          'containerItemId': effect!['containerItemId'],
          'requiredContentItemId': effect['fromContentItemId'],
          'successContentItemId': effect['toContentItemId'],
          'failureContentItemId': effect['fromContentItemId'],
          'failureCleanliness': effect['failureCleanliness'],
          'successCleanliness': effect['successCleanliness'],
          'successRequiresBoiling': effect['successRequiresBoiling'],
          'failureRequiresBoiling': effect['failureRequiresBoiling'],
          'contentTraitResolution': effect['contentTraitResolution'],
        },
      ];
    }
    if (effect?['type'] == 'transformContainers') {
      return (effect!['containers'] as List)
          .cast<Map>()
          .map(Map<String, Object?>.from)
          .toList(growable: false);
    }
    return const [];
  }

  static bool _sameCounts(Map<String, int> a, Map<String, int> b) =>
      a.length == b.length &&
      a.entries.every((entry) => b[entry.key] == entry.value);

  static bool _sameSet(Set<String> a, Set<String> b) =>
      a.length == b.length && a.containsAll(b);
}

bool _isChapterFourSoupRecipe(String recipeId) => const {
  'ss.recipe.soup_basic',
  'ss.recipe.soup_vegetable',
  'ss.recipe.soup_fish',
}.contains(recipeId);
