import 'street_scrap_inventory.dart';
import 'street_scrap_progress.dart';

/// Versioned, content-driven rules for the offline scavenging route.
class StreetScrapExpeditionRules {
  const StreetScrapExpeditionRules({
    required this.nodeCount,
    required this.investigationsPerNode,
    required this.movementCost,
    required this.investigationCost,
    required this.fixedWrongQuantity,
    required this.fixedLocations,
    required this.surprisePools,
    this.phaseSurprisePools = const {},
    required this.surpriseWeights,
    required this.surpriseTraitPools,
    required this.surpriseTraitChancePercent,
    required this.scrapQualities,
    required this.intactQualities,
  });

  final int nodeCount;
  final int investigationsPerNode;
  final int movementCost;
  final int investigationCost;
  final int fixedWrongQuantity;
  final List<StreetScrapFixedLocation> fixedLocations;
  final Map<String, List<String>> surprisePools;
  final Map<int, Map<String, List<String>>> phaseSurprisePools;
  final Map<String, int> surpriseWeights;
  final Map<String, List<StreetScrapSurpriseTraitRule>> surpriseTraitPools;
  final int surpriseTraitChancePercent;
  final List<int> scrapQualities;
  final List<int> intactQualities;

  StreetScrapFixedLocation locationFor(int phase, int nodeIndex) {
    if (phase < 0 || phase > 5 || nodeIndex < 0 || nodeIndex >= nodeCount) {
      throw RangeError('Invalid chapter or expedition node.');
    }
    final eligible = fixedLocations
        .where(
          (location) =>
              location.nodeIndex == nodeIndex && location.phase <= phase,
        )
        .toList();
    if (eligible.isEmpty) throw StateError('No fixed location for route node.');
    eligible.sort((a, b) => b.phase.compareTo(a.phase));
    return eligible.first;
  }

  factory StreetScrapExpeditionRules.fromJson(Map<String, Object?> json) {
    Map<String, Object?> map(Object? value, String label) {
      if (value is! Map) throw FormatException('Invalid expedition $label.');
      return Map<String, Object?>.from(value);
    }

    List<int> ints(Object? value, String label) {
      if (value is! List || value.any((item) => item is! int)) {
        throw FormatException('Invalid expedition $label.');
      }
      return List<int>.unmodifiable(value.cast<int>());
    }

    final weightsRaw = map(json['surpriseWeights'], 'weights');
    final poolsRaw = map(json['surprisePools'], 'pools');
    final phasePoolsValue = json['phaseSurprisePools'];
    final phasePoolsRaw = phasePoolsValue == null
        ? <String, Object?>{}
        : map(phasePoolsValue, 'phase pools');
    final traitValue = json['surpriseTraitPools'];
    final traitRaw = traitValue == null
        ? <String, Object?>{
            'positive': <Object?>[],
            'negative': <Object?>[],
            'chancePercent': 0,
          }
        : map(traitValue, 'trait pools');
    final locationsRaw = json['fixedLocations'];
    if (locationsRaw is! List) {
      throw const FormatException('Invalid fixed locations.');
    }
    final rules = StreetScrapExpeditionRules(
      nodeCount: json['nodeCount'] as int,
      investigationsPerNode: json['investigationsPerNode'] as int,
      movementCost: json['movementCost'] as int,
      investigationCost: json['investigationCost'] as int,
      fixedWrongQuantity: json['fixedWrongQuantity'] as int,
      fixedLocations: List.unmodifiable(
        locationsRaw.asMap().entries.map((indexed) {
          final raw = indexed.value;
          final location = map(raw, 'location');
          final options = location['options'];
          if (options is! List) {
            throw const FormatException('Invalid fixed options.');
          }
          return StreetScrapFixedLocation(
            id: location['id'] as String,
            label: location['name'] as String? ?? location['id'] as String,
            nodeIndex: location['nodeIndex'] as int? ?? indexed.key,
            phase: location['phase'] as int,
            options: List.unmodifiable(
              options.map((option) {
                final entry = map(option, 'option');
                return StreetScrapFixedOption(
                  itemId: entry['item'] as String,
                  quantity: entry['quantity'] as int,
                  label: entry['label'] as String? ?? entry['item'] as String,
                  qualityType: entry['qualityType'] as String? ?? 'scrap',
                );
              }),
            ),
          );
        }),
      ),
      surprisePools: Map.unmodifiable({
        for (final entry in poolsRaw.entries)
          entry.key: List<String>.unmodifiable(
            (entry.value as List).cast<String>(),
          ),
      }),
      phaseSurprisePools: Map.unmodifiable({
        for (final phaseEntry in phasePoolsRaw.entries)
          int.parse(phaseEntry.key): Map<String, List<String>>.unmodifiable({
            for (final poolEntry in map(phaseEntry.value, 'phase pool').entries)
              poolEntry.key: List<String>.unmodifiable(
                (poolEntry.value as List).cast<String>(),
              ),
          }),
      }),
      surpriseWeights: Map.unmodifiable({
        for (final entry in weightsRaw.entries) entry.key: entry.value as int,
      }),
      surpriseTraitPools: Map.unmodifiable({
        for (final polarity in ['positive', 'negative'])
          polarity: List<StreetScrapSurpriseTraitRule>.unmodifiable(
            (traitRaw[polarity] as List).map((value) {
              final entry = map(value, 'trait rule');
              return StreetScrapSurpriseTraitRule(
                prefix: entry['prefix'] as String,
                id: entry['id'] as String,
                minimumQuality: entry['minimumQuality'] as int? ?? 0,
              );
            }),
          ),
      }),
      surpriseTraitChancePercent: traitRaw['chancePercent'] as int,
      scrapQualities: ints(json['scrapQualities'], 'scrap qualities'),
      intactQualities: ints(json['intactQualities'], 'intact qualities'),
    );
    rules.validate();
    return rules;
  }

