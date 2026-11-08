import 'street_scrap_inventory.dart';
import 'street_scrap_progress.dart';

/// A resumable three-checkpoint maintenance action. It uses the same saved
/// reservation boundary as crafting, but produces no new grid object.
class StreetScrapMaintenance {
  static const rustOperationRecipeId = 'maintenance.remove_rust';
  static const operationRecipeId = rustOperationRecipeId;
  static const _profiles = <StreetScrapTraitMaintenanceProfile>[
    StreetScrapTraitMaintenanceProfile(
      recipeId: 'maintenance.remove_frayed',
      traitId: 'frayed',
      acceptedPrefixes: ['cloth.', 'rope.'],
      auxiliaryItemId: 'cloth.thread_spool',
      operationId: 'sew',
      title: '補線修整',
      prompts: ['固定磨損纖維', '補入完整線材', '收緊並檢查接縫'],
    ),
    StreetScrapTraitMaintenanceProfile(
      recipeId: 'maintenance.remove_damp',
      traitId: 'damp',
      acceptedPrefixes: ['wood.', 'paper.'],
      auxiliaryItemId: 'fuel.dry',
      operationId: 'heat',
      title: '乾燥處理',
      prompts: ['控制初段熱度', '維持均勻乾燥', '避免過熱收尾'],
    ),
    StreetScrapTraitMaintenanceProfile(
      recipeId: rustOperationRecipeId,
      traitId: 'rusted',
      acceptedPrefixes: ['metal.'],
      auxiliaryItemId: 'cloth.edge_scrap',
      waterItemId: 'water.filtered',
      operationId: 'wash',
      title: '擦拭去鏽',
      prompts: ['以過濾水潤濕布邊料', '沿鏽斑方向擦拭', '以乾淨布面收尾'],
    ),
    StreetScrapTraitMaintenanceProfile(
      recipeId: 'maintenance.remove_brittle',
      traitId: 'brittle',
      acceptedPrefixes: ['plastic.'],
      auxiliaryItemId: 'fuel.dry',
      operationId: 'heat',
      title: '重新熱整',
      prompts: ['均勻預熱塑料', '控制熱壓區間', '平穩冷卻收尾'],
    ),
    StreetScrapTraitMaintenanceProfile(
      recipeId: 'maintenance.remove_smoky',
      traitId: 'smoky',
      acceptedPrefixes: ['fuel.'],
      auxiliaryItemId: 'paper.scrap',
      operationId: 'heat',
      title: '重新乾燥燃料',
      prompts: ['移除表面煙垢', '控制乾燥熱度', '確認燃料狀態'],
    ),
    StreetScrapTraitMaintenanceProfile(
      recipeId: 'maintenance.remove_joint_skewed',
      traitId: 'joint_skewed',
      acceptedItemIds: ['wood.board'],
      auxiliaryItemId: 'metal.nail_bundle',
      operationId: 'align',
      title: '重新定位木板',
      prompts: ['校正板件端點', '對準偏斜接縫', '固定定位'],
    ),
  ];

  static StreetScrapTraitMaintenanceProfile? profileForRecipeId(String id) {
    for (final profile in _profiles) {
      if (profile.recipeId == id) return profile;
    }
    return null;
  }

  static StreetScrapTraitMaintenanceProfile? profileForTarget(
    StreetScrapObject item,
  ) {
    final profiles = profilesForTarget(item);
    return profiles.isEmpty ? null : profiles.first;
  }

  static List<StreetScrapTraitMaintenanceProfile> profilesForTarget(
    StreetScrapObject item,
  ) {
    final profiles = <StreetScrapTraitMaintenanceProfile>[];
    for (final profile in _profiles) {
      if (item.traits[profile.traitId] == true &&
          profile.accepts(item.itemId)) {
        profiles.add(profile);
      }
    }
    return List.unmodifiable(profiles);
  }

