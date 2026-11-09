import 'dart:typed_data';

import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taiwan_brawl_game_street_scrap/street_scrap_content.dart';
import 'package:taiwan_brawl_game_street_scrap/street_scrap_item_sprite.dart';
import 'package:taiwan_brawl_game_street_scrap/src/street_scrap_localizations.dart';

void main() {
  testWidgets('base recycling materials use detailed bundled offline art', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(760, 380);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    const items = [
      'paper.scrap',
      'cloth.rag_piece',
      'metal.scrap',
      'plastic.scrap',
    ];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          backgroundColor: const Color(0xff13211d),
          body: Center(
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final itemId in items)
                  StreetScrapItemSprite(
                    itemId: itemId,
                    source: 'found_native',
                    size: 164,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final images = tester.widgetList<Image>(find.byType(Image));
    expect(images, hasLength(items.length));
    expect(
      images.map((image) => (image.image as AssetImage).assetName),
      containsAll(items.map(streetScrapOfflineFallbackAssetFor)),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('offline material fallback sprites stay visually distinct', (
    tester,
  ) async {
    // Five 160px columns and 120px rows keep bitmap origins on whole pixels.
    // Fractional grid offsets produce CPU-dependent nearest-neighbor sampling.
    tester.view.physicalSize = const Size(832, 3400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final sprites = <({String itemId, String? contentItemId})>[
      (itemId: 'wood.chip', contentItemId: null),
      (itemId: 'wood.sawdust', contentItemId: null),
      (itemId: 'wood.driftwood', contentItemId: null),
      (itemId: 'wood.rod', contentItemId: null),
      (itemId: 'wood.board', contentItemId: null),
      (itemId: 'wood.frame', contentItemId: null),
      (itemId: 'toolpart.handle', contentItemId: null),
      (itemId: 'metal.scrap', contentItemId: null),
      (itemId: 'metal.shard', contentItemId: null),
      (itemId: 'metal.sheet', contentItemId: null),
      (itemId: 'metal.bar', contentItemId: null),
      (itemId: 'metal.wire', contentItemId: null),
      (itemId: 'metal.nail_bundle', contentItemId: null),
      (itemId: 'metal.fastener', contentItemId: null),
      (itemId: 'metal.ferrule', contentItemId: null),
      (itemId: 'metal.hook', contentItemId: null),
      (itemId: 'material.glass_scrap', contentItemId: null),
      (itemId: 'bundle.metal_scrap', contentItemId: null),
      (itemId: 'adhesive.residue', contentItemId: null),
      (itemId: 'adhesive.recycled', contentItemId: null),
      (itemId: 'adhesive.starch_paste', contentItemId: null),
      (itemId: 'material.waterproof_coating', contentItemId: null),
      (itemId: 'material.mud', contentItemId: null),
      (itemId: 'material.charcoal', contentItemId: null),
      (itemId: 'material.mineral_pack', contentItemId: null),
      (itemId: 'material.filter_cloth', contentItemId: null),
      for (final itemId in [
        'paper.scrap',
        'paper.pulp',
        'paper.board',
        'paper.packaging',
        'plastic.scrap',
        'plastic.sheet',
        'plastic.float_part',
        'plastic.seal',
        'bundle.plastic_scrap',
      ])
        (itemId: itemId, contentItemId: null),
      for (final itemId in [
        'fuel.mixed',
        'fuel.dry',
        'fuel.oilcloth',
        'fuel.efficient_pack',
        'tool.needle',
        'tool.paper_mould',
        'tool.awl',
        'tool.crowbar',
        'tool.pliers',
        'tool.kit',
        'tool.rod_basic',
        'tool.rod_repaired',
        'tool.rod_advanced',
        'tool.pot',
        'tool.stove',
        'tool.cook_kit',
        'tool.condenser',
        'toolpart.rig',
        'toolpart.float',
        'bait.basic',
        'bait.herb',
      ])
        (itemId: itemId, contentItemId: null),
      for (final itemId in [
        'container.broken_bottle',
        'container.used_intact',
        'container.clean',
        'container.clean_jar',
        'container.meal_box',
        'container.meal_box_insulated',
        'bag.basic',
        'bag.reinforced',
        'bag.weatherproof',
        'storage.wooden_crate',
        'storage.reinforced_chest',
        'structure.raft',
        'structure.tarp',
        'structure.shelter',
        'bundle.thread_end',
        'bundle.wood_chip',
        'bundle.paper_scrap',
      ])
        (itemId: itemId, contentItemId: null),
      for (final itemId in [
        'fish.raw',
        'fish.meat',
        'fish.bone',
        'fish.pack',
        'food.scrap',
        'food.greens',
        'food.edible',
        'food.cleaned',
        'food.starch',
        'herb.wild',
        'seasoning.salt',
        'seasoning.packet',
        'seasoning.blend',
        'meal.soup_basic',
        'meal.soup_fish',
        'meal.soup_vegetable',
        'meal.shared',
        'meal.failed',
        'meal.relief_box',
      ])
        (itemId: itemId, contentItemId: null),
      (itemId: 'cloth.rag_piece', contentItemId: null),
      (itemId: 'cloth.edge_scrap', contentItemId: null),
      (itemId: 'cloth.repair_strip', contentItemId: null),
      (itemId: 'cloth.patchwork', contentItemId: null),
      (itemId: 'cloth.thread_spool', contentItemId: null),
      (itemId: 'cloth.thread_end', contentItemId: null),
      (itemId: 'cloth.binding', contentItemId: null),
      (itemId: 'rope.coarse', contentItemId: null),
      (itemId: 'line.fishing', contentItemId: null),
      (itemId: 'cloth.waterproof', contentItemId: null),
      (itemId: 'cloth.insulation', contentItemId: null),
      (itemId: 'bundle.cloth_scrap', contentItemId: null),
      (itemId: 'water.turbid', contentItemId: null),
      (itemId: 'water.dirty', contentItemId: null),
      (itemId: 'water.muddy', contentItemId: null),
      (itemId: 'water.filtered', contentItemId: null),
      (itemId: 'water.boiled', contentItemId: null),
      (itemId: 'water.distilled', contentItemId: null),
      (itemId: 'water.mineral', contentItemId: null),
    ];
    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(
          backgroundColor: const Color(0xffe8dfcb),
          body: GridView.count(
            crossAxisCount: 5,
            padding: const EdgeInsets.all(8),
            crossAxisSpacing: 4,
            mainAxisSpacing: 4,
            childAspectRatio: 4 / 3,
            physics: const NeverScrollableScrollPhysics(),
            children: [
              for (final sprite in sprites)
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    StreetScrapItemSprite(
                      itemId: sprite.itemId,
                      source: 'found_native',
                      contentItemId: sprite.contentItemId,
                      size: 48,
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
    expect(find.byType(StreetScrapItemSprite), findsNWidgets(sprites.length));
    await tester.pumpAndSettle();
    final materialContext = tester.element(find.byType(MaterialApp));
    await tester.runAsync(() async {
      final fallbackAssets = sprites
          .map((sprite) => streetScrapOfflineFallbackAssetFor(sprite.itemId))
          .whereType<String>()
          .toSet();
      for (final asset in fallbackAssets) {
        await precacheImage(AssetImage(asset), materialContext);
      }
    });
    await tester.pumpAndSettle();
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('street_scrap_material_fallbacks.png'),
    );
  });

  testWidgets('broken bottle and driftwood use detailed bundled fallback art', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(760, 380);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(
          backgroundColor: const Color(0xff13211d),
          body: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              StreetScrapItemSprite(
                itemId: 'wood.driftwood',
                source: 'found_native',
                size: 288,
              ),
              StreetScrapItemSprite(
                itemId: 'container.broken_bottle',
                source: 'found_native',
                size: 288,
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final bundledImages = tester.widgetList<Image>(find.byType(Image));
    expect(bundledImages, hasLength(2));
    expect(
      bundledImages.map((image) => (image.image as AssetImage).assetName),
      containsAll([
        'packages/taiwan_brawl_game_street_scrap/assets/fallback/driftwood.png',
        'packages/taiwan_brawl_game_street_scrap/assets/fallback/broken_bottle.png',
      ]),
    );
    expect(tester.takeException(), isNull);
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('street_scrap_large_fallback_art.png'),
    );
  });

  testWidgets('material sprite keeps source and contained water accessible', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              StreetScrapItemSprite(
                itemId: 'wood.board',
                source: 'found_native',
              ),
              StreetScrapItemSprite(itemId: 'wood.board', source: 'crafted'),
              StreetScrapItemSprite(
                itemId: 'container.bottle_clean',
                source: 'found_native',
                contentItemId: 'water.muddy',
              ),
            ],
          ),
        ),
      ),
    );

    expect(
      find.byKey(
        const ValueKey('street-scrap-sprite:wood.board:found_native:null'),
      ),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('street-scrap-sprite:wood.board:crafted:null')),
      findsOneWidget,
    );
    expect(find.bySemanticsLabel('木板，原生／拾得'), findsOneWidget);
    expect(find.bySemanticsLabel('木板，加工'), findsOneWidget);
    expect(find.bySemanticsLabel('清潔容器，原生／拾得，內含 泥水'), findsOneWidget);
  });

  testWidgets('screen-reader item labels use localized names and content', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: StreetScrapLocalizationsScope(
          locale: 'en',
          child: const Scaffold(
            body: Column(
              children: [
                StreetScrapItemSprite(
                  itemId: 'wood.board',
                  source: 'found_native',
                ),
                StreetScrapItemSprite(itemId: 'wood.board', source: 'crafted'),
                StreetScrapItemSprite(
                  itemId: 'container.bottle_clean',
                  source: 'found_native',
                  contentItemId: 'water.muddy',
                ),
              ],
            ),
          ),
        ),
      ),
    );

    expect(
      find.bySemanticsLabel('Wooden board, Found (original material)'),
      findsOneWidget,
    );
    expect(find.bySemanticsLabel('Wooden board, Crafted'), findsOneWidget);
    expect(
      find.bySemanticsLabel(
        'Clean container, Found (original material), contains Muddy water',
      ),
      findsOneWidget,
    );
  });

  testWidgets('optional wood-chip bundle sprite renders on the bundle item', (
    tester,
  ) async {
    final bytes = (await tester.runAsync(
      () => File(
        'resources/art/street-scrap-art-wood-chip-bundle-v0.1.0.png',
      ).readAsBytes(),
    ))!;
    await tester.pumpWidget(
      StreetScrapLocalizationsScope(
        locale: 'en',
        child: MaterialApp(
          home: Scaffold(
            body: StreetScrapItemSprite(
              itemId: 'bundle.wood_chip',
              source: 'crafted:bundle.wood_chip',
              woodChipBundleSpriteBytes: bytes,
            ),
          ),
        ),
      ),
    );
    expect(find.byType(Image), findsOneWidget);
    expect(find.bySemanticsLabel('Wood-chip bundle, Crafted'), findsOneWidget);
  });

  testWidgets(
    'food-expanded material atlas PNG renders distinct cells through row twelve',
    (tester) async {
      final atlas = await tester.runAsync(() async {
        final bytes = await File(
          'resources/art/street-scrap-art-material-atlas-v0.3.0.png',
        ).readAsBytes();
        final codec = await ui.instantiateImageCodec(bytes);
        final frame = await codec.getNextFrame();
        final rgba = (await frame.image.toByteData(
          format: ui.ImageByteFormat.rawRgba,
        ))!.buffer.asUint8List();
        frame.image.dispose();
        codec.dispose();
        return (
          bytes: bytes,
          width: frame.image.width,
          height: frame.image.height,
          rgba: rgba,
        );
      });
      expect(atlas, isNotNull);
      final decodedAtlas = atlas!;
      expect(decodedAtlas.width, 768);
      expect(decodedAtlas.height, 2304);
      expect(
        decodedAtlas.rgba[3],
        0,
        reason: 'atlas padding stays transparent',
      );

      List<int> sampleCell(int cell) {
        final x0 = (cell % 4) * 192;
        final y0 = (cell ~/ 4) * 192;
        final sample = <int>[];
        for (var y = y0 + 4; y < y0 + 188; y += 8) {
          for (var x = x0 + 4; x < x0 + 188; x += 8) {
            final offset = (y * decodedAtlas.width + x) * 4;
            sample.addAll(decodedAtlas.rgba.skip(offset).take(4));
          }
        }
        return sample;
      }

      final nativeCell = sampleCell(0);
      final craftedCell = sampleCell(1);
      final muddyBottleCell = sampleCell(13);
      final woodChipsCell = sampleCell(16);
      final patchworkCell = sampleCell(22);
      final nailsCell = sampleCell(25);
      final filteredWaterCell = sampleCell(30);
      final fishCell = sampleCell(32);
      final fishMeatCell = sampleCell(33);
      final fishBoneCell = sampleCell(34);
      final vegetableSoupCell = sampleCell(47);
      expect(nativeCell, isNot(equals(craftedCell)));
      expect(nativeCell, isNot(equals(muddyBottleCell)));
      expect(craftedCell, isNot(equals(muddyBottleCell)));
      expect(woodChipsCell, isNot(equals(patchworkCell)));
      expect(patchworkCell, isNot(equals(nailsCell)));
      expect(nailsCell, isNot(equals(filteredWaterCell)));
      expect(fishCell, isNot(equals(fishMeatCell)));
      expect(fishMeatCell, isNot(equals(fishBoneCell)));
      expect(fishBoneCell, isNot(equals(vegetableSoupCell)));

      Widget sprite(String itemId, String source, {String? content}) =>
          StreetScrapItemSprite(
            itemId: itemId,
            source: source,
            size: 48,
            contentItemId: content,
            materialAtlasBytes: decodedAtlas.bytes,
          );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Row(
              children: [
                sprite('wood.board', 'found_native'),
                sprite('wood.board', 'crafted'),
                sprite(
                  'container.bottle_clean',
                  'found_native',
                  content: 'water.muddy',
                ),
                sprite('wood.chip', 'found_native'),
                sprite(
                  'container.bottle_clean',
                  'found_native',
                  content: 'water.filtered',
                ),
                sprite('fish.meat', 'crafted:fillet_fish'),
                sprite('meal.soup_vegetable', 'crafted:soup_vegetable'),
              ],
            ),
          ),
        ),
      );
      await tester.pump();
      expect(find.byType(Image), findsNWidgets(7));
      expect(
        tester
            .widgetList<Image>(find.byType(Image))
            .every(
              (image) =>
                  image.image is MemoryImage &&
                  (image.image as MemoryImage).bytes.length ==
                      decodedAtlas.bytes.length,
            ),
        isTrue,
      );
      expect(tester.takeException(), isNull);
    },
  );

  test('validates the optional native wood-board sprite resource', () async {
    final bytes = await File(
      'resources/art/street-scrap-art-v0.1.0.png',
    ).readAsBytes();
    await validateStreetScrapArtBytes(bytes);
    expect(bytes.length, lessThan(1024 * 1024));
  });

  test('validates the optional thread-spool sprite resource', () async {
    final bytes = await File(
      'resources/art/street-scrap-art-thread-spool-v0.1.0.png',
    ).readAsBytes();
    await validateStreetScrapArtBytes(bytes);
    expect(bytes.length, lessThan(1024 * 1024));
  });

  test('validates the optional mineral-pack sprite resource', () async {
    final bytes = await File(
      'resources/art/street-scrap-art-mineral-pack-v0.1.0.png',
    ).readAsBytes();
    await validateStreetScrapArtBytes(bytes);
    expect(bytes.length, lessThan(1024 * 1024));
  });

  test('validates the optional wood-chip bundle sprite resource', () async {
    final bytes = await File(
      'resources/art/street-scrap-art-wood-chip-bundle-v0.1.0.png',
    ).readAsBytes();
    await validateStreetScrapArtBytes(bytes);
    expect(bytes, hasLength(237875));
    expect(bytes.length, lessThan(1024 * 1024));
  });

  test('validates the previous optional 4x4 material atlas revision', () async {
    final bytes = await File(
      'resources/art/street-scrap-art-material-atlas-v0.1.0.png',
    ).readAsBytes();
    await validateStreetScrapMaterialAtlasBytes(bytes);
    expect(bytes.length, lessThan(1024 * 1024));
  });

  test('validates the expanded 4x8 material atlas revision', () async {
    final bytes = await File(
      'resources/art/street-scrap-art-material-atlas-v0.2.0.png',
    ).readAsBytes();
    await validateStreetScrapMaterialAtlasBytes(bytes);
    expect(bytes.length, lessThan(2 * 1024 * 1024));
    expect(streetScrapMaterialAtlasRows(bytes), 8);
  });

  test(
    'validates the 4x12 food-expanded atlas and its 16 added item cells',
    () async {
      final bytes = await File(
        'resources/art/street-scrap-art-material-atlas-v0.3.0.png',
      ).readAsBytes();
      await validateStreetScrapMaterialAtlasBytes(bytes);
      expect(bytes.length, lessThan(2 * 1024 * 1024));
      expect(streetScrapMaterialAtlasRows(bytes), 12);
      expect(
        [
          'fish.raw',
          'fish.meat',
          'fish.bone',
          'fish.pack',
          'food.scrap',
          'food.greens',
          'food.edible',
          'food.cleaned',
          'food.starch',
          'herb.wild',
          'seasoning.salt',
          'seasoning.packet',
          'seasoning.blend',
          'meal.soup_basic',
          'meal.soup_fish',
          'meal.soup_vegetable',
        ].map(
          (itemId) => streetScrapMaterialAtlasCellFor(
            itemId: itemId,
            source: 'crafted:test',
            atlasRows: 12,
          ),
        ),
        List<int>.generate(16, (index) => index + 32),
      );
    },
  );

  test(
    'validates the 4x12 food-expanded atlas and its 16 added item cells',
    () async {
      final bytes = await File(
        'resources/art/street-scrap-art-material-atlas-v0.3.0.png',
      ).readAsBytes();
      await validateStreetScrapMaterialAtlasBytes(bytes);
      expect(bytes.length, lessThan(2 * 1024 * 1024));
      expect(streetScrapMaterialAtlasRows(bytes), 12);
      expect(
        [
          'fish.raw',
          'fish.meat',
          'fish.bone',
          'fish.pack',
          'food.scrap',
          'food.greens',
          'food.edible',
          'food.cleaned',
          'food.starch',
          'herb.wild',
          'seasoning.salt',
          'seasoning.packet',
          'seasoning.blend',
          'meal.soup_basic',
          'meal.soup_fish',
          'meal.soup_vegetable',
        ].map(
          (itemId) => streetScrapMaterialAtlasCellFor(
            itemId: itemId,
            source: 'crafted:test',
            atlasRows: 12,
          ),
        ),
        List<int>.generate(16, (index) => index + 32),
      );
    },
  );

  test(
    'tool atlas is compact, validated and maps all 16 item sprites',
    () async {
      final bytes = await File(
        'resources/art/street-scrap-art-tool-atlas-v0.1.0.png',
      ).readAsBytes();
      await validateStreetScrapToolAtlasBytes(bytes);
      expect(bytes.length, lessThan(1024 * 1024));
      expect(
        [
          'tool.needle',
          'tool.paper_mould',
          'tool.awl',
          'tool.crowbar',
          'tool.pliers',
          'tool.kit',
          'tool.rod_basic',
          'tool.rod_advanced',
          'tool.pot',
          'tool.stove',
          'tool.cook_kit',
          'tool.condenser',
          'toolpart.rig',
          'toolpart.float',
          'bait.basic',
          'bait.herb',
        ].map(streetScrapToolAtlasCellFor).toList(),
        List<int>.generate(16, (index) => index),
      );
      expect(streetScrapToolAtlasCellFor('water.filtered'), isNull);
    },
  );

  test(
    'paper, plastic and fuel atlas validates and maps 16 material sprites',
    () async {
      final bytes = await File(
        'resources/art/street-scrap-art-material-pack-v0.1.0.png',
      ).readAsBytes();
      await validateStreetScrapMaterialPackArtBytes(bytes);
      expect(bytes.length, lessThan(2 * 1024 * 1024));
      expect(
        [
          'paper.scrap',
          'paper.pulp',
          'paper.board',
          'paper.packaging',
          'plastic.scrap',
          'plastic.sheet',
          'plastic.float_part',
          'plastic.seal',
          'bundle.plastic_scrap',
          'fuel.mixed',
          'fuel.dry',
          'fuel.oilcloth',
          'fuel.efficient_pack',
          'material.glass_scrap',
          'material.filter_cloth',
          'material.waterproof_coating',
        ].map(streetScrapPaperPlasticFuelAtlasCellFor).toList(),
        List<int>.generate(16, (index) => index),
      );
      expect(streetScrapPaperPlasticFuelAtlasCellFor('water.filtered'), isNull);
    },
  );

  testWidgets(
    'installed paper, plastic and fuel atlas renders its mapped cells',
    (tester) async {
      final bytes = (await tester.runAsync(
        () => File(
          'resources/art/street-scrap-art-material-pack-v0.1.0.png',
        ).readAsBytes(),
      ))!;
      await tester.pumpWidget(
        StreetScrapLocalizationsScope(
          locale: 'en',
          child: MaterialApp(
            home: Scaffold(
              body: Row(
                children: [
                  for (final itemId in [
                    'paper.scrap',
                    'plastic.float_part',
                    'fuel.efficient_pack',
                    'material.waterproof_coating',
                  ])
                    StreetScrapItemSprite(
                      itemId: itemId,
                      source: 'found_native',
                      size: 48,
                      materialPackArtBytes: bytes,
                    ),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      final images = tester.widgetList<Image>(find.byType(Image)).toList();
      expect(images, hasLength(4));
      expect(
        images.every(
          (image) =>
              image.image is MemoryImage &&
              (image.image as MemoryImage).bytes.length == bytes.length,
        ),
        isTrue,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('installed tool atlas renders fishing and cooking sprites', (
    tester,
  ) async {
    final bytes = (await tester.runAsync(
      () => File(
        'resources/art/street-scrap-art-tool-atlas-v0.1.0.png',
      ).readAsBytes(),
    ))!;
    await tester.pumpWidget(
      StreetScrapLocalizationsScope(
        locale: 'en',
        child: MaterialApp(
          home: Scaffold(
            body: Row(
              children: [
                for (final itemId in [
                  'tool.needle',
                  'tool.rod_basic',
                  'tool.stove',
                  'bait.herb',
                ])
                  StreetScrapItemSprite(
                    itemId: itemId,
                    source: 'found_native',
                    size: 48,
                    toolAtlasBytes: bytes,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    final images = tester.widgetList<Image>(find.byType(Image)).toList();
    expect(images, hasLength(4));
    expect(
      images.every(
        (image) =>
            image.image is MemoryImage &&
            (image.image as MemoryImage).bytes.length == bytes.length,
      ),
      isTrue,
    );
    expect(tester.takeException(), isNull);
  });

  test(
    'material atlas maps provenance and contained water to distinct cells',
    () {
      expect(
        streetScrapMaterialAtlasCellFor(
          itemId: 'wood.board',
          source: 'found_native',
        ),
        0,
      );
      expect(
        streetScrapMaterialAtlasCellFor(
          itemId: 'wood.board',
          source: 'crafted:ss.recipe.nail_board',
        ),
        1,
      );
      expect(
        streetScrapMaterialAtlasCellFor(
          itemId: 'container.bottle_clean',
          source: 'found_native',
          contentItemId: 'water.muddy',
        ),
        13,
      );
      expect(
        streetScrapMaterialAtlasCellFor(
          itemId: 'container.bottle_clean',
          source: 'found_native',
        ),
        12,
      );
      expect(
        streetScrapMaterialAtlasCellFor(
          itemId: 'container.used_intact',
          source: 'found_native',
        ),
        isNull,
      );
      expect(
        streetScrapMaterialAtlasCellFor(
          itemId: 'container.meal_box_insulated',
          source: 'found_native',
        ),
        isNull,
      );
      for (final water in [
        'water.turbid',
        'water.dirty',
        'water.filtered',
        'water.boiled',
        'water.distilled',
        'water.mineral',
      ]) {
        expect(
          streetScrapMaterialAtlasCellFor(
            itemId: 'container.bottle_clean',
            source: 'found_native',
            contentItemId: water,
          ),
          isNull,
          reason: '$water needs its own offline-rendered liquid state',
        );
      }
    },
  );

  test('all seven water variants have distinct offline palette colors', () {
    final colors = [
      'water.turbid',
      'water.dirty',
      'water.muddy',
      'water.filtered',
      'water.boiled',
      'water.distilled',
      'water.mineral',
    ].map(streetScrapWaterColorFor).toSet();
    expect(colors, hasLength(7));
  });

  test('expanded atlas maps additional materials and bottle states', () {
    const atlasRows = 8;
    const expectedCells = <String, int>{
      'wood.chip': 16,
      'wood.sawdust': 17,
      'wood.driftwood': 18,
      'wood.rod': 19,
      'wood.frame': 20,
      'cloth.edge_scrap': 21,
      'cloth.patchwork': 22,
      'cloth.thread_end': 23,
      'cloth.binding': 24,
      'metal.nail_bundle': 25,
      'metal.fastener': 26,
      'adhesive.recycled': 27,
    };
    for (final entry in expectedCells.entries) {
      expect(
        streetScrapMaterialAtlasCellFor(
          itemId: entry.key,
          source: 'found_native',
          atlasRows: atlasRows,
        ),
        entry.value,
      );
    }
    const waterCells = <String, int>{
      'water.muddy': 28,
      'water.dirty': 29,
      'water.filtered': 30,
      'water.boiled': 31,
    };
    for (final entry in waterCells.entries) {
      expect(
        streetScrapMaterialAtlasCellFor(
          itemId: 'container.bottle_clean',
          source: 'found_native',
          contentItemId: entry.key,
          atlasRows: atlasRows,
        ),
        entry.value,
      );
    }
    expect(
      streetScrapMaterialAtlasCellFor(
        itemId: 'wood.chip',
        source: 'found_native',
        atlasRows: 4,
      ),
      isNull,
      reason: 'the legacy atlas must use its offline fallback for new items',
    );
    expect(
      streetScrapMaterialAtlasCellFor(
        itemId: 'container.bottle_clean',
        source: 'found_native',
        contentItemId: 'water.mineral',
        atlasRows: atlasRows,
      ),
      isNull,
      reason: 'unmapped water stays on its distinct built-in fallback',
    );
  });

  test('wood processing chain has distinct offline material silhouettes', () {
    final woodGlyphs = {
      'wood.chip': streetScrapWoodGlyphFor('wood.chip'),
      'bundle.wood_chip': streetScrapWoodGlyphFor('bundle.wood_chip'),
      'wood.sawdust': streetScrapWoodGlyphFor('wood.sawdust'),
      'wood.driftwood': streetScrapWoodGlyphFor('wood.driftwood'),
      'wood.rod': streetScrapWoodGlyphFor('wood.rod'),
      'wood.board': streetScrapWoodGlyphFor('wood.board'),
      'wood.frame': streetScrapWoodGlyphFor('wood.frame'),
      'toolpart.handle': streetScrapWoodGlyphFor('toolpart.handle'),
    };
    expect(woodGlyphs.values.toSet(), hasLength(8));
    expect(woodGlyphs['wood.chip'], 'chips');
    expect(woodGlyphs['wood.sawdust'], 'sawdust');
    expect(woodGlyphs['wood.driftwood'], 'driftwood');
    expect(woodGlyphs['wood.rod'], 'rod');
    expect(woodGlyphs['wood.frame'], 'frame');
  });

  test(
    'cloth, thread and cord materials have distinct offline silhouettes',
    () {
      final clothGlyphs = {
        for (final itemId in [
          'cloth.rag_piece',
          'cloth.edge_scrap',
          'cloth.repair_strip',
          'cloth.patchwork',
          'cloth.thread_spool',
          'cloth.thread_end',
          'cloth.binding',
          'rope.coarse',
          'line.fishing',
          'cloth.waterproof',
          'cloth.insulation',
          'material.filter_cloth',
          'bundle.cloth_scrap',
        ])
          itemId: streetScrapClothGlyphFor(itemId),
      };
      expect(clothGlyphs.values.toSet(), hasLength(13));
      expect(streetScrapClothGlyphFor('bundle.thread_end'), 'looseThread');
      expect(clothGlyphs['cloth.thread_spool'], 'spool');
      expect(clothGlyphs['line.fishing'], 'fishingLine');
      expect(clothGlyphs['rope.coarse'], 'rope');
      expect(clothGlyphs['cloth.waterproof'], 'waterproof');
    },
  );

  test('metal parts and glass have distinct offline material silhouettes', () {
    final metalGlyphs = {
      for (final itemId in [
        'metal.scrap',
        'metal.shard',
        'metal.sheet',
        'metal.bar',
        'metal.wire',
        'metal.nail_bundle',
        'metal.fastener',
        'metal.ferrule',
        'metal.hook',
        'material.glass_scrap',
        'bundle.metal_scrap',
      ])
        itemId: streetScrapMetalGlyphFor(itemId),
    };
    expect(metalGlyphs.values.toSet(), hasLength(11));
    expect(metalGlyphs['metal.nail_bundle'], 'nails');
    expect(metalGlyphs['metal.hook'], 'hook');
    expect(metalGlyphs['material.glass_scrap'], 'glass');
  });

  test('recipe utility materials have distinct offline glyphs', () {
    final utilityGlyphs = {
      for (final itemId in [
        'adhesive.residue',
        'adhesive.recycled',
        'adhesive.starch_paste',
        'material.waterproof_coating',
        'material.mud',
        'material.charcoal',
        'material.mineral_pack',
      ])
        itemId: streetScrapUtilityGlyphFor(itemId),
    };
    expect(utilityGlyphs.values.toSet(), hasLength(7));
    expect(utilityGlyphs['adhesive.residue'], 'residue');
    expect(utilityGlyphs['adhesive.recycled'], 'recycledGlue');
    expect(utilityGlyphs['material.charcoal'], 'charcoal');
  });

  test(
    'fish, ingredients, seasonings and meals have distinct offline glyphs',
    () {
      final foodGlyphs = {
        for (final itemId in [
          'fish.raw',
          'fish.meat',
          'fish.bone',
          'fish.pack',
          'food.scrap',
          'food.greens',
          'food.edible',
          'food.cleaned',
          'food.starch',
          'herb.wild',
          'seasoning.salt',
          'seasoning.packet',
          'seasoning.blend',
          'meal.soup_basic',
          'meal.soup_fish',
          'meal.soup_vegetable',
          'meal.shared',
          'meal.failed',
          'meal.relief_box',
        ])
          itemId: streetScrapFoodGlyphFor(itemId),
      };
      expect(foodGlyphs.values.toSet(), hasLength(19));
      expect(foodGlyphs['fish.raw'], 'wholeFish');
      expect(foodGlyphs['fish.bone'], 'fishBone');
      expect(foodGlyphs['meal.relief_box'], 'reliefMeal');
    },
  );

  test('paper and plastic recipe materials have distinct offline glyphs', () {
    final paperGlyphs = {
      for (final itemId in [
        'paper.scrap',
        'bundle.paper_scrap',
        'paper.pulp',
        'paper.board',
        'paper.packaging',
      ])
        itemId: streetScrapPaperGlyphFor(itemId),
    };
    final plasticGlyphs = {
      for (final itemId in [
        'plastic.scrap',
        'plastic.sheet',
        'plastic.float_part',
        'plastic.seal',
        'bundle.plastic_scrap',
      ])
        itemId: streetScrapPlasticGlyphFor(itemId),
    };
    expect(paperGlyphs.values.toSet(), hasLength(5));
    expect(paperGlyphs['bundle.paper_scrap'], 'paperBundle');
    expect(plasticGlyphs.values.toSet(), hasLength(5));
    expect(streetScrapPlasticGlyphFor('bundle.plastic_scrap'), 'plasticBundle');
  });

  test(
    'fuel has distinct offline glyphs for material state and efficiency',
    () {
      final glyphs = {
        for (final itemId in [
          'fuel.mixed',
          'fuel.dry',
          'fuel.oilcloth',
          'fuel.efficient_pack',
        ])
          itemId: streetScrapFuelGlyphFor(itemId),
      };
      expect(glyphs.values.toSet(), hasLength(4));
    },
  );

  test('tools, fishing parts and baits have distinct offline glyphs', () {
    final glyphs = {
      for (final itemId in [
        'tool.needle',
        'tool.paper_mould',
        'tool.awl',
        'tool.crowbar',
        'tool.pliers',
        'tool.kit',
        'tool.rod_basic',
        'tool.rod_repaired',
        'tool.rod_advanced',
        'tool.pot',
        'tool.stove',
        'tool.cook_kit',
        'tool.condenser',
        'toolpart.rig',
        'toolpart.float',
        'bait.basic',
        'bait.herb',
      ])
        itemId: streetScrapToolGlyphFor(itemId),
    };
    expect(glyphs.values.toSet(), hasLength(17));
    expect(glyphs['tool.rod_repaired'], 'repairedRod');
    expect(glyphs['toolpart.float'], 'float');
    expect(glyphs['bait.herb'], 'herbBait');
  });

  test('containers, bags, storage and structures have distinct glyphs', () {
    final containerGlyphs = {
      for (final itemId in [
        'container.broken_bottle',
        'container.used_intact',
        'container.clean',
        'container.clean_jar',
        'container.meal_box',
        'container.meal_box_insulated',
      ])
        itemId: streetScrapContainerGlyphFor(itemId),
    };
    final storageGlyphs = {
      for (final itemId in [
        'bag.basic',
        'bag.reinforced',
        'bag.weatherproof',
        'storage.wooden_crate',
        'storage.reinforced_chest',
      ])
        itemId: streetScrapStorageGlyphFor(itemId),
    };
    final structureGlyphs = {
      for (final itemId in [
        'structure.raft',
        'structure.tarp',
        'structure.shelter',
      ])
        itemId: streetScrapStructureGlyphFor(itemId),
    };
    expect(containerGlyphs.values.toSet(), hasLength(6));
    expect(storageGlyphs.values.toSet(), hasLength(5));
    expect(structureGlyphs.values.toSet(), hasLength(3));
  });

  testWidgets(
    'native wood selects the optional image while crafted wood falls back',
    (tester) async {
      late Widget nativeSprite;
      late Widget craftedSprite;
      late Widget nativeThreadSpool;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              nativeSprite = StreetScrapItemSprite(
                itemId: 'wood.board',
                source: 'fixed:recovery-rack',
                woodBoardSpriteBytes: Uint8List.fromList([1]),
              ).build(context);
              craftedSprite = StreetScrapItemSprite(
                itemId: 'wood.board',
                source: 'crafted:ss.recipe.nail_board',
              ).build(context);
              nativeThreadSpool = StreetScrapItemSprite(
                itemId: 'cloth.thread_spool',
                source: 'found_native',
                threadSpoolSpriteBytes: Uint8List.fromList([1]),
              ).build(context);
              return const SizedBox.shrink();
            },
          ),
        ),
      );
      final nativeBox =
          ((nativeSprite as Semantics).child! as ExcludeSemantics).child!
              as SizedBox;
      final craftedBox =
          ((craftedSprite as Semantics).child! as ExcludeSemantics).child!
              as SizedBox;
      final threadSpoolBox =
          ((nativeThreadSpool as Semantics).child! as ExcludeSemantics).child!
              as SizedBox;
      expect(nativeBox.child, isA<Image>());
      expect(craftedBox.child, isA<CustomPaint>());
      expect(threadSpoolBox.child, isA<Image>());
    },
  );
}