  void validate() {
    const requiredWeights = {
      'commonScraps': 50,
      'intactBase': 25,
      'containers': 15,
      'optionalSpecial': 10,
    };
    if (nodeCount != 3 ||
        investigationsPerNode != 1 ||
        movementCost < 0 ||
        investigationCost < 1 ||
        fixedWrongQuantity < 1 ||
        surpriseWeights.length != requiredWeights.length ||
        requiredWeights.entries.any(
          (entry) => surpriseWeights[entry.key] != entry.value,
        ) ||
        surpriseWeights.values.any((weight) => weight < 0) ||
        surpriseWeights.values.fold<int>(0, (a, b) => a + b) != 100 ||
        surprisePools.keys
            .toSet()
            .difference(surpriseWeights.keys.toSet())
            .isNotEmpty ||
        surpriseWeights.keys
            .toSet()
            .difference(surprisePools.keys.toSet())
            .isNotEmpty ||
        (phaseSurprisePools.isNotEmpty &&
            (phaseSurprisePools.length != 6 ||
                List<int>.generate(
                  6,
                  (phase) => phase,
                ).any((phase) => !phaseSurprisePools.containsKey(phase)))) ||
        phaseSurprisePools.entries.any(
          (phaseEntry) =>
              phaseEntry.key < 0 ||
              phaseEntry.key > 5 ||
              phaseEntry.value.keys
                  .toSet()
                  .difference(surpriseWeights.keys.toSet())
                  .isNotEmpty ||
              surpriseWeights.keys
                  .toSet()
                  .difference(phaseEntry.value.keys.toSet())
                  .isNotEmpty ||
              surpriseWeights.keys
                  .where((category) => category != 'optionalSpecial')
                  .any((category) => phaseEntry.value[category]!.isEmpty) ||
              phaseEntry.value.values
                  .expand((pool) => pool)
                  .any((itemId) => itemId.isEmpty),
        ) ||
        surpriseTraitChancePercent < 0 ||
        surpriseTraitChancePercent > 100 ||
        !surpriseTraitPools.keys.toSet().containsAll([
          'positive',
          'negative',
        ]) ||
        surpriseTraitPools.values
            .expand((pool) => pool)
            .any(
              (rule) =>
                  rule.prefix.isEmpty ||
                  rule.id.isEmpty ||
                  rule.minimumQuality < 0 ||
                  rule.minimumQuality > 100,
            ) ||
        fixedLocations.length < nodeCount ||
        scrapQualities.isEmpty ||
        intactQualities.isEmpty ||
        fixedLocations.any(
          (location) =>
              location.options.isEmpty ||
              location.nodeIndex < 0 ||
              location.nodeIndex >= nodeCount ||
              location.phase < 0 ||
              location.phase > 5 ||
              location.options.any(
                (option) =>
                    option.qualityType != 'scrap' &&
                    option.qualityType != 'intact',
              ),
        ) ||
        [
          ...scrapQualities,
          ...intactQualities,
        ].any((quality) => quality < 0 || quality > 100)) {
      throw const FormatException('Invalid Street Scrap expedition rules.');
    }
    final phaseNodes = fixedLocations
        .map((location) => '${location.phase}:${location.nodeIndex}')
        .toSet();
    if (phaseNodes.length != fixedLocations.length ||
        List<int>.generate(
          nodeCount,
          (index) => index,
        ).any((index) => !phaseNodes.contains('0:$index'))) {
      throw const FormatException(
        'Invalid phase-specific fixed scavenging route.',
      );
    }
  }
}

class StreetScrapSurpriseTraitRule {
  const StreetScrapSurpriseTraitRule({
    required this.prefix,
    required this.id,
    this.minimumQuality = 0,
  });

  final String prefix;
  final String id;
  final int minimumQuality;
}

class StreetScrapFixedLocation {
  const StreetScrapFixedLocation({
    required this.id,
    this.label = '',
    required this.nodeIndex,
    required this.phase,
    required this.options,
  });
  final String id;
  final String label;
  final int nodeIndex;
  final int phase;
  final List<StreetScrapFixedOption> options;
}

class StreetScrapFixedOption {
  const StreetScrapFixedOption({
    required this.itemId,
    required this.quantity,
    required this.label,
    this.qualityType = 'scrap',
  });
  final String itemId;
  final int quantity;
  final String label;
  final String qualityType;
}

/// Persist this value in the save envelope. Pending rewards are frozen at the
/// investigation commit, so reopening a save can never reroll an outcome.
class StreetScrapExpedition {
  const StreetScrapExpedition({
    required this.id,
    required this.phase,
    required this.seed,
    required this.stamina,
    required this.nodeIndex,
    required this.visited,
    required this.investigated,
    required this.pendingRewards,
    required this.returned,
    required this.claimed,
    required this.drawIndex,
    required this.discardedCount,
  });

  final String id;
  final int phase;
  final int seed;
  final int stamina;
  final int nodeIndex;
  final List<int> visited;
  final List<int> investigated;
  final List<Map<String, Object?>> pendingRewards;
  final bool returned;
  final bool claimed;
  final int drawIndex;
  final int discardedCount;

  factory StreetScrapExpedition.start({
    required String id,
    required int phase,
    required int seed,
    required int stamina,
    required StreetScrapExpeditionRules rules,
  }) {
    rules.validate();
    if (id.trim().isEmpty ||
        phase < 0 ||
        stamina < rules.movementCost ||
        seed < 0) {
      throw ArgumentError('Invalid expedition start.');
    }
    return StreetScrapExpedition(
      id: id,
      phase: phase,
      seed: seed,
      stamina: stamina - rules.movementCost,
      nodeIndex: 0,
      visited: const [0],
      investigated: const [],
      pendingRewards: const [],
      returned: false,
      claimed: false,
      drawIndex: 0,
      discardedCount: 0,
    );
  }

  StreetScrapExpedition move(StreetScrapExpeditionRules rules) {
    validateAgainst(rules);
    _ensureActive();
    final next = nodeIndex + 1;
    if (next >= rules.nodeCount) throw StateError('No further route node.');
    if (stamina < rules.movementCost) throw StateError('insufficientStamina');
    return _copy(
      nodeIndex: next,
      stamina: stamina - rules.movementCost,
      visited: [...visited, next],
    );
  }