  static Future<StreetScrapCommandResult> beginRustRemoval({
    required StreetScrapSession session,
    required StreetScrapInventoryCatalog catalog,
    required Map<String, StreetScrapGridSpec> grids,
    required String gridId,
    required String metalInstanceId,
    required String clothScrapInstanceId,
    required String filteredWaterVesselInstanceId,
    required String operationId,
    required String commandId,
    required int expectedRevision,
  }) => beginTraitMaintenance(
    session: session,
    catalog: catalog,
    grids: grids,
    gridId: gridId,
    profile: _profiles[2],
    targetInstanceId: metalInstanceId,
    auxiliaryInstanceId: clothScrapInstanceId,
    waterVesselInstanceId: filteredWaterVesselInstanceId,
    operationId: operationId,
    commandId: commandId,
    expectedRevision: expectedRevision,
  );

  static Future<StreetScrapCommandResult> beginTraitMaintenance({
    required StreetScrapSession session,
    required StreetScrapInventoryCatalog catalog,
    required Map<String, StreetScrapGridSpec> grids,
    required String gridId,
    required StreetScrapTraitMaintenanceProfile profile,
    required String targetInstanceId,
    required String auxiliaryInstanceId,
    String? waterVesselInstanceId,
    required String operationId,
    required String commandId,
    required int expectedRevision,
  }) => session.apply(
    commandId: commandId,
    expectedRevision: expectedRevision,
    reduce: (state) {
      final canonicalProfile = profileForRecipeId(profile.recipeId);
      if (canonicalProfile == null) {
        throw StateError('maintenanceProfileUnknown');
      }
      if (canonicalProfile.prompts.length != 3) {
        throw StateError('maintenanceProfileInvalid');
      }
      if ((state['chapter'] as int? ?? 0) < 3) {
        throw StateError('maintenanceLocked');
      }
      if (state['craftOperation'] != null) {
        throw StateError('craftOperationActive');
      }
      final raw = state['inventory'];
      if (raw is! Map) throw StateError('inventoryMissing');
      final inventory = catalog.inventoryFromJson(
        grids: grids,
        json: Map<String, Object?>.from(raw),
      );
      StreetScrapObject requirePlaced(String id) {
        final item = inventory.objects[id];
        if (item == null ||
            item.containerContents.isNotEmpty ||
            inventory.placements[id]?.gridId != gridId) {
          throw StateError('rustMaintenanceInputUnavailable');
        }
        return item;
      }

      final target = requirePlaced(targetInstanceId);
      final auxiliary = requirePlaced(auxiliaryInstanceId);
      final vessel = waterVesselInstanceId == null
          ? null
          : requirePlaced(waterVesselInstanceId);
      if (operationId.trim().isEmpty ||
          {
                targetInstanceId,
                auxiliaryInstanceId,
                ?waterVesselInstanceId,
              }.length !=
              (waterVesselInstanceId == null ? 2 : 3)) {
        throw ArgumentError('Maintenance selections must be distinct.');
      }
      if (!canonicalProfile.accepts(target.itemId) ||
          target.traits[canonicalProfile.traitId] != true) {
        throw StateError('maintenanceTargetInvalid');
      }
      if (auxiliary.itemId != canonicalProfile.auxiliaryItemId) {
        throw StateError('maintenanceAuxiliaryRequired');
      }
      if ((canonicalProfile.waterItemId == null) != (vessel == null)) {
        throw StateError('maintenanceWaterRequired');
      }
      if (vessel != null &&
          (!const {
                'container.clean',
                'container.clean_jar',
                'container.used_intact',
              }.contains(vessel.itemId) ||
              vessel.containerState['contentItemId'] !=
                  canonicalProfile.waterItemId ||
              !const {
                'clean',
                'utility',
              }.contains(vessel.containerState['cleanliness']))) {
        throw StateError('maintenanceWaterRequired');
      }
      final locked = [
        targetInstanceId,
        auxiliaryInstanceId,
        ?waterVesselInstanceId,
      ];
      return StreetScrapReduction(
        state: {
          ...state,
          'craftOperation': {
            'operationId': operationId,
            'recipeId': canonicalProfile.recipeId,
            'rulesetVersion': session.rulesetVersion,
            'gridId': gridId,
            'targetInstanceId': targetInstanceId,
            'traitId': canonicalProfile.traitId,
            'auxiliaryInstanceId': auxiliaryInstanceId,
            'waterVesselInstanceId': waterVesselInstanceId,
            'lockedInstanceIds': locked,
            'answers': const <int>[],
            'status': 'inProgress',
          },
        },
        result: {'operationId': operationId, 'status': 'inProgress'},
      );
    },
  );

