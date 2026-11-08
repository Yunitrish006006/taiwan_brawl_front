import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:taiwan_brawl_game_street_scrap/street_scrap_content.dart';
import 'package:taiwan_brawl_game_street_scrap/street_scrap_orders.dart';
import 'package:taiwan_brawl_game_street_scrap/street_scrap_woodworking.dart';

Map<String, Object?> _payload() {
  final items = [
    for (var i = 0; i < 111; i++)
      {
        'id': 'fixture.item.$i',
        'phase': 0,
        'location': 'grid',
        'footprint': [1, 1],
      },
  ];
  items[109]['id'] = 'fish.bone';
  items[110]['id'] = 'wood.driftwood';
  final recipes = [
    for (var i = 0; i < 78; i++)
      {
        'id': 'ss.recipe.fixture.$i',
        'phase': 0,
        'station': 'workbench',
        'operation': {
          'id': 'align',
          'instructions': 'Align the pieces.',
          'durationSeconds': 10,
        },
        'inputGroups': [
          [
            {'item': 'fixture.item.0', 'quantity': 1},
          ],
        ],
        'reusableTools': <Object>[],
        'outputs': [
          {'item': 'fixture.item.1', 'quantity': 1},
        ],
        'quality': {
          'primaryInputs': ['fixture.item.0'],
          'loss': 0,
          'mode': 'weighted-primary',
          'masteryRevision': 1,
        },
        'traitResolution': {
          'inherit': <Object>[],
          'polarity': <String, Object>{},
          'success': <String, Object>{},
          'precise': <String, Object>{},
          'failure': <String, Object>{},
        },
        'qualityTraitEffects': <Object>[],
        'identity': {'retainedInputIds': <String>[]},
        'failure': {
          'trigger': 'operationFailed',
          'mode': 'reducedQualityOutput',
          'outcome': 'Output at reduced quality.',
          'sourceSection': '11.4',
        },
      },
  ];
  return {
    'schemaVersion': 1,
    'gameId': streetScrapModuleId,
    'packId': streetScrapContentResourceId,
    'rulesetVersion': 1,
    'saveSchemaVersion': 1,
    'optionalResource': true,
    'itemDefinitions': items,
    'recipes': recipes,
    'renewableSupplies': <Object>[],
    'toolRepairs': <Object>[],
    'packing': [
      for (var i = 0; i < 8; i++)
        {
          'input': 'fixture.item.${i + 2}',
          'output': 'fixture.item.${i + 20}',
          'count': 4,
          'manualUnpack': true,
        },
    ],
    'limits': {'staminaMax': 60},
    'scavenging': {
      'version': 4,
      'nodeCount': 3,
      'investigationsPerNode': 1,
      'movementCost': 1,
      'investigationCost': 2,
      'fixedWrongQuantity': 1,
      'scrapQualities': [30, 55],
      'intactQualities': [55, 80, 95],
      'surpriseWeights': {
        'commonScraps': 50,
        'intactBase': 25,
        'containers': 15,
        'optionalSpecial': 10,
      },
      'surprisePools': {
        'commonScraps': ['fixture.item.0'],
        'intactBase': ['fixture.item.0'],
        'containers': ['fixture.item.0'],
        'optionalSpecial': [],
      },
      'phaseSurprisePools': {
        for (var phase = 0; phase < 6; phase++)
          '$phase': {
            'commonScraps': ['fixture.item.0'],
            'intactBase': ['fixture.item.0'],
            'containers': ['fixture.item.0'],
            'optionalSpecial': <String>[],
          },
      },
      'fixedLocations': [
        for (var i = 0; i < 3; i++)
          {
            'id': 'node-$i',
            'nodeIndex': i,
            'phase': 0,
            'options': [
              {'item': 'fixture.item.0', 'label': 'fixture', 'quantity': 1},
            ],
          },
      ],
    },
    'fishing': {
      'version': 1,
      'castCost': 3,
      'signalsPerCast': 3,
      'successSignals': 2,
      'perfectSignals': 3,
      'signalHoldMilliseconds': 2000,
      'basePromptWidthPercent': 30,
      'preciseQualityBonus': 8,
      'guaranteeAfterFailures': 2,
      'freeNaturalBait': true,
      'loanerRodAvailable': true,
      'spots': [
        {'id': 'dock_entrance', 'phase': 2, 'name': '舊碼頭入口'},
        {
          'id': 'raft_point',
          'phase': 3,
          'name': 'Raft Point',
          'failureRewards': ['fish.bone', 'wood.driftwood'],
        },
      ],
      'failureRewards': ['fixture.item.0', 'fixture.item.1'],
    },
    'orders': [
      {
        'id': 'ss.order.fixture',
        'phase': 0,
        'acceptedItems': ['fixture.item.0', 'fixture.item.1'],
        'requirementGroups': [
          [
            {'item': 'fixture.item.0', 'quantity': 2},
          ],
          [
            {'item': 'fixture.item.1', 'quantity': 1},
          ],
        ],
        'rejectedItems': <String>[],
        'quantity': 2,
        'reward': {'currency': 'exchangeTickets', 'quantity': 3},
        'countsTowardCycle': true,
        'returnContainer': false,
        'returnedContainerCleanliness': null,
      },
    ],
  };
}