  StreetScrapInvestigation investigateFixed({
    required StreetScrapExpeditionRules rules,
    required int optionIndex,
    required bool selectedVisibleTarget,
  }) {
    _ensureCanInvestigate(rules);
    final location = rules.locationFor(phase, nodeIndex);
    if (optionIndex < 0 || optionIndex >= location.options.length) {
      throw StateError('lockedContent');
    }
    final selected = location.options[optionIndex];
    final quantity = selectedVisibleTarget
        ? selected.quantity
        : rules.fixedWrongQuantity;
    final qualityPool = selected.qualityType == 'intact'
        ? rules.intactQualities
        : rules.scrapQualities;
    final quality = _draw(qualityPool.length);
    final reward = _reward(
      selected.itemId,
      quantity,
      qualityPool[quality],
      'fixed:${location.id}',
    );
    return StreetScrapInvestigation(
      expedition: _copy(
        stamina: stamina - rules.investigationCost,
        investigated: [...investigated, nodeIndex],
        pendingRewards: [...pendingRewards, reward],
        drawIndex: drawIndex + 1,
      ),
      reward: reward,
    );
  }

  StreetScrapInvestigation investigateSurprise(
    StreetScrapExpeditionRules rules,
  ) {
    _ensureCanInvestigate(rules);
    final categoryRoll = _drawAt(drawIndex, 100);
    var cursor = 0;
    String category = '';
    for (final entry in rules.surpriseWeights.entries) {
      cursor += entry.value;
      if (categoryRoll < cursor) {
        category = entry.key;
        break;
      }
    }
    final phasePools = rules.phaseSurprisePools[phase] ?? rules.surprisePools;
    var pool = phasePools[category] ?? const <String>[];
    if (pool.isEmpty && category == 'optionalSpecial') {
      category = 'commonScraps';
      pool = phasePools[category] ?? const [];
    }
    if (pool.isEmpty) {
      throw StateError('No eligible surprise item for $category.');
    }
    final itemId = pool[_drawAt(drawIndex + 1, pool.length)];
    final intact =
        category == 'intactBase' ||
        category == 'containers' ||
        category == 'optionalSpecial';
    final qualityPool = intact ? rules.intactQualities : rules.scrapQualities;
    final quality = qualityPool[_drawAt(drawIndex + 2, qualityPool.length)];
    final traits = <String, Object?>{};
    for (final entry in [
      ('positive', drawIndex + 3, drawIndex + 4),
      ('negative', drawIndex + 5, drawIndex + 6),
    ]) {
      if (_drawAt(entry.$2, 100) >= rules.surpriseTraitChancePercent) continue;
      final candidates =
          (rules.surpriseTraitPools[entry.$1] ?? const [])
              .where(
                (rule) =>
                    itemId.startsWith(rule.prefix) &&
                    quality >= rule.minimumQuality,
              )
              .toList()
            ..sort((a, b) => a.id.compareTo(b.id));
      if (candidates.isNotEmpty) {
        final traitId = candidates[_drawAt(entry.$3, candidates.length)].id;
        // Inventory and crafting use canonical trait IDs as boolean keys.
        // Persisting the roll polarity as the key made found traits invisible
        // to every downstream consumer.
        traits[traitId] = true;
      }
    }
    if (itemId == 'water.mineral') traits['mineral_rich'] = true;
    final reward = _reward(
      itemId,
      1,
      quality,
      'surprise:$category',
      traits: traits,
    );
    return StreetScrapInvestigation(
      expedition: _copy(
        stamina: stamina - rules.investigationCost,
        investigated: [...investigated, nodeIndex],
        pendingRewards: [...pendingRewards, reward],
        drawIndex: drawIndex + 7,
      ),
      reward: reward,
    );
  }

  StreetScrapExpedition returnHome() {
    _ensureActive();
    return _copy(returned: true);
  }

  StreetScrapExpedition _markClaimed() {
    if (!returned || claimed) throw StateError('Rewards are not claimable.');
    return _copy(claimed: true);
  }

  Map<String, Object?> toJson() => {
    'id': id,
    'phase': phase,
    'seed': seed,
    'stamina': stamina,
    'nodeIndex': nodeIndex,
    'visited': visited,
    'investigated': investigated,
    'pendingRewards': pendingRewards,
    'returned': returned,
    'claimed': claimed,
    'drawIndex': drawIndex,
    'discardedCount': discardedCount,
  };

  factory StreetScrapExpedition.fromJson(Map<String, Object?> json) {
    final visited = (json['visited'] as List).cast<int>();
    final investigated = (json['investigated'] as List).cast<int>();
    final rewards = (json['pendingRewards'] as List)
        .map(
          (value) =>
              _normalizeSavedReward(Map<String, Object?>.from(value as Map)),
        )
        .toList();
    final expedition = StreetScrapExpedition(
      id: json['id'] as String,
      phase: json['phase'] as int,
      seed: json['seed'] as int,
      stamina: json['stamina'] as int,
      nodeIndex: json['nodeIndex'] as int,
      visited: List.unmodifiable(visited),
      investigated: List.unmodifiable(investigated),
      pendingRewards: List.unmodifiable(rewards),
      returned: json['returned'] as bool,
      claimed: json['claimed'] as bool,
      drawIndex: json['drawIndex'] as int,
      discardedCount: json['discardedCount'] as int? ?? 0,
    );
    if (expedition.id.isEmpty ||
        expedition.phase < 0 ||
        expedition.seed < 0 ||
        expedition.stamina < 0 ||
        expedition.nodeIndex < 0 ||
        expedition.visited.isEmpty ||
        expedition.visited.last != expedition.nodeIndex ||
        expedition.drawIndex < 0 ||
        expedition.discardedCount < 0 ||
        expedition.visited.toSet().length != expedition.visited.length ||
        expedition.visited.asMap().entries.any(
          (entry) => entry.value != entry.key,
        ) ||
        expedition.investigated.toSet().length !=
            expedition.investigated.length ||
        expedition.investigated.any(
          (node) => !expedition.visited.contains(node),
        ) ||
        expedition.pendingRewards.any(
          (reward) =>
              reward['itemId'] is! String ||
              reward['quantity'] is! int ||
              (reward['quantity']! as int) < 1 ||
              reward['quality'] is! int ||
              (reward['quality']! as int) < 0 ||
              (reward['quality']! as int) > 100 ||
              reward['source'] is! String ||
              (reward['source']! as String).isEmpty ||
              (reward['traits'] != null && reward['traits'] is! Map),
        ) ||
        expedition.pendingRewards.length + expedition.discardedCount !=
            expedition.investigated.length ||
        expedition.claimed && !expedition.returned) {
      throw const FormatException('Malformed saved Street Scrap expedition.');
    }
    return expedition;
  }

