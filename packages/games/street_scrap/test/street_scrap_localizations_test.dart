import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taiwan_brawl_game_street_scrap/src/street_scrap_localizations.dart';

void main() {
  test('recipe success summaries match their actual container effects', () {
    expect(
      streetScrapRecipeSuccessMessageKey(
        station: 'recycler',
        stateEffectType: 'transformContainers',
        hasOutputs: true,
      ),
      'recipe.successWithContainers',
    );
    expect(
      streetScrapRecipeSuccessMessageKey(
        station: 'kitchen',
        stateEffectType: 'transformContainers',
        hasOutputs: false,
      ),
      'recipe.successMeal',
    );
    expect(
      streetScrapRecipeSuccessMessageKey(
        station: 'kitchen',
        stateEffectType: 'transformContainers',
        hasOutputs: true,
      ),
      'recipe.successWithContainers',
    );
    expect(
      const StreetScrapLocalizations(
        'zh-Hant',
      ).text('recipe.successWithContainers', arguments: {'outputs': '紙漿 × 1'}),
      '成功結果：產出 紙漿 × 1；保留所選容器',
    );
    expect(
      const StreetScrapLocalizations('en').text(
        'recipe.successWithContainers',
        arguments: {'outputs': 'Pulp × 1'},
      ),
      'On success: produces Pulp × 1 and retains the selected container',
    );
  });

  test(
    'uses Traditional Chinese as the default and unknown-locale fallback',
    () {
      expect(
        const StreetScrapLocalizations('zh-Hant').text('entry.loaded'),
        '本機存檔已載入',
      );
      expect(
        const StreetScrapLocalizations('ja-JP').text('entry.loaded'),
        '本機存檔已載入',
      );
    },
  );

  test('supports English and interpolates package-owned copy', () {
    expect(
      const StreetScrapLocalizations('en-US').text('entry.loaded'),
      'Local save loaded',
    );
    expect(
      const StreetScrapLocalizations('en').text(
        'packing.contents',
        arguments: {
          'count': '3',
          'input': 'Wood chips',
          'output': 'Wood-chip bundle',
        },
      ),
      'These 3 Wood chips will be packed into Wood-chip bundle:',
    );
    expect(
      const StreetScrapLocalizations('en').text(
        'board.ownerLocation',
        arguments: {'grid': 'Work Board', 'x': '2', 'y': '3'},
      ),
      'Work Board (2, 3)',
    );
    expect(
      const StreetScrapLocalizations('en').text(
        'entry.progressVersion',
        arguments: {'revision': '4', 'savedAt': 'today'},
      ),
      'Progress revision 4; last saved today',
    );
    expect(
      const StreetScrapLocalizations('en').text('recipeIndex.title'),
      'Recipe Index',
    );
    expect(
      const StreetScrapLocalizations('en').recipeDisplayName(
        operationId: 'cut',
        inputItemId: 'cloth.rag_piece',
        outputItemId: 'cloth.edge_scrap',
      ),
      'Cut: Rag piece → Cloth offcut',
    );
    expect(
      const StreetScrapLocalizations('zh-Hant').recipeDisplayName(
        operationId: 'cut',
        inputItemId: 'cloth.rag_piece',
        outputItemId: 'cloth.edge_scrap',
      ),
      '切製・破布片 → 布邊料',
    );
    expect(
      const StreetScrapLocalizations(
        'en',
      ).recipeDisplayName(operationId: 'wash', inputItemId: 'cloth.edge_scrap'),
      'Clean: Cloth offcut',
    );
    expect(
      const StreetScrapLocalizations('en').text(
        'craft.dialog.materialQuality',
        arguments: {
          'name': 'Wood chip',
          'source': 'Found (original material)',
          'quality': '72',
        },
      ),
      'Wood chip · Found (original material) · quality 72',
    );
    expect(
      const StreetScrapLocalizations('en').text(
        'craft.dialog.selectedCount',
        arguments: {'name': 'Wood chip', 'selected': '1', 'required': '2'},
      ),
      'Wood chip: selected 1 / 2',
    );
    expect(
      const StreetScrapLocalizations(
        'en',
      ).text('craft.result.missed', arguments: {'quality': '54'}),
      'Missed; resolved by the recipe · quality 54.',
    );
    expect(
      const StreetScrapLocalizations(
        'en',
      ).text('recipeIndex.phaseProgress', arguments: {'phase': '3'}),
      'Available through Phase 3. Locked recipes still show their unlock phase.',
    );
    expect(
      const StreetScrapLocalizations('en').text('materialUses.title'),
      'Material Sources and Uses',
    );
    expect(
      const StreetScrapLocalizations('en').text(
        'materialUses.producedBy',
        arguments: {'recipes': 'ss.recipe.board'},
      ),
      'Found / made by: ss.recipe.board',
    );
    expect(
      const StreetScrapLocalizations(
        'en',
      ).text('recipe.failure', arguments: {'outcome': 'lower quality'}),
      'On a miss: lower quality',
    );
    expect(
      const StreetScrapLocalizations('en').text('water.confirmDiscardTitle'),
      'Discard the bottle contents?',
    );
    expect(
      const StreetScrapLocalizations('en').text('water.confirmDiscardBody'),
      'Only the selected container will be emptied; the container and its grid position will remain.',
    );
    expect(
      const StreetScrapLocalizations('en').text('water.errorSourceLocked'),
      'This water source is still locked.',
    );
    expect(
      const StreetScrapLocalizations('zh-Hant').text('water.errorStamina'),
      '體力不足，未改變水瓶。',
    );
    expect(
      const StreetScrapLocalizations(
        'en',
      ).text('craft.error.operationMalformed'),
      'The saved crafting progress is malformed. No materials were changed.',
    );
    expect(
      const StreetScrapLocalizations(
        'en',
      ).text('craft.error.recipeVersionUnavailable'),
      'The recipe version used by this operation is unavailable. Materials remain locked.',
    );
    expect(
      const StreetScrapLocalizations('en').text(
        'craft.error.questLocked',
        arguments: {
          'quest': const StreetScrapLocalizations(
            'en',
          ).text('recipe.questPrerequisite.pressRod'),
        },
      ),
      'This recipe unlocks after the wood-press tutorial materials are claimed.',
    );
    expect(
      const StreetScrapLocalizations('en').text(
        'recipes.questLocked',
        arguments: {
          'quest': const StreetScrapLocalizations(
            'en',
          ).text('recipe.questPrerequisite.pressRod'),
        },
      ),
      'Locked until the wood-press tutorial materials are claimed',
    );
  });

  test(
    'chapter 2 through 5 tutorial checklist is localized in both languages',
    () {
      const keys = [
        'expedition.phaseTwo',
        'expedition.phaseThree',
        'expedition.phaseFour',
        'expedition.phaseFive',
        'expedition.task.castLine',
        'expedition.task.landFish',
        'expedition.task.chooseFishUse',
        'expedition.task.pressRod',
        'expedition.task.nailBoard',
        'expedition.task.repairTool',
        'expedition.task.storeCrate',
        'expedition.task.upgradeBagOptional',
        'expedition.task.filterWater',
        'expedition.task.cookMeal',
        'expedition.task.useOrDeliverMeal',
        'expedition.task.advancedOrders',
        'expedition.task.stableLiving',
      ];
      for (final locale in ['zh-Hant', 'en']) {
        final strings = StreetScrapLocalizations(locale);
        for (final key in keys) {
          expect(strings.text(key), isNot(key), reason: '$locale: $key');
        }
      }
      expect(
        const StreetScrapLocalizations(
          'zh-Hant',
        ).text('expedition.task.advancedOrders'),
        '完成五種生產器各一張進階委託',
      );
      expect(
        const StreetScrapLocalizations(
          'en',
        ).text('expedition.task.stableLiving'),
        'Place the shelter and reinforced chest, then complete 5 regular cycle orders',
      );
    },
  );

  test('localizes item IDs across categories and preserves future IDs', () {
    expect(
      const StreetScrapLocalizations('zh-Hant').itemName('wood.board'),
      '木板',
    );
    expect(
      const StreetScrapLocalizations('en').itemName('wood.board'),
      'Wooden board',
    );
    expect(
      const StreetScrapLocalizations('zh-Hant').itemName('water.filtered'),
      '過濾水',
    );
    expect(
      const StreetScrapLocalizations('en').itemName('content:water.distilled'),
      'Distilled water',
    );
    expect(
      const StreetScrapLocalizations('en').itemName('meal.soup_vegetable'),
      'Vegetable soup',
    );
    expect(
      const StreetScrapLocalizations('en').itemName('future.material'),
      'future.material',
    );
    expect(
      const StreetScrapLocalizations('en').itemSource('street-find'),
      'Found (original material)',
    );
    expect(
      const StreetScrapLocalizations('en').itemSource('crafted:press'),
      'Crafted',
    );
    expect(
      const StreetScrapLocalizations('en').itemQuality(72),
      'Quality: Good (72)',
    );
    expect(
      const StreetScrapLocalizations('en').itemQuality(39),
      'Quality: Poor (39)',
    );
    expect(
      const StreetScrapLocalizations('en').itemQuality(40),
      'Quality: Ordinary (40)',
    );
    expect(
      const StreetScrapLocalizations('en').itemQuality(90),
      'Quality: Excellent (90)',
    );
    expect(
      const StreetScrapLocalizations('en').text(
        'board.cellSemantics',
        arguments: {
          'grid': 'Work Board',
          'row': '1',
          'column': '2',
          'state': 'empty',
          'cursor': ', cursor here',
        },
      ),
      'Work Board, row 1, column 2, empty, cursor here',
    );
  });

  test('localizes formal recipe checkpoint prompts and preserves unknown copy', () {
    expect(
      const StreetScrapLocalizations('en').checkpointPrompt('先從哪裡起針？'),
      'Where should the first stitch begin?',
    );
    expect(
      const StreetScrapLocalizations('en-GB').checkpointPrompt('封口前最後檢查什麼？'),
      'What should be checked before sealing?',
    );
    expect(
      const StreetScrapLocalizations('en').checkpointPrompt('校正板件端點'),
      'Align the board ends',
    );
    expect(
      const StreetScrapLocalizations('zh-Hant').checkpointPrompt('先從哪裡起針？'),
      '先從哪裡起針？',
    );
    expect(
      const StreetScrapLocalizations('en').checkpointPrompt('future prompt'),
      'future prompt',
    );
    expect(
      const StreetScrapLocalizations('en').maintenanceTitle('擦拭去鏽'),
      'Rust removal',
    );
    expect(
      const StreetScrapLocalizations('en').text('craft.error.inputMismatch'),
      'The selected materials changed or have the wrong quantity. No materials were consumed.',
    );
    expect(
      const StreetScrapLocalizations('en').text('woodwork.errorCrateUncrafted'),
      'Craft the wooden crate from its recipe first.',
    );
    expect(
      const StreetScrapLocalizations('en').text('woodwork.openRecipes'),
      'Open recipes and manual crafting',
    );
    expect(
      const StreetScrapLocalizations(
        'en',
      ).text('expedition.error.malformedSave'),
      'Exploration data could not be read. Your save is unchanged. Return to game progress and use Save Recovery to inspect available backups.',
    );
    expect(
      const StreetScrapLocalizations('en').text('game.error.malformedSave'),
      'Game save data could not be read. This page is paused to avoid overwriting progress, and the save is unchanged. Return to game progress and use Save Recovery to inspect backups.',
    );
    expect(
      const StreetScrapLocalizations('en').text(
        'maintenance.cost',
        arguments: {
          'material': 'Filtered water',
          'waterCost': '',
          'vesselNote': '',
          'trait': 'Rust',
        },
      ),
      'Cost: 1 Filtered water. The object identity, quality, and position stay unchanged. At least two of three steps must be on target to remove “Rust”.',
    );
  });

  test(
    'localizes recipe operation summaries and safely preserves unknown content',
    () {
      expect(
        const StreetScrapLocalizations('en').operationInstructions('針具／沿縫線拆線'),
        'Needle / unpick along the seam',
      );
      expect(
        const StreetScrapLocalizations(
          'en-GB',
        ).operationInstructions('針具／沿縫線拆線'),
        'Needle / unpick along the seam',
      );
      expect(
        const StreetScrapLocalizations(
          'zh-Hant',
        ).operationInstructions('針具／沿縫線拆線'),
        '針具／沿縫線拆線',
      );
      expect(
        const StreetScrapLocalizations(
          'en',
        ).operationInstructions('future recipe instruction'),
        'future recipe instruction',
      );
      expect(
        const StreetScrapLocalizations('en').stationName('workbench'),
        'Woodworking bench',
      );
      expect(
        const StreetScrapLocalizations('zh-Hant').stationName('dock'),
        '碼頭',
      );
      expect(
        const StreetScrapLocalizations('en').stationName('future_station'),
        'future_station',
      );
    },
  );

  test(
    'localizes recipe quality modes and failure outcomes without changing source content',
    () {
      expect(
        const StreetScrapLocalizations(
          'en',
        ).recipeQualityMode('weighted-primary'),
        'weighted by primary-material quality',
      );
      expect(
        const StreetScrapLocalizations(
          'en-GB',
        ).recipeQualityMode('capped-at-primary'),
        'capped at primary-material quality',
      );
      expect(
        const StreetScrapLocalizations(
          'zh-Hant',
        ).recipeQualityMode('preserve-primary'),
        '保留主材品質',
      );
      expect(
        const StreetScrapLocalizations('en').recipeQualityMode('future-mode'),
        'future-mode',
      );

      const canonicalOutcome = '調味包 1，品質 −10';
      expect(
        const StreetScrapLocalizations(
          'en',
        ).recipeFailureOutcome(canonicalOutcome),
        '1 seasoning pack; quality is reduced by 10.',
      );
      expect(
        const StreetScrapLocalizations(
          'zh-Hant',
        ).recipeFailureOutcome(canonicalOutcome),
        canonicalOutcome,
      );
      expect(
        const StreetScrapLocalizations(
          'en',
        ).recipeFailureOutcome('future outcome'),
        'future outcome',
      );
    },
  );

  test('localizes remaining inventory controls and fishing spot names', () {
    const english = StreetScrapLocalizations('en');
    const traditionalChinese = StreetScrapLocalizations('zh-Hant');
    expect(english.text('common.dismiss'), 'Dismiss');
    expect(english.text('checkpoint.leftZone'), 'Left zone');
    expect(english.text('checkpoint.promptZone'), 'Cue zone');
    expect(english.text('checkpoint.rightZone'), 'Right zone');
    expect(english.text('relief.clockSaveError'), contains('Reopen the game'));
    expect(
      traditionalChinese.text('relief.clockSaveError'),
      contains('重新進入遊戲'),
    );
    expect(
      english.fishingSpotName('dock_entrance', '舊碼頭入口'),
      'Old Dock Entrance',
    );
    expect(
      traditionalChinese.fishingSpotName('dock_entrance', 'old label'),
      '舊碼頭入口',
    );
    expect(
      english.fishingSpotName('future_spot', 'Future Shore'),
      'Future Shore',
    );
  });

  test(
    'localizes the legacy clean-bottle ID without exposing its internal alias',
    () {
      expect(
        const StreetScrapLocalizations('en').itemName('container.bottle_clean'),
        'Clean container',
      );
      expect(
        const StreetScrapLocalizations(
          'zh-Hant',
        ).itemName('content:container.bottle_clean'),
        '清潔容器',
      );
    },
  );

  test('localizes fixed and surprise exploration reward sources safely', () {
    const english = StreetScrapLocalizations('en');
    const traditionalChinese = StreetScrapLocalizations('zh-Hant');
    expect(
      english.expeditionRewardSource('fixed:metal_recycling_rack'),
      'Metal recycling rack',
    );
    expect(
      traditionalChinese.expeditionRewardSource('surprise:commonScraps'),
      '驚喜拾得・常見散料',
    );
    expect(
      english.expeditionRewardSource('fixed:future_location'),
      'Fixed-site find',
    );
    expect(
      english.expeditionRewardSource('surprise:future_category'),
      'Surprise find',
    );
    expect(
      english.expeditionRewardSource('future-source-id'),
      'Scavenged item',
    );
  });

  testWidgets('scope notifies descendants when host locale changes', (
    tester,
  ) async {
    Widget page(String locale) => MaterialApp(
      home: StreetScrapLocalizationsScope(
        locale: locale,
        child: Builder(
          builder: (context) =>
              Text(StreetScrapLocalizations.of(context).text('entry.loaded')),
        ),
      ),
    );

    await tester.pumpWidget(page('zh-Hant'));
    expect(find.text('本機存檔已載入'), findsOneWidget);
    await tester.pumpWidget(page('en'));
    expect(find.text('Local save loaded'), findsOneWidget);
  });
}