void main() {
  test('parses the versioned optional protagonist art payload', () async {
    final payload = await File(
      'resources/art/street-scrap-protagonist-v0.1.0.json',
    ).readAsBytes();
    final art = StreetScrapProtagonistArt.fromPayload(
      Uint8List.fromList(payload),
    );
    expect(art.idlePng[0], 137);
    expect(art.actionsPng[0], 137);
    expect(ByteData.sublistView(art.idlePng).getUint32(16), 1159);
    expect(ByteData.sublistView(art.actionsPng).getUint32(16), 1884);
  });

  test('rejects mismatched protagonist presentation resource identity', () {
    expect(
      () => StreetScrapProtagonistArt.fromPayload(
        Uint8List.fromList(
          utf8.encode(
            jsonEncode({
              'moduleId': streetScrapModuleId,
              'resourceId': streetScrapProtagonistArtResourceId,
              'version': '9.9.9',
              'schemaVersion': streetScrapProtagonistArtSchemaVersion,
              'idlePngBase64': '',
              'actionsPngBase64': '',
            }),
          ),
        ),
      ),
      throwsFormatException,
    );
  });

  test('base content exposes its chapter 0-4 recipe count independently', () {
    final payload = _payload();
    final itemIds = (payload['itemDefinitions'] as List)
        .map((item) => (item as Map)['id'] as String)
        .toSet();
    final recipes = (payload['recipes'] as List)
        .take(67)
        .map((raw) => StreetScrapRecipe.fromJson(raw as Map, itemIds: itemIds));

    final catalog = StreetScrapRecipeCatalog.fromRecipes(
      recipes,
      expectedCount: 67,
    );

    expect(catalog.recipes, hasLength(67));
  });

  test('content parser accepts retained-object packing recipes', () {
    final payload = _payload();
    final recipes = payload['recipes'] as List;
    final recipe = recipes.first as Map<String, Object?>;
    recipe['outputs'] = <Object>[];
    recipe['identity'] = {
      'retainedInputIds': ['fixture.item.0'],
    };
    recipe['stateEffect'] = {
      'type': 'packObjects',
      'retainedInputIds': ['fixture.item.0'],
      'toItemId': 'fixture.item.1',
      'packingRuleId': 'fixture.item.0',
      'requireEmptyContainerItems': ['fixture.item.0'],
    };
    final firstPackingRule = (payload['packing'] as List).first as Map;
    firstPackingRule['input'] = 'fixture.item.0';
    firstPackingRule['output'] = 'fixture.item.1';
    firstPackingRule['count'] = 1;

    final catalog = StreetScrapRecipeCatalog.fromContentPayload(
      jsonEncode(payload),
    );

    expect(catalog['ss.recipe.fixture.0']!.supportsRetainedPacking, isTrue);
  });

  test(
    'module and optional content versions are stable and independently named',
    () {
      const manifest = StreetScrapGameManifest();
      expect(manifest.toJson()['moduleId'], 'game.street-scrap');
      expect(manifest.toJson()['packageVersion'], '0.1.14');
      expect(manifest.toJson()['platforms'], streetScrapSupportedPlatforms);
      expect(manifest.toJson()['saveSchemaVersion'], 1);
      expect(manifest.toJson()['rulesetVersion'], 1);
      expect(
        manifest.toJson()['optionalArtResourceId'],
        streetScrapArtResourceId,
      );
      expect(manifest.toJson()['optionalArtResourceIds'], [
        streetScrapArtResourceId,
        streetScrapThreadSpoolArtResourceId,
        streetScrapMaterialAtlasResourceId,
        streetScrapMineralPackArtResourceId,
        streetScrapWoodChipBundleArtResourceId,
        streetScrapToolAtlasResourceId,
        streetScrapMaterialPackArtResourceId,
        streetScrapFishingSceneArtResourceId,
        streetScrapProtagonistArtResourceId,
      ]);
      expect(manifest.toJson()['artRevision'], streetScrapArtResourceVersion);
      expect(
        manifest.toJson()['materialAtlasRevision'],
        streetScrapMaterialAtlasResourceVersion,
      );
      expect(streetScrapMaterialAtlasResourceVersion, '0.3.0');
      expect(streetScrapArtSha256, hasLength(64));
      expect(streetScrapWoodChipBundleArtSha256, hasLength(64));
      expect(
        streetScrapContentResourceId,
        'game.street-scrap.content.chapters-0-4',
      );
      expect(streetScrapContentResourceVersion, '0.1.33');
      expect(streetScrapSaveCompatibleBaseContentVersions['0.1.33'], {
        '0.1.31',
        '0.1.32',
      });
      expect(streetScrapChapter5ContentResourceVersion, '0.1.24');
    },
  );

  test('accepts complete versioned content with unique references', () {
    expect(
      () => validateStreetScrapContentPayload(_encode(_payload())),
      returnsNormally,
    );
  });

  test(
    'tool repair catalog reads versioned alternatives and rejects unknown materials',
    () {
      final payload = _payload();
      for (var index = 2; index < 8; index++) {
        (payload['itemDefinitions'] as List)[index]['baseDurability'] = 20;
      }
      (payload['itemDefinitions'] as List)[10]['phase'] = 4;
      (payload['itemDefinitions'] as List)[10]['location'] = 'liquid';
      (payload['itemDefinitions'] as List)[10].remove('footprint');
      payload['toolRepairs'] = [
        {
          'id': 'repair.tool.2',
          'tool': 'fixture.item.2',
          'phase': 3,
          'restoreUses': 10,
          'materialOptions': [
            ['fixture.item.11'],
          ],
        },
        {
          'id': 'repair.precision.2',
          'tool': 'fixture.item.2',
          'phase': 5,
          'restoreUses': 10,
          'materialOptions': [
            ['content:fixture.item.10', 'fixture.item.11'],
          ],
        },
      ];
      final catalog = StreetScrapToolRepairCatalog.fromContentPayload(
        jsonEncode(payload),
      );
      expect(catalog.rules['repair.tool.2']!.materialOptions, [
        ['fixture.item.11'],
      ]);
      expect(catalog.rules['repair.precision.2']!.phase, 5);
      final invalid = _payload();
      for (var index = 2; index < 8; index++) {
        (invalid['itemDefinitions'] as List)[index]['baseDurability'] = 20;
      }
      invalid['toolRepairs'] = [
        {
          'id': 'repair.tool.2',
          'tool': 'fixture.item.2',
          'phase': 3,
          'restoreUses': 10,
          'materialOptions': [
            ['missing.item'],
          ],
        },
      ];
      expect(
        () => StreetScrapToolRepairCatalog.fromContentPayload(
          jsonEncode(invalid),
        ),
        throwsFormatException,
      );
    },
  );

  test(
    'order catalog loads requirements and reward from versioned content',
    () {
      final catalog = StreetScrapOrderCatalog.fromContentPayload(
        _encode(_payload()),
      );
      expect(catalog['ss.order.fixture']!.quantity, 2);
      expect(catalog['ss.order.fixture']!.rewardQuantity, 3);
      expect(catalog['ss.order.fixture']!.countsTowardCycle, isTrue);
      expect(catalog['ss.order.fixture']!.acceptedItems, [
        'fixture.item.0',
        'fixture.item.1',
      ]);
      expect(
        catalog['ss.order.fixture']!.requirementGroups.first.single.quantity,
        2,
      );
    },
  );

  test(
    'content validator accepts returned multi-item containers and rejects a quantity mismatch',
    () {
      final payload = _payload();
      final order = (payload['orders'] as List).single as Map<String, Object?>;
      order
        ..['acceptedItems'] = ['fixture.item.0']
        ..['requirementGroups'] = [
          [
            {'item': 'fixture.item.0', 'quantity': 3},
          ],
        ]
        ..['quantity'] = 3
        ..['returnContainer'] = true
        ..['consumeContainer'] = false
        ..['containerItemId'] = 'fixture.item.2'
        ..['returnedContainerCleanliness'] = 'soiled';

      expect(
        () => validateStreetScrapContentPayload(_encode(payload)),
        returnsNormally,
      );
      final parsed = StreetScrapOrderCatalog.fromContentPayload(
        _encode(payload),
      )['ss.order.fixture']!;
      expect(parsed.returnContainer, isTrue);
      expect(parsed.containerItemId, 'fixture.item.2');
      expect(parsed.requirementGroups.single.single.quantity, 3);

      final malformed = _payload();
      final malformedOrder =
          (malformed['orders'] as List).single as Map<String, Object?>;
      malformedOrder
        ..['acceptedItems'] = ['fixture.item.0']
        ..['requirementGroups'] = [
          [
            {'item': 'fixture.item.0', 'quantity': 2},
          ],
        ]
        ..['quantity'] = 3
        ..['returnContainer'] = true
        ..['consumeContainer'] = false
        ..['containerItemId'] = 'fixture.item.2'
        ..['returnedContainerCleanliness'] = 'soiled';
      expect(
        () => validateStreetScrapContentPayload(_encode(malformed)),
        throwsFormatException,
      );
    },
  );

  test('recipe catalog recognizes declared retained-instance transforms', () {
    final payload = _payload();
    final recipe = (payload['recipes'] as List).first as Map<String, Object?>;
    recipe['outputs'] = <Object>[];
    recipe['identity'] = {
      'retainedInputIds': ['fixture.item.0'],
    };
    recipe['stateEffect'] = {
      'type': 'transformObject',
      'fromItemId': 'fixture.item.0',
      'toItemId': 'fixture.item.1',
      'requireEmptyContainer': true,
    };
    final catalog = StreetScrapRecipeCatalog.fromContentPayload(
      jsonEncode(payload),
    );
    expect(catalog['ss.recipe.fixture.0']!.supportsIdentityTransform, isTrue);
  });

  test(
    'recipe catalog preserves grouped inputs, reusable tools and failure policy',
    () {
      final payload = _payload();
      final recipes = payload['recipes']! as List;
      final first = recipes.first as Map;
      first['inputGroups'] = [
        [
          {'item': 'fixture.item.0', 'quantity': 2},
          {'item': 'fixture.item.1', 'quantity': 1},
        ],
        [
          {'item': 'fixture.item.2', 'quantity': 1},
        ],
      ];
      first['reusableTools'] = ['fixture.item.3'];
      first['failureOutputs'] = [
        {'item': 'fixture.item.4', 'quantity': 1},
      ];
      first['failureResolution'] = {
        'mode': 'sameOutputsQualityLoss',
        'qualityLoss': 10,
        'consumeSelectedInputs': true,
      };
      (first['operation']! as Map)['manualCheckpoints'] = [
        for (var i = 0; i < 3; i++)
          {
            'prompt': 'Checkpoint ${i + 1}',
            'options': ['wrong', 'right'],
            'correctOption': 1,
          },
      ];

      final catalog = StreetScrapRecipeCatalog.fromContentPayload(
        _encode(payload),
      );
      final recipe = catalog['ss.recipe.fixture.0']!;
      expect(catalog.recipes, hasLength(78));
      expect(recipe.inputGroups, hasLength(2));
      expect(recipe.inputGroups.first.map((input) => input.quantity), [2, 1]);
      expect(recipe.reusableTools, ['fixture.item.3']);
      expect(recipe.failureOutcome, 'Output at reduced quality.');
      expect(recipe.failureResolution!.qualityLoss, 10);
      expect(recipe.failureOutputs.single.itemId, 'fixture.item.4');
      expect(recipe.manualCheckpoints, hasLength(3));
      expect(recipe.manualCheckpoints.last.correctOption, 1);
      expect(catalog.availableAtPhase(0), hasLength(78));
      expect(() => recipe.inputGroups.clear(), throwsUnsupportedError);
    },
  );

  test('recipe catalog fails closed on unknown item references', () {
    final payload = _payload();
    final recipe = (payload['recipes']! as List).first as Map;
    (recipe['outputs']! as List).first = {
      'item': 'not.in.catalog',
      'quantity': 1,
    };
    expect(
      () => StreetScrapRecipeCatalog.fromContentPayload(_encode(payload)),
      throwsFormatException,
    );
  });

  test(
    'recipe catalog preserves and validates initial output container state',
    () {
      final payload = _payload();
      final recipe = (payload['recipes']! as List).first as Map;
      final outputItemId = ((recipe['outputs']! as List).first as Map)['item'];
      recipe['outputContainerStates'] = {
        outputItemId: {'cleanliness': 'clean'},
      };

      final catalog = StreetScrapRecipeCatalog.fromContentPayload(
        _encode(payload),
      );
      expect(
        catalog['ss.recipe.fixture.0']!.outputContainerStates[outputItemId],
        {'cleanliness': 'clean'},
      );

      recipe['outputContainerStates'] = {
        outputItemId: {'cleanliness': 'unknown-state'},
      };
      expect(
        () => StreetScrapRecipeCatalog.fromContentPayload(_encode(payload)),
        throwsFormatException,
      );

      recipe['outputContainerStates'] = {
        'missing.output': {'cleanliness': 'clean'},
      };
      expect(
        () => StreetScrapRecipeCatalog.fromContentPayload(_encode(payload)),
        throwsFormatException,
      );
    },
  );

  test(
    'recipe catalog accepts identity-preserving and no-grid-output operations',
    () {
      final payload = _payload();
      final recipe = (payload['recipes']! as List).first as Map;
      recipe['outputs'] = <Object>[];
      (recipe['quality']! as Map)
        ..['primaryInputs'] = <String>[]
        ..['mode'] = 'preserve-primary';
      final catalog = StreetScrapRecipeCatalog.fromContentPayload(
        _encode(payload),
      );
      expect(catalog['ss.recipe.fixture.0']!.outputs, isEmpty);
      expect(catalog['ss.recipe.fixture.0']!.quality.mode, 'preserve-primary');
    },
  );

  test('recipe catalog validates container-content transformations', () {
    final payload = _payload();
    final recipe = (payload['recipes']! as List).first as Map;
    recipe['outputs'] = <Object>[];
    recipe['stateEffect'] = {
      'type': 'transformContainerContent',
      'containerItemId': 'fixture.item.0',
      'fromContentItemId': 'fixture.item.1',
      'toContentItemId': 'fixture.item.2',
    };
    final catalog = StreetScrapRecipeCatalog.fromContentPayload(
      _encode(payload),
    );
    expect(
      catalog['ss.recipe.fixture.0']!.stateEffect!['toContentItemId'],
      'fixture.item.2',
    );

    recipe['stateEffect'] = {
      'type': 'transformContainers',
      'containers': [
        {
          'containerItemId': 'fixture.item.0',
          'requiredContentItemId': 'fixture.item.1',
          'successContentItemId': 'fixture.item.2',
          'failureContentItemId': 'fixture.item.1',
        },
      ],
    };
    final multiple = StreetScrapRecipeCatalog.fromContentPayload(
      _encode(payload),
    );
    expect(
      (multiple['ss.recipe.fixture.0']!.stateEffect!['containers']! as List),
      hasLength(1),
    );

    ((recipe['stateEffect']! as Map)['containers']! as List)[0] = {
      'containerItemId': 'missing.container',
      'requiredContentItemId': 'fixture.item.1',
      'successContentItemId': 'fixture.item.2',
      'failureContentItemId': 'fixture.item.1',
    };
    expect(
      () => StreetScrapRecipeCatalog.fromContentPayload(_encode(payload)),
      throwsFormatException,
    );
  });

  test('content rejects incomplete structured failure deltas', () {
    final payload = _payload();
    final recipe = (payload['recipes']! as List).first as Map;
    recipe['failureResolution'] = {
      'mode': 'sameOutputsQualityLoss',
      'qualityLoss': 10,
      'consumeSelectedInputs': false,
    };
    expect(
      () => validateStreetScrapContentPayload(_encode(payload)),
      throwsFormatException,
    );
  });

  test(
    'rejects wrong game identity, duplicate items, and missing failure branches',
    () {
      final wrongGame = _payload()..['gameId'] = 'game.archery';
      expect(
        () => validateStreetScrapContentPayload(_encode(wrongGame)),
        throwsFormatException,
      );

      final duplicate = _payload();
      final items = duplicate['itemDefinitions']! as List;
      items[1] = items[0];
      expect(
        () => validateStreetScrapContentPayload(_encode(duplicate)),
        throwsFormatException,
      );

      final missingFailure = _payload();
      final recipes = missingFailure['recipes']! as List;
      (recipes.first as Map)['failure'] = <String, Object?>{};
      expect(
        () => validateStreetScrapContentPayload(_encode(missingFailure)),
        throwsFormatException,
      );
    },
  );

  test(
    'rejects a scavenging payload that violates the three-node one-survey cap',
    () {
      final payload = _payload();
      (payload['scavenging']! as Map)['investigationsPerNode'] = 2;
      expect(
        () => validateStreetScrapContentPayload(_encode(payload)),
        throwsFormatException,
      );
    },
  );

  test(
    'rejects fishing rules that drift from the versioned signal contract',
    () {
      final payload = _payload();
      (payload['fishing']! as Map)['signalHoldMilliseconds'] = 500;
      expect(
        () => validateStreetScrapContentPayload(_encode(payload)),
        throwsFormatException,
      );
    },
  );

  test('requires raft fishing spot rewards to be two defined materials', () {
    final missingSpot = _payload();
    (missingSpot['fishing']! as Map)['spots'] = [
      {'id': 'dock_entrance', 'phase': 2, 'name': 'Old Dock'},
    ];
    expect(
      () => validateStreetScrapContentPayload(_encode(missingSpot)),
      throwsFormatException,
    );

    final duplicateReward = _payload();
    final raftSpot =
        ((duplicateReward['fishing']! as Map)['spots'] as List).last as Map;
    raftSpot['failureRewards'] = ['fish.bone', 'fish.bone'];
    expect(
      () => validateStreetScrapContentPayload(_encode(duplicateReward)),
      throwsFormatException,
    );
  });
}

String _encode(Object value) => jsonEncode(value);