  void validateAgainst(StreetScrapExpeditionRules rules) {
    rules.validate();
    if (nodeIndex >= rules.nodeCount ||
        visited.length > rules.nodeCount ||
        investigated.length > rules.nodeCount * rules.investigationsPerNode ||
        investigated.any((node) => node < 0 || node >= rules.nodeCount)) {
      throw const FormatException(
        'Expedition progress exceeds the installed route rules.',
      );
    }
  }

  void _ensureCanInvestigate(StreetScrapExpeditionRules rules) {
    validateAgainst(rules);
    _ensureActive();
    if (nodeIndex >= rules.nodeCount || investigated.contains(nodeIndex)) {
      throw StateError('nodeAlreadyInvestigated');
    }
    if (stamina < rules.investigationCost) {
      throw StateError('insufficientStamina');
    }
  }

  void _ensureActive() {
    if (returned || claimed) throw StateError('expeditionNotActive');
  }

  int _draw(int count) {
    return _drawAt(drawIndex, count);
  }

  /// Stable clue answer for the current survey, derived from the persisted seed
  /// and draw position; observing or reopening the route does not consume RNG.
  int get targetSilhouetteIndex => _drawAt(drawIndex + 1, 3);

  int _drawAt(int index, int count) {
    if (count < 1) throw StateError('Empty random table.');
    // A small deterministic integer mixer; only seed and drawIndex are saved.
    var value = (seed + 0x9e3779b9 * (index + 1)) & 0x7fffffff;
    value ^= value << 13;
    value &= 0x7fffffff;
    value ^= value >> 17;
    value &= 0x7fffffff;
    value ^= value << 5;
    value &= 0x7fffffff;
    return value % count;
  }

  Map<String, Object?> _reward(
    String item,
    int quantity,
    int quality,
    String source, {
    Map<String, Object?> traits = const {},
  }) => {
    'itemId': item,
    'quantity': quantity,
    'quality': quality,
    'source': source,
    if (traits.isNotEmpty) 'traits': traits,
  };

  static Map<String, Object?> _normalizeSavedReward(
    Map<String, Object?> reward,
  ) {
    final rawTraits = reward['traits'];
    if (rawTraits == null) return reward;
    if (rawTraits is! Map) {
      throw const FormatException('Malformed saved scavenging traits.');
    }
    reward['traits'] = streetScrapNormalizeTraitMap(rawTraits);
    return reward;
  }

  StreetScrapExpedition _copy({
    int? nodeIndex,
    int? stamina,
    List<int>? visited,
    List<int>? investigated,
    List<Map<String, Object?>>? pendingRewards,
    bool? returned,
    bool? claimed,
    int? drawIndex,
    int? discardedCount,
  }) => StreetScrapExpedition(
    id: id,
    phase: phase,
    seed: seed,
    stamina: stamina ?? this.stamina,
    nodeIndex: nodeIndex ?? this.nodeIndex,
    visited: List.unmodifiable(visited ?? this.visited),
    investigated: List.unmodifiable(investigated ?? this.investigated),
    pendingRewards: List.unmodifiable(
      pendingRewards ?? this.pendingRewards.map(Map<String, Object?>.from),
    ),
    returned: returned ?? this.returned,
    claimed: claimed ?? this.claimed,
    drawIndex: drawIndex ?? this.drawIndex,
    discardedCount: discardedCount ?? this.discardedCount,
  );
}

class StreetScrapInvestigation {
  const StreetScrapInvestigation({
    required this.expedition,
    required this.reward,
  });
  final StreetScrapExpedition expedition;
  final Map<String, Object?> reward;
}

/// Save a domain transition using the session's existing revision/CAS receipt.
Future<StreetScrapCommandResult> applyStreetScrapExpeditionCommand({
  required StreetScrapSession session,
  required String commandId,
  required int expectedRevision,
  required StreetScrapExpeditionRules rules,
  required StreetScrapExpedition Function(StreetScrapExpedition?) transition,
}) => session.apply(
  commandId: commandId,
  expectedRevision: expectedRevision,
  reduce: (state) {
    final raw = state['expedition'];
    final current = raw == null
        ? null
        : raw is Map
        ? StreetScrapExpedition.fromJson(Map<String, Object?>.from(raw))
        : throw const FormatException('Malformed expedition save.');
    current?.validateAgainst(rules);
    final next = transition(current);
    rules.validate();
    next.validateAgainst(rules);
    return StreetScrapReduction(
      state: {...state, 'stamina': next.stamina, 'expedition': next.toJson()},
      result: next.toJson(),
    );
  },
);