  static Future<StreetScrapCommandResult?> answerRustCheckpoint({
    required StreetScrapSession session,
    required StreetScrapInventoryCatalog catalog,
    required Map<String, StreetScrapGridSpec> grids,
    required String operationId,
    required int optionIndex,
    required int expectedRevision,
  }) => answerMaintenanceCheckpoint(
    session: session,
    catalog: catalog,
    grids: grids,
    operationId: operationId,
    optionIndex: optionIndex,
    expectedRevision: expectedRevision,
  );

  static Future<StreetScrapCommandResult?> answerMaintenanceCheckpoint({
    required StreetScrapSession session,
    required StreetScrapInventoryCatalog catalog,
    required Map<String, StreetScrapGridSpec> grids,
    required String operationId,
    required int optionIndex,
    required int expectedRevision,
  }) async {
    final raw = session.snapshot.state['craftOperation'];
    if (raw is! Map ||
        raw['operationId'] != operationId ||
        profileForRecipeId(raw['recipeId'] as String? ?? '') == null ||
        raw['rulesetVersion'] != session.rulesetVersion) {
      throw StateError('maintenanceOperationChanged');
    }
    final answers = raw['answers'];
    if (answers is! List ||
        answers.any((answer) => answer is! int) ||
        answers.length >= 3 ||
        optionIndex < 0 ||
        optionIndex > 2) {
      throw StateError('rustMaintenanceCheckpointInvalid');
    }
    final nextAnswers = [...answers.cast<int>(), optionIndex];
    await session.apply(
      commandId: 'checkpoint-$operationId-${answers.length}',
      expectedRevision: expectedRevision,
      reduce: (state) {
        final current = state['craftOperation'];
        if (current is! Map ||
            current['operationId'] != operationId ||
            current['recipeId'] != raw['recipeId'] ||
            (current['answers'] as List).length != answers.length) {
          throw StateError('maintenanceOperationChanged');
        }
        return StreetScrapReduction(
          state: {
            ...state,
            'craftOperation': {
              ...Map<String, Object?>.from(current),
              'answers': nextAnswers,
              'status': nextAnswers.length == 3
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
    if (nextAnswers.length < 3) return null;
    return settleMaintenance(
      session: session,
      catalog: catalog,
      grids: grids,
      operationId: operationId,
    );
  }

  static Future<StreetScrapCommandResult?> resumeRustRemoval({
    required StreetScrapSession session,
    required StreetScrapInventoryCatalog catalog,
    required Map<String, StreetScrapGridSpec> grids,
  }) => resumeMaintenance(session: session, catalog: catalog, grids: grids);

  static Future<StreetScrapCommandResult?> resumeMaintenance({
    required StreetScrapSession session,
    required StreetScrapInventoryCatalog catalog,
    required Map<String, StreetScrapGridSpec> grids,
  }) {
    final raw = session.snapshot.state['craftOperation'];
    if (raw is! Map ||
        profileForRecipeId(raw['recipeId'] as String? ?? '') == null ||
        raw['operationId'] is! String) {
      return Future.value(null);
    }
    final operationId = raw['operationId'] as String;
    if (raw['status'] == 'readyToClear') {
      return _clear(session, operationId).then((_) => null);
    }
    if (raw['status'] != 'readyToSettle' ||
        raw['answers'] is! List ||
        (raw['answers'] as List).length != 3) {
      return Future.value(null);
    }
    return settleMaintenance(
      session: session,
      catalog: catalog,
      grids: grids,
      operationId: operationId,
    );
  }

  static Future<void> cancelRustRemoval({
    required StreetScrapSession session,
    required String operationId,
    required int expectedRevision,
  }) => cancelMaintenance(
    session: session,
    operationId: operationId,
    expectedRevision: expectedRevision,
  );

  static Future<void> cancelMaintenance({
    required StreetScrapSession session,
    required String operationId,
    required int expectedRevision,
  }) async {
    await session.apply(
      commandId: 'cancel-craft-$operationId',
      expectedRevision: expectedRevision,
      reduce: (state) {
        final operation = state['craftOperation'];
        if (operation is! Map ||
            operation['operationId'] != operationId ||
            profileForRecipeId(operation['recipeId'] as String? ?? '') ==
                null ||
            (operation['answers'] as List).isNotEmpty) {
          throw StateError('maintenanceAlreadyIrreversible');
        }
        return StreetScrapReduction(
          state: {...state}..remove('craftOperation'),
          result: {'operationId': operationId, 'cancelled': true},
        );
      },
    );
  }

  static Future<StreetScrapCommandResult> settleRustRemoval({
    required StreetScrapSession session,
    required StreetScrapInventoryCatalog catalog,
    required Map<String, StreetScrapGridSpec> grids,
    required String operationId,
  }) => settleMaintenance(
    session: session,
    catalog: catalog,
    grids: grids,
    operationId: operationId,
  );

  static Future<StreetScrapCommandResult> settleMaintenance({
    required StreetScrapSession session,
    required StreetScrapInventoryCatalog catalog,
    required Map<String, StreetScrapGridSpec> grids,
    required String operationId,
  }) async {
    final operation = session.snapshot.state['craftOperation'];
    final profile = operation is Map
        ? profileForRecipeId(operation['recipeId'] as String? ?? '')
        : null;
    if (operation is! Map ||
        operation['operationId'] != operationId ||
        profile == null ||
        operation['status'] != 'readyToSettle' ||
        operation['rulesetVersion'] != session.rulesetVersion ||
        operation['answers'] is! List ||
        (operation['answers'] as List).length != 3 ||
        (operation['answers'] as List).any(
          (answer) => answer is! int || answer < 0 || answer > 2,
        )) {
      throw StateError('maintenanceOperationIncomplete');
    }
    final points = (operation['answers'] as List)
        .where((answer) => answer == 1)
        .length;
    final succeeded = points >= 2;
    return session
        .apply(
          commandId: 'settle-craft-$operationId',
          expectedRevision: session.snapshot.revision,
          reduce: (state) {
            final current = state['craftOperation'];
            if (current is! Map ||
                current['operationId'] != operationId ||
                current['recipeId'] != profile.recipeId ||
                current['status'] != 'readyToSettle') {
              throw StateError('maintenanceOperationChanged');
            }
            final rawInventory = state['inventory'];
            if (rawInventory is! Map) throw StateError('inventoryMissing');
            final inventory = catalog.inventoryFromJson(
              grids: grids,
              json: Map<String, Object?>.from(rawInventory),
            );
            final gridId = current['gridId']! as String;
            final targetId = current['targetInstanceId']! as String;
            final auxiliaryId = current['auxiliaryInstanceId']! as String;
            final vesselId = current['waterVesselInstanceId'] as String?;
            final target = inventory.objects[targetId];
            final auxiliary = inventory.objects[auxiliaryId];
            final vessel = vesselId == null
                ? null
                : inventory.objects[vesselId];
            final inputIds = [
              targetId,
              auxiliaryId,
              ?vesselId,
            ];
            if (target == null ||
                auxiliary == null ||
                (vesselId != null && vessel == null) ||
                inputIds.any(
                  (id) => inventory.placements[id]?.gridId != gridId,
                ) ||
                !profile.accepts(target.itemId) ||
                target.traits[profile.traitId] != true ||
                auxiliary.itemId != profile.auxiliaryItemId ||
                (profile.waterItemId == null) != (vessel == null) ||
                (vessel != null &&
                    (vessel.containerState['contentItemId'] !=
                            profile.waterItemId ||
                        !const {
                          'clean',
                          'utility',
                        }.contains(vessel.containerState['cleanliness'])))) {
              throw StateError('maintenanceInputsChanged');
            }
            var nextInventory = inventory.consumeFromGrid([
              auxiliaryId,
            ], gridId);
            if (vessel != null && vesselId != null) {
              nextInventory = nextInventory.withContainerState(vesselId, {
                'cleanliness': 'clean',
                'lastContentItemId': profile.waterItemId,
                if (vessel.containerState['contentQuality'] != null)
                  'lastContentQuality': vessel.containerState['contentQuality'],
              });
            }
            if (succeeded) {
              nextInventory = nextInventory.withTraits(
                targetId,
                Map<String, Object?>.of(target.traits)..remove(profile.traitId),
              );
            }
            nextInventory = nextInventory.appendProvenanceEvent(
              instanceId: targetId,
              relatedInputs: [auxiliary, ?vessel],
              event: {
                'eventId': 'maintenance:$operationId',
                'kind': 'transform',
                'recipeId': profile.recipeId,
                'revision': session.snapshot.revision + 1,
                'outcome': succeeded ? 'success' : 'failure',
                'inputs': [target, auxiliary, ?vessel]
                    .map(
                      (item) => {
                        'instanceId': item.instanceId,
                        'itemId': item.itemId,
                        'source': item.source,
                        'quality': item.quality,
                        'traits': item.traits,
                        if (item.instanceId == vesselId)
                          'contentItemId': profile.waterItemId,
                      },
                    )
                    .toList(growable: false),
              },
            );
            return StreetScrapReduction(
              state: {
                ...state,
                'inventory': nextInventory.toJson(),
                'craftOperation': {
                  ...Map<String, Object?>.from(current),
                  'status': 'readyToClear',
                  'result': {
                    'succeeded': succeeded,
                    'targetInstanceId': targetId,
                    'traitId': profile.traitId,
                    'manualPoints': points,
                  },
                },
              },
              result: {
                'succeeded': succeeded,
                'targetInstanceId': targetId,
                'traitId': profile.traitId,
                'manualPoints': points,
                'consumedAuxiliary': auxiliaryId,
                if (profile.waterItemId != null)
                  'consumedWater': profile.waterItemId,
                'vesselInstanceId': vesselId,
              },
            );
          },
        )
        .then((result) async {
          await _clear(session, operationId);
          return result;
        });
  }

  static Future<void> _clear(
    StreetScrapSession session,
    String operationId,
  ) async {
    await session.apply(
      commandId: 'clear-craft-$operationId',
      expectedRevision: session.snapshot.revision,
      reduce: (state) {
        final operation = state['craftOperation'];
        if (operation is! Map ||
            operation['operationId'] != operationId ||
            profileForRecipeId(operation['recipeId'] as String? ?? '') ==
                null ||
            operation['status'] != 'readyToClear') {
          throw StateError('maintenanceOperationChanged');
        }
        return StreetScrapReduction(
          state: {...state}..remove('craftOperation'),
          result: operation['result'],
        );
      },
    );
  }
}

class StreetScrapTraitMaintenanceProfile {
  const StreetScrapTraitMaintenanceProfile({
    required this.recipeId,
    required this.traitId,
    this.acceptedPrefixes = const [],
    this.acceptedItemIds = const [],
    required this.auxiliaryItemId,
    this.waterItemId,
    required this.operationId,
    required this.title,
    required this.prompts,
  });

  final String recipeId;
  final String traitId;
  final List<String> acceptedPrefixes;
  final List<String> acceptedItemIds;
  final String auxiliaryItemId;
  final String? waterItemId;
  final String operationId;
  final String title;
  final List<String> prompts;

  bool accepts(String itemId) =>
      acceptedItemIds.contains(itemId) ||
      acceptedPrefixes.any(itemId.startsWith);
}