/// Starts a new route and atomically pays the movement cost for entering its
/// first node. An unclaimed previous trip must be resolved first.
Future<StreetScrapCommandResult> startStreetScrapExpeditionCommand({
  required StreetScrapSession session,
  required String commandId,
  required int expectedRevision,
  required int phase,
  required int seed,
  required int defaultStamina,
  required StreetScrapExpeditionRules rules,
}) => session.apply(
  commandId: commandId,
  expectedRevision: expectedRevision,
  reduce: (state) {
    final raw = state['expedition'];
    if (raw != null) {
      if (raw is! Map) {
        throw const FormatException('Malformed expedition save.');
      }
      final previous = StreetScrapExpedition.fromJson(
        Map<String, Object?>.from(raw),
      );
      if (!previous.claimed) throw StateError('claimPreviousRewardsFirst');
    }
    final stamina = state['stamina'] as int? ?? defaultStamina;
    if (defaultStamina < 1 || stamina < 0 || stamina > defaultStamina) {
      throw const FormatException(
        'Saved expedition stamina is outside its configured range.',
      );
    }
    final next = StreetScrapExpedition.start(
      id: 'expedition-$commandId',
      phase: phase,
      seed: seed,
      stamina: stamina,
      rules: rules,
    );
    next.validateAgainst(rules);
    return StreetScrapReduction(
      state: {...state, 'stamina': next.stamina, 'expedition': next.toJson()},
      result: next.toJson(),
    );
  },
);

/// Atomically transfers all returned rewards into the backpack and marks the
/// expedition claimed. A full or incompatible inventory leaves both unchanged.
Future<StreetScrapCommandResult> claimStreetScrapExpeditionRewards({
  required StreetScrapSession session,
  required String commandId,
  required int expectedRevision,
  required StreetScrapExpeditionRules rules,
  required StreetScrapInventoryCatalog catalog,
  required Map<String, StreetScrapGridSpec> grids,
  required String backpackGridId,
  Map<int, String> mineralWaterVessels = const {},
}) => session.apply(
  commandId: commandId,
  expectedRevision: expectedRevision,
  reduce: (state) {
    final rawExpedition = state['expedition'];
    final rawInventory = state['inventory'];
    if (rawExpedition is! Map) throw StateError('No expedition to claim.');
    final expedition = StreetScrapExpedition.fromJson(
      Map<String, Object?>.from(rawExpedition),
    );
    expedition.validateAgainst(rules);
    if (!expedition.returned || expedition.claimed) {
      throw StateError('Rewards are not claimable.');
    }
    final inventory = rawInventory == null
        ? catalog.emptyInventory(grids: grids)
        : rawInventory is Map
        ? catalog.inventoryFromJson(
            grids: grids,
            json: Map<String, Object?>.from(rawInventory),
          )
        : throw const FormatException(
            'Malformed saved Street Scrap inventory.',
          );
    var nextInventory = inventory;
    var ordinal = 0;
    final consumedVessels = <String>{};
    for (
      var rewardIndex = 0;
      rewardIndex < expedition.pendingRewards.length;
      rewardIndex++
    ) {
      final reward = expedition.pendingRewards[rewardIndex];
      if (reward['itemId'] == 'water.mineral') {
        if (reward['quantity'] != 1) {
          throw const FormatException(
            'Mineral water rewards must be single-vessel events.',
          );
        }
        final vesselId = mineralWaterVessels[rewardIndex];
        if (vesselId == null || !consumedVessels.add(vesselId)) {
          throw StateError(
            'A clean empty vessel must be selected for mineral water.',
          );
        }
        final vessel = nextInventory.objects[vesselId];
        if (vessel == null ||
            !const {
              'container.clean',
              'container.clean_jar',
              'container.used_intact',
            }.contains(vessel.itemId) ||
            vessel.containerState['contentItemId'] != null ||
            vessel.containerState['cleanliness'] != 'clean' ||
            !nextInventory.placements.containsKey(vesselId)) {
          throw StateError(
            'A clean empty vessel must be selected for mineral water.',
          );
        }
        nextInventory = nextInventory.withContainerState(vesselId, {
          'contentItemId': 'water.mineral',
          'contentQuality': reward['quality']! as int,
          'contentSource': reward['source']! as String,
          'contentTraits': reward['traits'] is Map
              ? Map<String, Object?>.from(reward['traits']! as Map)
              : const <String, Object?>{},
          'requiresBoiling': false,
          'cleanliness': 'utility',
        });
        continue;
      }
      final quantity = reward['quantity']! as int;
      for (var copy = 0; copy < quantity; copy++) {
        final instanceId = '${expedition.id}:reward:$rewardIndex:$copy';
        if (nextInventory.objects.containsKey(instanceId)) {
          throw const FormatException('Duplicate expedition reward identity.');
        }
        final item = catalog.createObject(
          instanceId: instanceId,
          itemId: reward['itemId']! as String,
          source: reward['source']! as String,
          quality: reward['quality']! as int,
          traits: reward['traits'] is Map
              ? Map<String, Object?>.from(reward['traits']! as Map)
              : const {},
          acquiredRevision: expectedRevision + 1,
          containerState: switch (reward['itemId']) {
            'container.clean' ||
            'container.clean_jar' => const {'cleanliness': 'clean'},
            'container.used_intact' => const {'cleanliness': 'soiled'},
            _ => const {},
          },
        );
        nextInventory = nextInventory.addAndPlaceFirstFit(item, backpackGridId);
        ordinal++;
      }
    }
    final claimed = expedition._markClaimed();
    final rawTasks = state['tutorialTasks'];
    if (rawTasks != null && rawTasks is! Map) {
      throw const FormatException('Malformed tutorial task progress.');
    }
    final tasks = <String, Object?>{
      if (rawTasks is Map) ...Map<String, Object?>.from(rawTasks),
    };
    if (expedition.pendingRewards.isNotEmpty) tasks['q0.01'] = true;
    if (nextInventory.placements.values.any(
      (placement) => placement.gridId == backpackGridId,
    )) {
      tasks['q0.02'] = true;
    }
    return StreetScrapReduction(
      state: {
        ...state,
        'inventory': nextInventory.toJson(),
        'expedition': claimed.toJson(),
        'tutorialTasks': tasks,
      },
      result: {
        'claimedObjects': ordinal,
        'filledVessels': consumedVessels.toList(growable: false),
      },
    );
  },
);

/// Completes the phase-0 recycling hand-in as one save transaction.
Future<StreetScrapCommandResult> deliverStreetScrapTutorialMaterials({
  required StreetScrapSession session,
  required String commandId,
  required int expectedRevision,
  required StreetScrapInventoryCatalog catalog,
  required Map<String, StreetScrapGridSpec> grids,
  required String backpackGridId,
  required List<String> eligibleItemIds,
  required int quantity,
}) => session.apply(
  commandId: commandId,
  expectedRevision: expectedRevision,
  reduce: (state) {
    final rawTasks = state['tutorialTasks'];
    if (rawTasks is! Map ||
        rawTasks['q0.01'] != true ||
        rawTasks['q0.02'] != true ||
        rawTasks['q0.03'] == true) {
      throw StateError('tutorialDeliveryLocked');
    }
    final rawInventory = state['inventory'];
    if (rawInventory is! Map || quantity < 1 || eligibleItemIds.isEmpty) {
      throw const FormatException('Tutorial delivery has no valid inventory.');
    }
    final inventory = catalog.inventoryFromJson(
      grids: grids,
      json: Map<String, Object?>.from(rawInventory),
    );
    final ids = inventory.placements.values
        .where((placement) => placement.gridId == backpackGridId)
        .map((placement) => placement.instanceId)
        .where((id) => eligibleItemIds.contains(inventory.objects[id]?.itemId))
        .take(quantity)
        .toList(growable: false);
    if (ids.length != quantity) {
      throw StateError('tutorialDeliveryInsufficientItems');
    }
    final nextInventory = inventory.consumeFromGrid(ids, backpackGridId);
    final rawChapter = state['chapter'] ?? 0;
    if (rawChapter is! int || rawChapter < 0 || rawChapter > 5) {
      throw const FormatException('Malformed Street Scrap chapter progress.');
    }
    final tasks = Map<String, Object?>.from(rawTasks)..['q0.03'] = true;
    return StreetScrapReduction(
      state: {
        ...state,
        'chapter': rawChapter < 1 ? 1 : rawChapter,
        'inventory': nextInventory.toJson(),
        'tutorialTasks': tasks,
      },
      result: {'itemIds': ids, 'quantity': quantity},
    );
  },
);

const streetScrapRecyclingCategories = <String, String>{
  'paper': '紙',
  'metal': '金屬',
  'cloth': '布',
  'plastic': '塑料',
};

const streetScrapRecyclingTutorialSamples = <String, String>{
  'q1-sample-paper': 'paper.scrap',
  'q1-sample-metal': 'metal.scrap',
  'q1-sample-cloth': 'cloth.rag_piece',
  'q1-sample-plastic': 'plastic.scrap',
};

String? streetScrapRecyclingCategoryForItem(String itemId) {
  for (final category in streetScrapRecyclingCategories.keys) {
    if (itemId.startsWith('$category.')) return category;
  }
  return null;
}

/// Grants the two reusable starter bottles from the phase-0 tutorial once.
/// Both bottles enter the backpack together, or neither does if space is short.
Future<StreetScrapCommandResult> claimStreetScrapStarterVessels({
  required StreetScrapSession session,
  required String commandId,
  required int expectedRevision,
  required StreetScrapInventoryCatalog catalog,
  required Map<String, StreetScrapGridSpec> grids,
  required String backpackGridId,
}) => session.apply(
  commandId: commandId,
  expectedRevision: expectedRevision,
  reduce: (state) {
    final chapter = state['chapter'] ?? 0;
    if (chapter != 0) throw StateError('starterVesselsLocked');
    final rawTasks = state['tutorialTasks'];
    if (rawTasks != null && rawTasks is! Map) {
      throw const FormatException('Malformed tutorial task progress.');
    }
    final tasks = <String, Object?>{
      if (rawTasks is Map) ...Map<String, Object?>.from(rawTasks),
    };
    if (tasks['q0.vesselsClaimed'] == true) {
      throw StateError('starterVesselsAlreadyClaimed');
    }
    final rawInventory = state['inventory'];
    final inventory = rawInventory == null
        ? catalog.emptyInventory(grids: grids)
        : rawInventory is Map
        ? catalog.inventoryFromJson(
            grids: grids,
            json: Map<String, Object?>.from(rawInventory),
          )
        : throw const FormatException('Malformed Street Scrap inventory.');
    var next = inventory;
    for (var index = 0; index < 2; index++) {
      final instanceId = 'q0-starter-vessel-$index';
      if (next.objects.containsKey(instanceId)) {
        throw const FormatException('Duplicate phase-0 starter vessel.');
      }
      next = next.addAndPlaceFirstFit(
        catalog.createObject(
          instanceId: instanceId,
          itemId: 'container.used_intact',
          source: 'tutorial:q0-starter-vessels',
          quality: 55,
          traits: const {},
          containerState: const {'cleanliness': 'soiled'},
        ),
        backpackGridId,
      );
    }
    tasks['q0.vesselsClaimed'] = true;
    return StreetScrapReduction(
      state: {...state, 'inventory': next.toJson(), 'tutorialTasks': tasks},
      result: {'vesselCount': 2},
    );
  },
);

/// Delivers the fixed chapter-1 teaching samples exactly once. If the backpack
/// cannot fit all four, the transaction fails without granting a partial set.
Future<StreetScrapCommandResult> claimStreetScrapRecyclingSamples({
  required StreetScrapSession session,
  required String commandId,
  required int expectedRevision,
  required StreetScrapInventoryCatalog catalog,
  required Map<String, StreetScrapGridSpec> grids,
  required String backpackGridId,
}) => session.apply(
  commandId: commandId,
  expectedRevision: expectedRevision,
  reduce: (state) {
    final chapter = state['chapter'] ?? 0;
    if (chapter is! int || chapter < 0 || chapter > 5) {
      throw const FormatException('Malformed Street Scrap chapter progress.');
    }
    if (chapter < 1) throw StateError('recyclingClassificationLocked');
    if (state['recyclingSamplesClaimed'] == true) {
      throw StateError('recyclingSamplesAlreadyClaimed');
    }
    final rawInventory = state['inventory'];
    final inventory = rawInventory == null
        ? catalog.emptyInventory(grids: grids)
        : rawInventory is Map
        ? catalog.inventoryFromJson(
            grids: grids,
            json: Map<String, Object?>.from(rawInventory),
          )
        : throw const FormatException('Malformed Street Scrap inventory.');
    var next = inventory;
    for (final sample in streetScrapRecyclingTutorialSamples.entries) {
      final instanceId = sample.key;
      if (next.objects.containsKey(instanceId)) {
        throw const FormatException('Duplicate chapter-1 recycling sample.');
      }
      next = next.addAndPlaceFirstFit(
        catalog.createObject(
          instanceId: instanceId,
          itemId: sample.value,
          source: 'tutorial:recycling-sample',
          quality: 55,
          traits: const {},
        ),
        backpackGridId,
      );
    }
    return StreetScrapReduction(
      state: {
        ...state,
        'inventory': next.toJson(),
        'recyclingSamplesClaimed': true,
      },
      result: {'sampleCount': streetScrapRecyclingCategories.length},
    );
  },
);

/// Gives the q1.02 guaranteed sewing supplies once, and only after q1.01.
/// The rag and thread have source identities so crafting can protect them for
/// their intended lesson steps.
Future<StreetScrapCommandResult> claimStreetScrapSewingTutorialKit({
  required StreetScrapSession session,
  required String commandId,
  required int expectedRevision,
  required StreetScrapInventoryCatalog catalog,
  required Map<String, StreetScrapGridSpec> grids,
  required String backpackGridId,
}) => session.apply(
  commandId: commandId,
  expectedRevision: expectedRevision,
  reduce: (state) {
    final chapter = state['chapter'] ?? 0;
    final rawTasks = state['tutorialTasks'];
    if (chapter is! int ||
        chapter < 1 ||
        chapter > 5 ||
        rawTasks is! Map ||
        rawTasks['q1.01'] != true) {
      throw StateError('sewingTutorialKitLocked');
    }
    if (state['q1.02KitClaimed'] == true) {
      throw StateError('sewingTutorialKitAlreadyClaimed');
    }
    final rawInventory = state['inventory'];
    final inventory = rawInventory == null
        ? catalog.emptyInventory(grids: grids)
        : rawInventory is Map
        ? catalog.inventoryFromJson(
            grids: grids,
            json: Map<String, Object?>.from(rawInventory),
          )
        : throw const FormatException('Malformed Street Scrap inventory.');
    var next = inventory;
    final supplies = [
      ('q1-kit-rag', 'cloth.rag_piece', 'tutorial:q1.02-rag', null),
      ('q1-kit-thread', 'cloth.thread_end', 'tutorial:q1.02-thread', null),
      ('q1-kit-needle', 'tool.needle', 'tutorial:q1.02-needle', null),
    ];
    for (final supply in supplies) {
      final (instanceId, itemId, source, durability) = supply;
      if (next.objects.containsKey(instanceId)) {
        throw const FormatException('Duplicate q1.02 tutorial supply.');
      }
      next = next.addAndPlaceFirstFit(
        catalog.createObject(
          instanceId: instanceId,
          itemId: itemId,
          source: source,
          quality: 55,
          traits: const {},
          toolDurability: durability,
        ),
        backpackGridId,
      );
    }
    return StreetScrapReduction(
      state: {...state, 'inventory': next.toJson(), 'q1.02KitClaimed': true},
      result: {'supplyCount': supplies.length},
    );
  },
);

/// Saves a correctable sorting decision for a phase-1 sample. Wrong answers
/// remain visible and can be reassigned; once a category is correctly sorted,
/// that task progress survives later movement or use of the sample.
Future<StreetScrapCommandResult> classifyStreetScrapRecyclingSample({
  required StreetScrapSession session,
  required String commandId,
  required int expectedRevision,
  required StreetScrapInventoryCatalog catalog,
  required Map<String, StreetScrapGridSpec> grids,
  required String backpackGridId,
  required String instanceId,
  required String category,
}) => session.apply(
  commandId: commandId,
  expectedRevision: expectedRevision,
  reduce: (state) {
    final chapter = state['chapter'] ?? 0;
    if (chapter is! int || chapter < 0 || chapter > 5) {
      throw const FormatException('Malformed Street Scrap chapter progress.');
    }
    if (chapter < 1) throw StateError('recyclingClassificationLocked');
    if (!streetScrapRecyclingCategories.containsKey(category)) {
      throw ArgumentError.value(category, 'category');
    }
    final rawInventory = state['inventory'];
    if (rawInventory is! Map) throw StateError('recyclingSampleUnavailable');
    final inventory = catalog.inventoryFromJson(
      grids: grids,
      json: Map<String, Object?>.from(rawInventory),
    );
    final sample = inventory.objects[instanceId];
    final placement = inventory.placements[instanceId];
    if (sample == null ||
        placement?.gridId != backpackGridId ||
        streetScrapRecyclingCategoryForItem(sample.itemId) == null) {
      throw StateError('recyclingSampleUnavailable');
    }
    final rawClassifications = state['recyclingClassifications'];
    if (rawClassifications != null && rawClassifications is! Map) {
      throw const FormatException('Malformed recycling classifications.');
    }
    final classifications = <String, Object?>{
      if (rawClassifications is Map)
        ...Map<String, Object?>.from(rawClassifications),
      instanceId: category,
    };
    final rawSorted = state['recyclingSortedCategories'];
    if (rawSorted != null &&
        (rawSorted is! List ||
            rawSorted.any(
              (entry) =>
                  entry is! String ||
                  !streetScrapRecyclingCategories.containsKey(entry),
            ))) {
      throw const FormatException('Malformed sorted recycling categories.');
    }
    final correctTutorialCategories = <String>{
      for (final entry in streetScrapRecyclingTutorialSamples.entries)
        if (classifications[entry.key] ==
            streetScrapRecyclingCategoryForItem(entry.value))
          streetScrapRecyclingCategoryForItem(entry.value)!,
    };
    final completed = streetScrapRecyclingTutorialSamples.entries.every(
      (entry) =>
          classifications[entry.key] ==
          streetScrapRecyclingCategoryForItem(entry.value),
    );
    final rawTasks = state['tutorialTasks'];
    if (rawTasks != null && rawTasks is! Map) {
      throw const FormatException('Malformed tutorial task progress.');
    }
    final tasks = <String, Object?>{
      if (rawTasks is Map) ...Map<String, Object?>.from(rawTasks),
    };
    final rawStations = state['unlockedStations'];
    if (rawStations != null &&
        (rawStations is! List ||
            rawStations.any((entry) => entry is! String))) {
      throw const FormatException('Malformed unlocked stations.');
    }
    final stations = <String>{
      if (rawStations is List) ...rawStations.cast<String>(),
    };
    if (completed) {
      tasks['q1.01'] = true;
      stations.add('recycler');
    }
    return StreetScrapReduction(
      state: {
        ...state,
        'recyclingClassifications': classifications,
        'recyclingSortedCategories': correctTutorialCategories.toList()..sort(),
        'tutorialTasks': tasks,
        'unlockedStations': stations.toList()..sort(),
      },
      result: {
        'instanceId': instanceId,
        'category': category,
        'correctCount': correctTutorialCategories.length,
        'completed': completed,
      },
    );
  },
);

/// Records the chapter-1 intact-material lesson as either keep or hand-in.
/// Only a metal-sheet or board found at the fixed recycling rack is eligible;
/// hand-in and quest/index unlock commit together.
Future<StreetScrapCommandResult> chooseStreetScrapIntactMaterial({
  required StreetScrapSession session,
  required String commandId,
  required int expectedRevision,
  required StreetScrapInventoryCatalog catalog,
  required Map<String, StreetScrapGridSpec> grids,
  required String instanceId,
  required String choice,
}) => session.apply(
  commandId: commandId,
  expectedRevision: expectedRevision,
  reduce: (state) {
    final rawTasks = state['tutorialTasks'];
    if (rawTasks is! Map || rawTasks['q1.02'] != true) {
      throw StateError('intactMaterialLessonLocked');
    }
    if (rawTasks['q1.03'] == true) {
      throw StateError('intactMaterialLessonComplete');
    }
    if (choice != 'keep' && choice != 'deliver') {
      throw ArgumentError.value(choice, 'choice');
    }
    final rawInventory = state['inventory'];
    if (rawInventory is! Map) throw StateError('intactMaterialUnavailable');
    final inventory = catalog.inventoryFromJson(
      grids: grids,
      json: Map<String, Object?>.from(rawInventory),
    );
    final item = inventory.objects[instanceId];
    final placement = inventory.placements[instanceId];
    if (item == null ||
        placement == null ||
        item.source != 'fixed:metal_recycling_rack' ||
        !const {'metal.sheet', 'wood.board'}.contains(item.itemId)) {
      throw StateError('intactMaterialUnavailable');
    }
    final nextInventory = choice == 'deliver'
        ? inventory.consumeFromGrid([instanceId], placement.gridId)
        : inventory;
    final rawIndexes = state['unlockedIndexes'];
    if (rawIndexes != null &&
        (rawIndexes is! List || rawIndexes.any((entry) => entry is! String))) {
      throw const FormatException('Malformed unlocked material indexes.');
    }
    final indexes = <String>{
      if (rawIndexes is List) ...rawIndexes.cast<String>(),
      'material_use_index',
    }.toList()..sort();
    final tasks = Map<String, Object?>.from(rawTasks)..['q1.03'] = true;
    final unlockedFishingSpots = <String>{
      if (state['unlockedFishingSpots'] is List)
        ...(state['unlockedFishingSpots'] as List).whereType<String>(),
      'dock_entrance',
    }.toList()..sort();
    return StreetScrapReduction(
      state: {
        ...state,
        'chapter': 2,
        'inventory': nextInventory.toJson(),
        'tutorialTasks': tasks,
        'q1.03Choice': choice,
        'unlockedIndexes': indexes,
        'unlockedFishingSpots': unlockedFishingSpots,
      },
      result: {
        'choice': choice,
        'itemId': item.itemId,
        'instanceId': instanceId,
        'materialUseIndexUnlocked': true,
        'chapterUnlocked': 2,
        'fishingSpotUnlocked': 'dock_entrance',
      },
    );
  },
);

/// Explicitly discards one returned item only after the caller has shown the
/// concrete object and received confirmation. Its result cannot be rerolled.
Future<StreetScrapCommandResult> discardStreetScrapExpeditionReward({
  required StreetScrapSession session,
  required String commandId,
  required int expectedRevision,
  required StreetScrapExpeditionRules rules,
  required int rewardIndex,
}) => session.apply(
  commandId: commandId,
  expectedRevision: expectedRevision,
  reduce: (state) {
    final raw = state['expedition'];
    if (raw is! Map) throw StateError('No expedition reward to discard.');
    final expedition = StreetScrapExpedition.fromJson(
      Map<String, Object?>.from(raw),
    );
    expedition.validateAgainst(rules);
    if (!expedition.returned ||
        expedition.claimed ||
        rewardIndex < 0 ||
        rewardIndex >= expedition.pendingRewards.length) {
      throw StateError('Expedition reward is not discardable.');
    }
    final discarded = expedition.pendingRewards[rewardIndex];
    final remaining = List<Map<String, Object?>>.of(expedition.pendingRewards)
      ..removeAt(rewardIndex);
    final next = expedition._copy(
      pendingRewards: remaining,
      discardedCount: expedition.discardedCount + 1,
    );
    return StreetScrapReduction(
      state: {...state, 'expedition': next.toJson()},
      result: discarded,
    );
  },
);
