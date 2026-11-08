import 'dart:typed_data';

import 'package:flutter/material.dart';

import 'street_scrap_localizations.dart';

/// A small, offline pixel-art silhouette for the material groups used by the
/// inventory. It is deliberately a renderer fallback, not a replacement for
/// the production atlas described by the art manifest.
class StreetScrapItemSprite extends StatelessWidget {
  const StreetScrapItemSprite({
    super.key,
    required this.itemId,
    required this.source,
    this.size = 32,
    this.visualScale = 1,
    this.contentItemId,
    this.woodBoardSpriteBytes,
    this.threadSpoolSpriteBytes,
    this.materialAtlasBytes,
    this.toolAtlasBytes,
    this.materialPackArtBytes,
    this.mineralPackSpriteBytes,
    this.woodChipBundleSpriteBytes,
  });

  final String itemId;
  final String source;
  final double size;

  /// Enlarges the artwork inside its fixed hit target, useful for visual-first
  /// inventory surfaces where the item silhouette should read at a glance.
  final double visualScale;
  final String? contentItemId;
  final Uint8List? woodBoardSpriteBytes;
  final Uint8List? threadSpoolSpriteBytes;
  final Uint8List? materialAtlasBytes;
  final Uint8List? toolAtlasBytes;
  final Uint8List? materialPackArtBytes;
  final Uint8List? mineralPackSpriteBytes;
  final Uint8List? woodChipBundleSpriteBytes;

  int? get _materialAtlasCell {
    return streetScrapMaterialAtlasCellFor(
      itemId: itemId,
      source: source,
      contentItemId: contentItemId,
      atlasRows: materialAtlasBytes == null
          ? 4
          : streetScrapMaterialAtlasRows(materialAtlasBytes!),
    );
  }

  int? get _toolAtlasCell => streetScrapToolAtlasCellFor(itemId);

  bool get _crafted =>
      source.toLowerCase().contains('crafted') ||
      source.toLowerCase().contains('recycled') ||
      source.contains('加工');

  @override
  Widget build(BuildContext context) {
    final offlineFallbackAsset = streetScrapOfflineFallbackAssetFor(itemId);
    final strings = StreetScrapLocalizations.of(context);
    final label = strings.text(
      contentItemId == null
          ? 'board.spriteSemantics'
          : 'board.spriteSemanticsWithContents',
      arguments: {
        'item': strings.itemName(itemId),
        'source': strings.itemSource(source),
        if (contentItemId != null) 'content': strings.itemName(contentItemId!),
      },
    );
    final Widget artwork;
    if (materialPackArtBytes != null &&
        streetScrapPaperPlasticFuelAtlasCellFor(itemId) != null) {
      artwork = _StreetScrapAtlasCell(
        bytes: materialPackArtBytes!,
        cell: streetScrapPaperPlasticFuelAtlasCellFor(itemId)!,
        size: size,
        rows: 4,
      );
    } else if (materialAtlasBytes != null &&
        _materialAtlasCell != null &&
        _materialAtlasCell! <
            streetScrapMaterialAtlasRows(materialAtlasBytes!) * 4) {
      artwork = _StreetScrapAtlasCell(
        bytes: materialAtlasBytes!,
        cell: _materialAtlasCell!,
        size: size,
        rows: streetScrapMaterialAtlasRows(materialAtlasBytes!),
      );
    } else if (offlineFallbackAsset != null) {
      artwork = Image.asset(
        offlineFallbackAsset,
        fit: BoxFit.contain,
        filterQuality: FilterQuality.none,
        gaplessPlayback: true,
      );
    } else if (toolAtlasBytes != null && _toolAtlasCell != null) {
      artwork = _StreetScrapAtlasCell(
        bytes: toolAtlasBytes!,
        cell: _toolAtlasCell!,
        size: size,
        rows: 4,
      );
    } else if (itemId == 'wood.board' &&
        !_crafted &&
        woodBoardSpriteBytes != null) {
      artwork = Image.memory(
        woodBoardSpriteBytes!,
        fit: BoxFit.contain,
        filterQuality: FilterQuality.none,
        gaplessPlayback: true,
      );
    } else if (itemId == 'cloth.thread_spool' &&
        !_crafted &&
        threadSpoolSpriteBytes != null) {
      artwork = Image.memory(
        threadSpoolSpriteBytes!,
        fit: BoxFit.contain,
        filterQuality: FilterQuality.none,
        gaplessPlayback: true,
      );
    } else if (itemId == 'material.mineral_pack' &&
        mineralPackSpriteBytes != null) {
      artwork = Image.memory(
        mineralPackSpriteBytes!,
        fit: BoxFit.contain,
        filterQuality: FilterQuality.none,
        gaplessPlayback: true,
      );
    } else if (itemId == 'bundle.wood_chip' &&
        woodChipBundleSpriteBytes != null) {
      artwork = Image.memory(
        woodChipBundleSpriteBytes!,
        fit: BoxFit.contain,
        filterQuality: FilterQuality.none,
        gaplessPlayback: true,
      );
    } else {
      artwork = CustomPaint(
        painter: _StreetScrapPixelPainter(
          itemId: itemId,
          contentItemId: contentItemId,
          crafted: _crafted,
        ),
      );
    }
    return Semantics(
      label: label,
      image: true,
      child: ExcludeSemantics(
        child: SizedBox.square(
          key: ValueKey('street-scrap-sprite:$itemId:$source:$contentItemId'),
          dimension: size,
          child: visualScale == 1
              ? artwork
              : Transform.scale(scale: visualScale, child: artwork),
        ),
      ),
    );
  }
}

String? streetScrapOfflineFallbackAssetFor(String itemId) => switch (itemId) {
  'container.broken_bottle' =>
    'packages/taiwan_brawl_game_street_scrap/assets/fallback/broken_bottle.png',
  'container.used_intact' =>
    'packages/taiwan_brawl_game_street_scrap/assets/fallback/old_bottle.png',
  'wood.driftwood' =>
    'packages/taiwan_brawl_game_street_scrap/assets/fallback/driftwood.png',
  'paper.scrap' =>
    'packages/taiwan_brawl_game_street_scrap/assets/fallback/paper_scrap_v1.png',
  'cloth.rag_piece' =>
    'packages/taiwan_brawl_game_street_scrap/assets/fallback/rag_piece_v1.png',
  'metal.scrap' =>
    'packages/taiwan_brawl_game_street_scrap/assets/fallback/metal_scrap_v1.png',
  'plastic.scrap' =>
    'packages/taiwan_brawl_game_street_scrap/assets/fallback/plastic_scrap_v1.png',
  _ => null,
};

int? streetScrapMaterialAtlasCellFor({
  required String itemId,
  required String source,
  String? contentItemId,
  int atlasRows = 4,
}) {
  final normalized = itemId.toLowerCase();
  final normalizedSource = source.toLowerCase();
  final crafted =
      normalizedSource.contains('crafted') ||
      normalizedSource.contains('recycled') ||
      source.contains('加工');
  if (atlasRows >= 12) {
    final foodCell = switch (normalized) {
      'fish.raw' => 32,
      'fish.meat' => 33,
      'fish.bone' => 34,
      'fish.pack' => 35,
      'food.scrap' => 36,
      'food.greens' => 37,
      'food.edible' => 38,
      'food.cleaned' => 39,
      'food.starch' => 40,
      'herb.wild' => 41,
      'seasoning.salt' => 42,
      'seasoning.packet' => 43,
      'seasoning.blend' => 44,
      'meal.soup_basic' => 45,
      'meal.soup_fish' => 46,
      'meal.soup_vegetable' => 47,
      _ => null,
    };
    if (foodCell != null) return foodCell;
  }
  if (atlasRows >= 8) {
    final addedMaterialCell = switch (normalized) {
      'wood.chip' => 16,
      'wood.sawdust' => 17,
      'wood.driftwood' => 18,
      'wood.rod' => 19,
      'wood.frame' => 20,
      'cloth.edge_scrap' => 21,
      'cloth.patchwork' => 22,
      'cloth.thread_end' => 23,
      'cloth.binding' => 24,
      'metal.nail_bundle' => 25,
      'metal.fastener' => 26,
      'adhesive.recycled' => 27,
      _ => null,
    };
    if (addedMaterialCell != null) return addedMaterialCell;
    if ((normalized == 'container.clean' ||
            normalized == 'container.bottle_clean') &&
        contentItemId != null) {
      return switch (contentItemId) {
        'water.muddy' => 28,
        'water.dirty' => 29,
        'water.filtered' => 30,
        'water.boiled' => 31,
        _ => null,
      };
    }
  }
  if (normalized == 'wood.board') return crafted ? 1 : 0;
  if (normalized == 'cloth.thread_spool') return 2;
  if (normalized == 'cloth.repair_strip') return 3;
  if (normalized == 'cloth.rag_piece') return 4;
  if (normalized == 'cloth.thread_end') return 5;
  if (normalized == 'metal.scrap') return 6;
  if (normalized == 'metal.sheet') return 7;
  if (normalized == 'metal.shard') return 8;
  if (normalized == 'plastic.scrap') return 9;
  if (normalized == 'paper.scrap') return 10;
  if (normalized == 'fuel.dry') return 11;
  if ((normalized == 'container.clean' ||
          normalized == 'container.bottle_clean') &&
      (contentItemId?.contains('water.muddy') ?? false)) {
    return 13;
  }
  // Only the muddy-water cell exists in the first optional atlas revision.
  // Other water variants must use the offline painter so the atlas cannot
  // erase their visibly distinct state.
  if (contentItemId != null && contentItemId.startsWith('water.')) return null;
  if (normalized == 'container.clean' || normalized == 'container.bottle_clean') {
    return 12;
  }
  if (normalized == 'container.meal_box') return 14;
  if (normalized == 'fish.raw') return 15;
  return null;
}

int streetScrapMaterialAtlasRows(Uint8List bytes) {
  const pngHeaderLength = 24;
  if (bytes.length < pngHeaderLength) return 0;
  final header = ByteData.sublistView(bytes);
  if (header.getUint32(16) != 768) return 0;
  return switch (header.getUint32(20)) {
    768 => 4,
    1536 => 8,
    2304 => 12,
    _ => 0,
  };
}

int? streetScrapToolAtlasCellFor(String itemId) => switch (itemId) {
  'tool.needle' => 0,
  'tool.paper_mould' => 1,
  'tool.awl' => 2,
  'tool.crowbar' => 3,
  'tool.pliers' => 4,
  'tool.kit' => 5,
  'tool.rod_basic' => 6,
  'tool.rod_advanced' => 7,
  'tool.pot' => 8,
  'tool.stove' => 9,
  'tool.cook_kit' => 10,
  'tool.condenser' => 11,
  'toolpart.rig' => 12,
  'toolpart.float' => 13,
  'bait.basic' => 14,
  'bait.herb' => 15,
  _ => null,
};

int? streetScrapPaperPlasticFuelAtlasCellFor(String itemId) => switch (itemId) {
  'paper.scrap' => 0,
  'paper.pulp' => 1,
  'paper.board' => 2,
  'paper.packaging' => 3,
  'plastic.scrap' => 4,
  'plastic.sheet' => 5,
  'plastic.float_part' => 6,
  'plastic.seal' => 7,
  'bundle.plastic_scrap' => 8,
  'fuel.mixed' => 9,
  'fuel.dry' => 10,
  'fuel.oilcloth' => 11,
  'fuel.efficient_pack' => 12,
  'material.glass_scrap' => 13,
  'material.filter_cloth' => 14,
  'material.waterproof_coating' => 15,
  _ => null,
};

String streetScrapWoodGlyphFor(String itemId) => switch (itemId) {
  'wood.chip' => 'chips',
  'bundle.wood_chip' => 'chipBundle',
  'wood.sawdust' => 'sawdust',
  'wood.driftwood' => 'driftwood',
  'wood.rod' => 'rod',
  'wood.frame' => 'frame',
  'toolpart.handle' => 'wrappedHandle',
  'wood.board' => 'board',
  _ => 'board',
};

String streetScrapClothGlyphFor(String itemId) => switch (itemId) {
  'cloth.rag_piece' => 'rag',
  'cloth.edge_scrap' => 'frayedEdge',
  'cloth.repair_strip' => 'repairStrip',
  'cloth.patchwork' => 'patchwork',
  'cloth.thread_spool' => 'spool',
  'cloth.thread_end' || 'bundle.thread_end' => 'looseThread',
  'cloth.binding' => 'binding',
  'rope.coarse' => 'rope',
  'line.fishing' => 'fishingLine',
  'cloth.waterproof' => 'waterproof',
  'cloth.insulation' => 'insulation',
  'material.filter_cloth' => 'filterCloth',
  'bundle.cloth_scrap' => 'clothBundle',
  _ => 'cloth',
};

String streetScrapUtilityGlyphFor(String itemId) => switch (itemId) {
  'adhesive.residue' => 'residue',
  'adhesive.recycled' => 'recycledGlue',
  'adhesive.starch_paste' => 'starchPaste',
  'material.waterproof_coating' => 'waterproofCoating',
  'material.mud' => 'mud',
  'material.charcoal' => 'charcoal',
  'material.mineral_pack' => 'mineralPack',
  _ => 'utility',
};

String streetScrapFoodGlyphFor(String itemId) => switch (itemId) {
  'fish.raw' => 'wholeFish',
  'fish.meat' => 'fishMeat',
  'fish.bone' => 'fishBone',
  'fish.pack' => 'fishPack',
  'food.scrap' => 'foodScrap',
  'food.greens' => 'greens',
  'food.edible' => 'foundFood',
  'food.cleaned' => 'cleanedFood',
  'food.starch' => 'starchFood',
  'herb.wild' => 'herb',
  'seasoning.salt' => 'salt',
  'seasoning.packet' => 'seasoningPacket',
  'seasoning.blend' => 'seasoningBlend',
  'meal.soup_basic' => 'basicSoup',
  'meal.soup_fish' => 'fishSoup',
  'meal.soup_vegetable' => 'vegetableSoup',
  'meal.shared' => 'sharedMeal',
  'meal.failed' => 'failedMeal',
  'meal.relief_box' => 'reliefMeal',
  _ => 'food',
};

String streetScrapPaperGlyphFor(String itemId) => switch (itemId) {
  'paper.scrap' => 'paperScrap',
  'bundle.paper_scrap' => 'paperBundle',
  'paper.pulp' => 'pulp',
  'paper.board' => 'paperBoard',
  'paper.packaging' => 'packaging',
  _ => 'paper',
};

String streetScrapPlasticGlyphFor(String itemId) => switch (itemId) {
  'plastic.scrap' => 'plasticScrap',
  'plastic.sheet' => 'plasticSheet',
  'plastic.float_part' => 'floatPart',
  'plastic.seal' => 'plasticSeal',
  'bundle.plastic_scrap' => 'plasticBundle',
  _ => 'plastic',
};

String streetScrapFuelGlyphFor(String itemId) => switch (itemId) {
  'fuel.mixed' => 'mixedFuel',
  'fuel.dry' => 'dryFuel',
  'fuel.oilcloth' => 'oilClothFuel',
  'fuel.efficient_pack' => 'efficientFuel',
  _ => 'fuel',
};

String streetScrapToolGlyphFor(String itemId) => switch (itemId) {
  'tool.needle' => 'needle',
  'tool.paper_mould' => 'paperMould',
  'tool.awl' => 'awl',
  'tool.crowbar' => 'crowbar',
  'tool.pliers' => 'pliers',
  'tool.kit' => 'repairKit',
  'tool.rod_basic' => 'basicRod',
  'tool.rod_repaired' => 'repairedRod',
  'tool.rod_advanced' => 'advancedRod',
  'tool.pot' => 'pot',
  'tool.stove' => 'stove',
  'tool.cook_kit' => 'cookKit',
  'tool.condenser' => 'condenser',
  'toolpart.rig' => 'fishingRig',
  'toolpart.float' => 'float',
  'bait.basic' => 'basicBait',
  'bait.herb' => 'herbBait',
  _ => 'tool',
};

String streetScrapContainerGlyphFor(String itemId) => switch (itemId) {
  'container.broken_bottle' => 'brokenBottle',
  'container.used_intact' => 'oldBottle',
  'container.clean' => 'cleanBottle',
  'container.clean_jar' => 'cleanJar',
  'container.meal_box' => 'mealBox',
  'container.meal_box_insulated' => 'insulatedMealBox',
  _ => 'container',
};

String streetScrapStorageGlyphFor(String itemId) => switch (itemId) {
  'bag.basic' => 'basicBackpack',
  'bag.reinforced' => 'reinforcedBackpack',
  'bag.weatherproof' => 'weatherproofBag',
  'storage.wooden_crate' => 'woodCrate',
  'storage.reinforced_chest' => 'reinforcedChest',
  _ => 'storage',
};

String streetScrapStructureGlyphFor(String itemId) => switch (itemId) {
  'structure.raft' => 'raft',
  'structure.tarp' => 'tarpShelter',
  'structure.shelter' => 'foldingShelter',
  _ => 'structure',
};

String streetScrapMetalGlyphFor(String itemId) => switch (itemId) {
  'metal.scrap' => 'scrap',
  'metal.shard' => 'shard',
  'metal.sheet' => 'sheet',
  'metal.bar' => 'bar',
  'metal.wire' => 'wire',
  'metal.nail_bundle' => 'nails',
  'metal.fastener' => 'fastener',
  'metal.ferrule' => 'ferrule',
  'metal.hook' => 'hook',
  'material.glass_scrap' => 'glass',
  'bundle.metal_scrap' => 'metalBundle',
  _ => 'metal',
};

Color streetScrapWaterColorFor(String? waterItemId) => switch (waterItemId) {
  'water.turbid' => const Color(0xff85836e),
  'water.dirty' => const Color(0xff696c3b),
  'water.muddy' => const Color(0xff986d45),
  'water.filtered' => const Color(0xff6c9fa0),
  'water.boiled' => const Color(0xffaed3cf),
  'water.distilled' => const Color(0xffa2dce0),
  'water.mineral' => const Color(0xff4d91ae),
  _ => const Color(0xff73999a),
};

class _StreetScrapAtlasCell extends StatelessWidget {
  const _StreetScrapAtlasCell({
    required this.bytes,
    required this.cell,
    required this.size,
    required this.rows,
  });

  final Uint8List bytes;
  final int cell;
  final double size;
  final int rows;

  @override
  Widget build(BuildContext context) {
    final column = cell % 4;
    final row = cell ~/ 4;
    return ClipRect(
      child: SizedBox.square(
        dimension: size,
        child: OverflowBox(
          minWidth: size * 4,
          maxWidth: size * 4,
          minHeight: size * rows,
          maxHeight: size * rows,
          alignment: Alignment(2 * column / 3 - 1, 2 * row / (rows - 1) - 1),
          child: Image.memory(
            bytes,
            width: size * 4,
            height: size * rows,
            fit: BoxFit.fill,
            filterQuality: FilterQuality.none,
            gaplessPlayback: true,
          ),
        ),
      ),
    );
  }
}

class _StreetScrapPixelPainter extends CustomPainter {
  const _StreetScrapPixelPainter({
    required this.itemId,
    required this.contentItemId,
    required this.crafted,
  });

  final String itemId;
  final String? contentItemId;
  final bool crafted;

  static const _ink = Color(0xff293d3b);
  static const _paper = Color(0xffe8dfcb);
  static const _wood = Color(0xffcab98b);
  static const _copper = Color(0xffbc7955);
  static const _metal = Color(0xff6c8382);
  static const _water = Color(0xff73999a);
  static const _light = Color(0xffe8d3a2);
  static const _glue = Color(0xffb78c55);
  static const _mud = Color(0xff785743);
  static const _charcoal = Color(0xff3f4945);
  static const _greens = Color(0xff687c4d);
  static const _food = Color(0xffbd8a52);
  static const _soup = Color(0xffc9954f);

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.width / 16;
    canvas.save();
    canvas.scale(scale, size.height / 16);
    final group = _group;
    switch (group) {
      case 'wood':
        _woodMaterial(canvas);
      case 'cloth':
        _clothMaterial(canvas);
      case 'metal':
        _metalMaterial(canvas);
      case 'utility':
        _utilityMaterial(canvas);
      case 'fuel':
        _fuelMaterial(canvas);
      case 'container':
        _containerMaterial(canvas);
      case 'storage':
        _storageMaterial(canvas);
      case 'structure':
        _structureMaterial(canvas);
      case 'water':
        _bottle(canvas);
      case 'food':
        _foodMaterial(canvas);
      case 'paper':
        _paperMaterial(canvas);
      case 'plastic':
        if (itemId.startsWith('plastic.') || itemId == 'bundle.plastic_scrap') {
          _plasticMaterial(canvas);
        } else {
          _plasticObject(canvas);
        }
      case 'tool':
        _toolMaterial(canvas);
      default:
        _scrapBundle(canvas);
    }
    if (crafted) _craftMark(canvas);
    canvas.restore();
  }

  String get _group {
    final id = itemId.toLowerCase();
    final content = contentItemId?.toLowerCase() ?? '';
    if (id.startsWith('adhesive.') ||
        id == 'material.waterproof_coating' ||
        id == 'material.mud' ||
        id == 'material.charcoal' ||
        id == 'material.mineral_pack') {
      return 'utility';
    }
    if (id == 'material.filter_cloth') return 'cloth';
    if (id.startsWith('wood.') ||
        id.contains('wood') ||
        id == 'toolpart.handle') {
      return 'wood';
    }
    if (id.startsWith('cloth.') ||
        id.startsWith('thread.') ||
        id.startsWith('rope.') ||
        id.startsWith('line.') ||
        id == 'bundle.cloth_scrap' ||
        id == 'bundle.thread_end' ||
        id.contains('cloth')) {
      return 'cloth';
    }
    if (id.startsWith('metal.') ||
        id.contains('metal') ||
        id == 'material.glass_scrap') {
      return 'metal';
    }
    if (id.startsWith('fuel.')) return 'fuel';
    if (id.startsWith('container.')) {
      return content.startsWith('water.') ? 'water' : 'container';
    }
    if (id.startsWith('bag.') || id.startsWith('storage.')) return 'storage';
    if (id.startsWith('structure.')) return 'structure';
    if (id.startsWith('water.') || content.startsWith('water.')) return 'water';
    if (id.startsWith('food.') || id.startsWith('fish.') || id.contains('soup')) {
      return 'food';
    }
    if (id.startsWith('herb.') ||
        id.startsWith('seasoning.') ||
        id.startsWith('meal.')) {
      return 'food';
    }
    if (id.startsWith('paper.') || id == 'bundle.paper_scrap') return 'paper';
    if (id.startsWith('plastic.') ||
        id == 'bundle.plastic_scrap' ||
        id.contains('bottle') ||
        id.contains('container')) {
      return 'plastic';
    }
    if (id.startsWith('bait.')) return 'tool';
    if (id.startsWith('tool.') ||
        id.contains('tool') ||
        id.startsWith('toolpart.') ||
        id.contains('rod') ||
        id.contains('awl')) {
      return 'tool';
    }
    return 'scrap';
  }

  void _pixel(Canvas canvas, int x, int y, Color color) {
    final paint = Paint()..color = color;
    canvas.drawRect(Rect.fromLTWH(x.toDouble(), y.toDouble(), 1, 1), paint);
  }

  void _row(Canvas canvas, int x, int y, int width, Color color) {
    final paint = Paint()..color = color;
    canvas.drawRect(
      Rect.fromLTWH(x.toDouble(), y.toDouble(), width.toDouble(), 1),
      paint,
    );
  }

  void _finePixel(Canvas canvas, int x, int y, Color color) {
    final paint = Paint()..color = color;
    canvas.drawRect(Rect.fromLTWH(x / 2, y / 2, 0.5, 0.5), paint);
  }

  void _fineRow(Canvas canvas, int x, int y, int width, Color color) {
    final paint = Paint()..color = color;
    canvas.drawRect(Rect.fromLTWH(x / 2, y / 2, width / 2, 0.5), paint);
  }

  void _woodBoard(Canvas canvas) {
    for (var y = 4; y <= 11; y += 4) {
      _row(canvas, 2, y, 12, _ink);
      _row(canvas, 3, y + 1, 10, _wood);
      _row(canvas, 4, y + 2, 8, _light);
      _pixel(canvas, 5, y + 2, _copper);
      _pixel(canvas, 11, y + 1, _copper);
    }
    if (crafted) {
      _pixel(canvas, 7, 5, _ink);
      _pixel(canvas, 7, 9, _ink);
    } else {
      _row(canvas, 5, 3, 6, _light);
    }
  }

  void _fuelMaterial(Canvas canvas) {
    switch (streetScrapFuelGlyphFor(itemId)) {
      case 'mixedFuel':
        _row(canvas, 4, 5, 8, _ink);
        _row(canvas, 3, 6, 10, _copper);
        _row(canvas, 4, 7, 8, _charcoal);
        _row(canvas, 3, 8, 10, _wood);
        _row(canvas, 4, 9, 8, _ink);
        _pixel(canvas, 5, 4, _wood);
        _pixel(canvas, 10, 10, _copper);
      case 'dryFuel':
        _row(canvas, 4, 4, 8, _ink);
        _row(canvas, 3, 5, 10, _wood);
        _row(canvas, 4, 6, 8, _ink);
        _row(canvas, 5, 7, 7, _wood);
        _row(canvas, 4, 8, 8, _ink);
        _row(canvas, 3, 9, 10, _wood);
        _row(canvas, 4, 10, 8, _ink);
        _pixel(canvas, 6, 3, _light);
        _pixel(canvas, 9, 11, _light);
      case 'oilClothFuel':
        _row(canvas, 5, 4, 6, _ink);
        _row(canvas, 4, 5, 8, _charcoal);
        _row(canvas, 3, 6, 10, _ink);
        _row(canvas, 4, 7, 8, _copper);
        _row(canvas, 5, 8, 6, _charcoal);
        _row(canvas, 6, 9, 4, _ink);
        _pixel(canvas, 7, 3, _copper);
        _pixel(canvas, 9, 5, _light);
      case 'efficientFuel':
        _row(canvas, 5, 3, 6, _ink);
        _row(canvas, 4, 4, 8, _charcoal);
        _row(canvas, 3, 5, 10, _ink);
        _row(canvas, 4, 6, 8, _copper);
        _row(canvas, 4, 7, 8, _charcoal);
        _row(canvas, 3, 8, 10, _ink);
        _row(canvas, 4, 9, 8, _charcoal);
        _row(canvas, 5, 10, 6, _ink);
        _pixel(canvas, 7, 6, _light);
      default:
        _scrapBundle(canvas);
    }
  }

  void _woodMaterial(Canvas canvas) {
    switch (streetScrapWoodGlyphFor(itemId)) {
      case 'chips':
        _woodChips(canvas);
      case 'chipBundle':
        _woodChipBundle(canvas);
      case 'sawdust':
        _woodSawdust(canvas);
      case 'driftwood':
        _driftwood(canvas);
      case 'rod':
        _woodRod(canvas);
      case 'frame':
        _woodFrame(canvas);
      case 'wrappedHandle':
        _wrappedHandle(canvas);
      default:
        _woodBoard(canvas);
    }
  }

  void _woodChips(Canvas canvas) {
    _row(canvas, 3, 11, 10, _ink);
    _row(canvas, 4, 10, 8, _wood);
    _row(canvas, 5, 9, 5, _light);
    _pixel(canvas, 4, 8, _ink);
    _row(canvas, 5, 7, 5, _copper);
    _pixel(canvas, 10, 6, _ink);
    _row(canvas, 11, 5, 3, _wood);
    _pixel(canvas, 12, 4, _light);
    _pixel(canvas, 6, 12, _copper);
  }

  void _woodChipBundle(Canvas canvas) {
    _row(canvas, 4, 4, 8, _ink);
    _row(canvas, 3, 5, 10, _wood);
    _row(canvas, 3, 6, 10, _ink);
    _row(canvas, 4, 7, 8, _light);
    _row(canvas, 3, 8, 10, _ink);
    _row(canvas, 3, 9, 10, _wood);
    _row(canvas, 4, 10, 8, _ink);
    _row(canvas, 7, 5, 2, _copper);
    _row(canvas, 7, 8, 2, _copper);
    _pixel(canvas, 5, 6, _light);
    _pixel(canvas, 10, 9, _light);
  }

  void _woodSawdust(Canvas canvas) {
    _row(canvas, 5, 5, 6, _ink);
    _row(canvas, 4, 6, 8, _wood);
    _row(canvas, 3, 7, 10, _light);
    _row(canvas, 2, 8, 12, _wood);
    _row(canvas, 3, 9, 10, _light);
    _row(canvas, 4, 10, 8, _wood);
    _row(canvas, 5, 11, 6, _ink);
    _pixel(canvas, 6, 8, _copper);
    _pixel(canvas, 9, 9, _copper);
  }

  void _driftwood(Canvas canvas) {
    _fineRow(canvas, 10, 10, 13, _ink);
    _fineRow(canvas, 8, 11, 18, _wood);
    _fineRow(canvas, 7, 12, 22, _ink);
    _fineRow(canvas, 5, 13, 26, _wood);
    _fineRow(canvas, 4, 14, 28, _ink);
    _fineRow(canvas, 3, 15, 29, _wood);
    _fineRow(canvas, 2, 16, 29, _ink);
    _fineRow(canvas, 3, 17, 27, _light);
    _fineRow(canvas, 4, 18, 25, _wood);
    _fineRow(canvas, 6, 19, 22, _ink);
    _fineRow(canvas, 9, 20, 17, _wood);
    _fineRow(canvas, 12, 21, 11, _ink);
    _fineRow(canvas, 14, 22, 7, _wood);

    // Broken branch nubs and dark end grain keep it from reading as a board.
    _fineRow(canvas, 3, 12, 5, _ink);
    _fineRow(canvas, 5, 11, 4, _light);
    _fineRow(canvas, 25, 12, 5, _ink);
    _fineRow(canvas, 27, 13, 3, _copper);
    _fineRow(canvas, 2, 18, 5, _ink);
    _fineRow(canvas, 24, 17, 5, _ink);
    _finePixel(canvas, 8, 14, _light);
    _finePixel(canvas, 10, 14, _copper);
    _fineRow(canvas, 12, 15, 8, _wood);
    _fineRow(canvas, 7, 17, 6, _copper);
    _fineRow(canvas, 15, 18, 7, _light);
    _finePixel(canvas, 18, 16, _ink);
    _finePixel(canvas, 21, 17, _copper);
  }

  void _woodRod(Canvas canvas) {
    for (var x = 3; x < 13; x++) {
      final y = x < 8 ? 10 - (x - 3) ~/ 3 : 8 - (x - 8) ~/ 4;
      _pixel(canvas, x, y, _ink);
      _pixel(canvas, x, y + 1, x.isEven ? _wood : _light);
    }
    _pixel(canvas, 12, 6, _copper);
  }

  void _woodFrame(Canvas canvas) {
    for (var y = 3; y < 13; y++) {
      _row(canvas, 3, y, 2, y == 3 || y == 12 ? _ink : _wood);
      _row(canvas, 11, y, 2, y == 3 || y == 12 ? _ink : _wood);
    }
    _row(canvas, 5, 3, 6, _ink);
    _row(canvas, 5, 4, 6, _light);
    _row(canvas, 5, 11, 6, _light);
    _row(canvas, 5, 12, 6, _ink);
    _pixel(canvas, 4, 4, _copper);
    _pixel(canvas, 11, 11, _copper);
  }

  void _wrappedHandle(Canvas canvas) {
    _row(canvas, 7, 2, 3, _ink);
    _row(canvas, 8, 3, 2, _metal);
    for (var y = 4; y < 14; y++) {
      _row(canvas, 7, y, 3, _wood);
      if (y.isEven) _row(canvas, 7, y, 3, _copper);
    }
    _row(canvas, 7, 14, 3, _ink);
  }

  void _cloth(Canvas canvas) {
    _row(canvas, 4, 2, 8, _ink);
    for (var y = 3; y < 12; y++) {
      _pixel(canvas, 3, y, _ink);
      _row(canvas, 4, y, 8, y < 6 ? _paper : _light);
      _pixel(canvas, 12, y, _ink);
    }
    _row(canvas, 5, 5, 5, _metal);
    _pixel(canvas, 10, 9, _metal);
    if (crafted) {
      for (var x = 5; x < 11; x += 2) {
        _pixel(canvas, x, 7, _copper);
      }
    }
  }

  void _clothMaterial(Canvas canvas) {
    switch (streetScrapClothGlyphFor(itemId)) {
      case 'rag':
        _rag(canvas);
      case 'frayedEdge':
        _frayedEdge(canvas);
      case 'repairStrip':
        _repairStrip(canvas);
      case 'patchwork':
        _patchwork(canvas);
      case 'spool':
        _threadSpool(canvas);
      case 'looseThread':
        _looseThread(canvas);
      case 'binding':
        _binding(canvas);
      case 'rope':
        _rope(canvas);
      case 'fishingLine':
        _fishingLine(canvas);
      case 'waterproof':
        _waterproofCloth(canvas);
      case 'insulation':
        _insulationCloth(canvas);
      case 'clothBundle':
        _clothBundle(canvas);
      default:
        _cloth(canvas);
    }
  }

  void _utilityMaterial(Canvas canvas) {
    switch (streetScrapUtilityGlyphFor(itemId)) {
      case 'residue':
        _row(canvas, 5, 4, 6, _ink);
        _row(canvas, 4, 5, 8, _glue);
        _row(canvas, 5, 7, 6, _glue);
        _row(canvas, 6, 8, 4, _ink);
        _pixel(canvas, 5, 9, _glue);
      case 'recycledGlue':
        _row(canvas, 5, 3, 6, _ink);
        _row(canvas, 4, 4, 8, _glue);
        _row(canvas, 4, 5, 8, _ink);
        for (var y = 6; y < 12; y++) {
          _row(canvas, 5, y, 6, _glue);
        }
        _row(canvas, 4, 12, 8, _ink);
        _row(canvas, 6, 7, 4, _light);
      case 'starchPaste':
        _row(canvas, 4, 6, 8, _ink);
        _row(canvas, 3, 7, 10, _paper);
        _row(canvas, 4, 8, 8, _light);
        _row(canvas, 5, 9, 6, _paper);
        _row(canvas, 6, 10, 4, _ink);
        _pixel(canvas, 7, 5, _paper);
      case 'waterproofCoating':
        _row(canvas, 4, 4, 8, _ink);
        _row(canvas, 3, 5, 10, _copper);
        _row(canvas, 3, 6, 10, _ink);
        _row(canvas, 4, 7, 8, _copper);
        _row(canvas, 5, 8, 6, _ink);
        _pixel(canvas, 6, 5, _light);
        _pixel(canvas, 9, 7, _light);
      case 'mud':
        _row(canvas, 4, 5, 8, _ink);
        _row(canvas, 3, 6, 10, _mud);
        _row(canvas, 4, 7, 8, _mud);
        _row(canvas, 5, 8, 6, _mud);
        _row(canvas, 6, 9, 4, _ink);
        _pixel(canvas, 5, 6, _copper);
        _pixel(canvas, 9, 7, _paper);
      case 'charcoal':
        _row(canvas, 5, 3, 6, _ink);
        _row(canvas, 4, 4, 8, _charcoal);
        _row(canvas, 3, 5, 10, _ink);
        _row(canvas, 4, 6, 8, _charcoal);
        _row(canvas, 3, 7, 10, _ink);
        _row(canvas, 4, 8, 8, _charcoal);
        _row(canvas, 5, 9, 6, _ink);
        _pixel(canvas, 6, 5, _light);
      case 'mineralPack':
        _row(canvas, 5, 3, 6, _ink);
        _row(canvas, 4, 4, 8, _paper);
        _row(canvas, 3, 5, 10, _ink);
        for (var y = 6; y < 11; y++) {
          _row(canvas, 4, y, 8, y.isEven ? _light : _paper);
        }
        _row(canvas, 4, 11, 8, _ink);
        _pixel(canvas, 7, 7, _copper);
        _pixel(canvas, 9, 9, _copper);
      default:
        _scrapBundle(canvas);
    }
  }

  void _rag(Canvas canvas) {
    _row(canvas, 5, 3, 7, _ink);
    _row(canvas, 3, 4, 10, _ink);
    _row(canvas, 4, 5, 8, _paper);
    _row(canvas, 3, 6, 10, _light);
    _row(canvas, 4, 7, 8, _paper);
    _row(canvas, 3, 8, 10, _ink);
    _row(canvas, 5, 9, 6, _paper);
    _row(canvas, 4, 10, 8, _ink);
    _pixel(canvas, 4, 11, _light);
    _pixel(canvas, 6, 12, _ink);
    _pixel(canvas, 9, 11, _ink);
  }

  void _frayedEdge(Canvas canvas) {
    _row(canvas, 2, 6, 12, _ink);
    _row(canvas, 3, 7, 10, _paper);
    _row(canvas, 3, 8, 10, _light);
    for (var x = 3; x < 13; x += 2) {
      _pixel(canvas, x, 9, _ink);
      _pixel(canvas, x + 1, 10 + (x % 3), _paper);
    }
    _pixel(canvas, 4, 5, _ink);
    _pixel(canvas, 11, 5, _ink);
  }

  void _repairStrip(Canvas canvas) {
    _row(canvas, 3, 5, 10, _ink);
    _row(canvas, 2, 6, 12, _paper);
    _row(canvas, 2, 7, 12, _light);
    _row(canvas, 3, 8, 10, _paper);
    _row(canvas, 4, 9, 8, _ink);
    for (var x = 4; x < 12; x += 3) {
      _pixel(canvas, x, 7, _copper);
    }
    _pixel(canvas, 12, 6, _ink);
  }

  void _patchwork(Canvas canvas) {
    _row(canvas, 4, 3, 8, _ink);
    for (var y = 4; y < 12; y++) {
      _pixel(canvas, 3, y, _ink);
      _pixel(canvas, 12, y, _ink);
    }
    _row(canvas, 4, 12, 8, _ink);
    _row(canvas, 4, 4, 4, _paper);
    _row(canvas, 8, 4, 4, _light);
    _row(canvas, 4, 5, 4, _light);
    _row(canvas, 8, 5, 4, _paper);
    _row(canvas, 4, 8, 4, _light);
    _row(canvas, 8, 8, 4, _paper);
    _row(canvas, 4, 9, 4, _paper);
    _row(canvas, 8, 9, 4, _light);
    for (var y = 5; y < 11; y += 3) {
      _pixel(canvas, 8, y, _copper);
    }
  }

  void _threadSpool(Canvas canvas) {
    _row(canvas, 4, 3, 8, _ink);
    _row(canvas, 5, 4, 6, _metal);
    _row(canvas, 4, 5, 8, _ink);
    for (var y = 6; y < 11; y++) {
      _row(canvas, 4, y, 8, y.isEven ? _paper : _light);
      _pixel(canvas, 4, y, _ink);
      _pixel(canvas, 11, y, _copper);
    }
    _row(canvas, 4, 11, 8, _ink);
    _row(canvas, 5, 12, 6, _metal);
    _row(canvas, 4, 13, 8, _ink);
  }

  void _looseThread(Canvas canvas) {
    _row(canvas, 4, 4, 7, _light);
    _pixel(canvas, 3, 5, _light);
    _pixel(canvas, 11, 5, _light);
    _row(canvas, 5, 6, 6, _ink);
    _pixel(canvas, 6, 7, _paper);
    _pixel(canvas, 7, 8, _paper);
    _pixel(canvas, 8, 9, _paper);
    _row(canvas, 9, 10, 4, _light);
    _pixel(canvas, 12, 9, _copper);
  }

  void _binding(Canvas canvas) {
    _row(canvas, 4, 4, 8, _ink);
    _row(canvas, 3, 5, 10, _paper);
    _row(canvas, 3, 6, 10, _light);
    _row(canvas, 4, 7, 8, _ink);
    _row(canvas, 5, 8, 6, _paper);
    _row(canvas, 5, 9, 6, _ink);
    _row(canvas, 4, 10, 8, _light);
    _pixel(canvas, 6, 6, _copper);
    _pixel(canvas, 10, 6, _copper);
  }

  void _rope(Canvas canvas) {
    _row(canvas, 5, 3, 6, _ink);
    _row(canvas, 4, 4, 8, _wood);
    _row(canvas, 3, 5, 10, _ink);
    _row(canvas, 3, 6, 3, _light);
    _row(canvas, 10, 6, 3, _light);
    _row(canvas, 4, 7, 8, _ink);
    _row(canvas, 5, 8, 6, _wood);
    _row(canvas, 5, 9, 2, _ink);
    _row(canvas, 9, 9, 2, _ink);
    _row(canvas, 4, 10, 8, _wood);
    _row(canvas, 3, 11, 10, _ink);
    _row(canvas, 4, 12, 8, _light);
    _row(canvas, 5, 13, 6, _ink);
  }

  void _fishingLine(Canvas canvas) {
    _pixel(canvas, 5, 3, _light);
    _row(canvas, 6, 3, 5, _ink);
    _pixel(canvas, 11, 4, _light);
    _pixel(canvas, 12, 5, _ink);
    _row(canvas, 5, 6, 7, _light);
    _pixel(canvas, 4, 7, _ink);
    _pixel(canvas, 4, 8, _light);
    _row(canvas, 5, 9, 6, _ink);
    _pixel(canvas, 10, 10, _light);
    _pixel(canvas, 9, 11, _ink);
    _pixel(canvas, 8, 12, _copper);
    _pixel(canvas, 7, 13, _copper);
  }

  void _waterproofCloth(Canvas canvas) {
    _row(canvas, 4, 3, 8, _ink);
    for (var y = 4; y < 12; y++) {
      _row(canvas, 3, y, 10, y.isEven ? _metal : _water);
      _pixel(canvas, 3, y, _ink);
      _pixel(canvas, 12, y, _ink);
    }
    _row(canvas, 4, 12, 8, _ink);
    _pixel(canvas, 6, 5, _light);
    _pixel(canvas, 10, 8, _light);
    _pixel(canvas, 7, 10, _paper);
  }

  void _insulationCloth(Canvas canvas) {
    _row(canvas, 4, 3, 8, _ink);
    for (var y = 4; y < 12; y++) {
      _row(canvas, 3, y, 10, y.isEven ? _light : _paper);
      _pixel(canvas, 3, y, _ink);
      _pixel(canvas, 12, y, _ink);
    }
    _row(canvas, 4, 12, 8, _ink);
    _row(canvas, 7, 4, 2, _copper);
    _row(canvas, 7, 6, 2, _copper);
    _row(canvas, 7, 8, 2, _copper);
    _row(canvas, 7, 10, 2, _copper);
  }

  void _clothBundle(Canvas canvas) {
    _row(canvas, 4, 4, 8, _ink);
    _row(canvas, 3, 5, 10, _paper);
    _row(canvas, 3, 6, 10, _light);
    _row(canvas, 4, 7, 8, _ink);
    _row(canvas, 3, 8, 10, _paper);
    _row(canvas, 3, 9, 10, _light);
    _row(canvas, 4, 10, 8, _ink);
    _row(canvas, 7, 5, 2, _copper);
    _row(canvas, 7, 8, 2, _copper);
    _row(canvas, 7, 9, 2, _copper);
  }

  void _metalObject(Canvas canvas) {
    _row(canvas, 4, 3, 8, _ink);
    _row(canvas, 3, 4, 10, _metal);
    _row(canvas, 2, 5, 12, _ink);
    for (var y = 6; y < 11; y++) {
      _row(canvas, 3, y, 10, _metal);
    }
    _row(canvas, 4, 11, 8, _ink);
    _pixel(canvas, 5, 6, _light);
    _pixel(canvas, 10, 8, crafted ? _copper : _ink);
    _pixel(canvas, 6, 9, _ink);
  }

  void _metalMaterial(Canvas canvas) {
    switch (streetScrapMetalGlyphFor(itemId)) {
      case 'scrap':
        _metalScrap(canvas);
      case 'shard':
        _metalShard(canvas);
      case 'sheet':
        _metalSheet(canvas);
      case 'bar':
        _metalBar(canvas);
      case 'wire':
        _metalWire(canvas);
      case 'nails':
        _nailBundle(canvas);
      case 'fastener':
        _fastener(canvas);
      case 'ferrule':
        _ferrule(canvas);
      case 'hook':
        _metalHook(canvas);
      case 'glass':
        _glassShard(canvas);
      case 'metalBundle':
        _metalBundle(canvas);
      default:
        _metalObject(canvas);
    }
  }

  void _metalScrap(Canvas canvas) {
    _row(canvas, 4, 4, 7, _ink);
    _row(canvas, 3, 5, 10, _metal);
    _row(canvas, 4, 6, 8, _ink);
    _row(canvas, 3, 7, 10, _metal);
    _row(canvas, 4, 8, 9, _ink);
    _row(canvas, 5, 9, 7, _metal);
    _row(canvas, 6, 10, 5, _ink);
    _pixel(canvas, 5, 6, _light);
    _pixel(canvas, 10, 8, _copper);
    _pixel(canvas, 7, 11, _metal);
  }

  void _metalShard(Canvas canvas) {
    _pixel(canvas, 8, 3, _ink);
    _row(canvas, 7, 4, 3, _metal);
    _row(canvas, 6, 5, 5, _ink);
    _row(canvas, 5, 6, 7, _metal);
    _row(canvas, 4, 7, 8, _ink);
    _row(canvas, 5, 8, 7, _metal);
    _row(canvas, 6, 9, 5, _ink);
    _row(canvas, 7, 10, 3, _metal);
    _pixel(canvas, 8, 11, _ink);
    _pixel(canvas, 7, 7, _light);
  }

  void _metalSheet(Canvas canvas) {
    _row(canvas, 4, 3, 8, _ink);
    for (var y = 4; y < 12; y++) {
      _row(canvas, 3, y, 10, _metal);
    }
    _row(canvas, 4, 12, 8, _ink);
    _row(canvas, 5, 5, 6, _light);
    _pixel(canvas, 4, 10, _copper);
    _pixel(canvas, 11, 5, _ink);
  }

  void _metalBar(Canvas canvas) {
    _row(canvas, 3, 7, 10, _ink);
    _row(canvas, 4, 6, 9, _metal);
    _row(canvas, 4, 8, 9, _metal);
    _row(canvas, 3, 9, 10, _ink);
    _pixel(canvas, 4, 7, _light);
    _pixel(canvas, 11, 7, _copper);
  }

  void _metalWire(Canvas canvas) {
    _row(canvas, 5, 3, 6, _ink);
    _row(canvas, 4, 4, 8, _metal);
    _row(canvas, 3, 5, 10, _ink);
    _pixel(canvas, 3, 6, _metal);
    _row(canvas, 4, 7, 8, _ink);
    _row(canvas, 5, 8, 6, _metal);
    _row(canvas, 5, 9, 2, _ink);
    _row(canvas, 9, 9, 2, _ink);
    _row(canvas, 4, 10, 8, _metal);
    _row(canvas, 3, 11, 10, _ink);
    _pixel(canvas, 12, 10, _copper);
  }

  void _nailBundle(Canvas canvas) {
    for (var offset = 0; offset < 3; offset++) {
      final x = 4 + offset * 3;
      for (var i = 0; i < 8; i++) {
        _pixel(canvas, x + (i ~/ 4), 4 + i, i == 0 ? _ink : _metal);
      }
      _pixel(canvas, x - 1, 4, _ink);
    }
    _row(canvas, 4, 9, 8, _copper);
    _row(canvas, 4, 10, 8, _ink);
  }

  void _fastener(Canvas canvas) {
    _row(canvas, 6, 3, 4, _ink);
    _row(canvas, 5, 4, 6, _light);
    _row(canvas, 6, 5, 4, _ink);
    _row(canvas, 7, 6, 2, _metal);
    _row(canvas, 6, 7, 4, _metal);
    _row(canvas, 7, 8, 2, _metal);
    _row(canvas, 6, 9, 4, _metal);
    _row(canvas, 7, 10, 2, _metal);
    _row(canvas, 5, 11, 6, _ink);
    _row(canvas, 6, 12, 4, _copper);
  }

  void _ferrule(Canvas canvas) {
    _row(canvas, 4, 3, 8, _ink);
    _row(canvas, 3, 4, 2, _metal);
    _row(canvas, 11, 4, 2, _metal);
    _row(canvas, 3, 5, 2, _ink);
    _row(canvas, 11, 5, 2, _ink);
    _row(canvas, 3, 6, 2, _metal);
    _row(canvas, 11, 6, 2, _metal);
    _row(canvas, 4, 7, 8, _ink);
    _row(canvas, 5, 4, 6, _light);
    _row(canvas, 5, 5, 6, _light);
    _pixel(canvas, 4, 4, _copper);
    _pixel(canvas, 11, 6, _copper);
  }

  void _metalHook(Canvas canvas) {
    _row(canvas, 6, 3, 5, _ink);
    _pixel(canvas, 10, 4, _metal);
    _pixel(canvas, 10, 5, _ink);
    _row(canvas, 7, 6, 3, _metal);
    _pixel(canvas, 7, 7, _ink);
    _pixel(canvas, 7, 8, _metal);
    _pixel(canvas, 7, 9, _ink);
    _pixel(canvas, 8, 10, _metal);
    _pixel(canvas, 9, 10, _ink);
    _pixel(canvas, 10, 9, _metal);
    _pixel(canvas, 10, 8, _ink);
    _pixel(canvas, 11, 7, _light);
  }

  void _glassShard(Canvas canvas) {
    _pixel(canvas, 7, 3, _ink);
    _row(canvas, 6, 4, 3, _water);
    _row(canvas, 5, 5, 5, _ink);
    _row(canvas, 4, 6, 8, _water);
    _row(canvas, 5, 7, 7, _light);
    _row(canvas, 6, 8, 5, _ink);
    _row(canvas, 7, 9, 3, _water);
    _pixel(canvas, 8, 10, _ink);
    _pixel(canvas, 6, 6, _paper);
  }

  void _metalBundle(Canvas canvas) {
    _row(canvas, 4, 4, 8, _ink);
    _row(canvas, 3, 5, 10, _metal);
    _row(canvas, 3, 6, 10, _ink);
    _row(canvas, 4, 7, 8, _metal);
    _row(canvas, 3, 8, 10, _ink);
    _row(canvas, 3, 9, 10, _metal);
    _row(canvas, 4, 10, 8, _ink);
    _row(canvas, 7, 5, 2, _copper);
    _row(canvas, 7, 8, 2, _copper);
    _pixel(canvas, 6, 6, _light);
    _pixel(canvas, 9, 9, _light);
  }

  void _bottle(Canvas canvas) {
    _row(canvas, 6, 1, 4, _ink);
    _row(canvas, 5, 2, 6, _metal);
    _row(canvas, 4, 3, 8, _ink);
    for (var y = 4; y < 13; y++) {
      _row(canvas, 3, y, 10, _metal);
      _pixel(canvas, 4, y, _light);
      final content = contentItemId ?? itemId;
      if (content.startsWith('water.') && y >= 8) {
        final liquid = streetScrapWaterColorFor(content);
        _row(canvas, 5, y, 7, liquid);
        if (content == 'water.turbid' && y.isEven) {
          _pixel(canvas, 7, y, _metal);
          _pixel(canvas, 10, y, _paper);
        } else if (content == 'water.dirty' && y == 10) {
          _pixel(canvas, 6, y, _ink);
          _pixel(canvas, 9, y, _wood);
        } else if (content == 'water.muddy' && y.isOdd) {
          _pixel(canvas, 8, y, _copper);
        } else if (content == 'water.boiled' && (y == 8 || y == 11)) {
          _pixel(canvas, 7, y, _paper);
          _pixel(canvas, 10, y, _paper);
        } else if (content == 'water.distilled' && y == 9) {
          _pixel(canvas, 8, y, _paper);
        } else if (content == 'water.mineral' && y == 10) {
          _row(canvas, 6, y, 4, _light);
        }
      }
    }
    _row(canvas, 4, 13, 8, _ink);
    _pixel(canvas, 10, 6, _paper);
  }

  void _brokenBottle(Canvas canvas) {
    // Fine pixels form the jagged neck and the curved glass body.
    _fineRow(canvas, 18, 3, 3, _ink);
    _fineRow(canvas, 17, 4, 5, _light);
    _fineRow(canvas, 15, 5, 9, _ink);
    _fineRow(canvas, 14, 6, 11, _water);
    _fineRow(canvas, 12, 7, 15, _ink);
    _fineRow(canvas, 10, 8, 18, _metal);
    _fineRow(canvas, 8, 9, 21, _ink);
    _fineRow(canvas, 7, 10, 22, _water);
    _fineRow(canvas, 6, 11, 23, _ink);
    _fineRow(canvas, 5, 12, 23, _water);
    _fineRow(canvas, 4, 13, 23, _ink);
    _fineRow(canvas, 4, 14, 22, _metal);
    _fineRow(canvas, 5, 15, 21, _ink);
    _fineRow(canvas, 6, 16, 20, _water);
    _fineRow(canvas, 7, 17, 18, _ink);
    _fineRow(canvas, 8, 18, 16, _metal);
    _fineRow(canvas, 10, 19, 13, _ink);
    _fineRow(canvas, 12, 20, 10, _water);
    _fineRow(canvas, 14, 21, 6, _ink);
    _finePixel(canvas, 9, 11, _paper);
    _fineRow(canvas, 11, 12, 2, _light);
    _finePixel(canvas, 12, 13, _light);
    _fineRow(canvas, 17, 9, 3, _paper);
    _finePixel(canvas, 6, 15, _light);
    _finePixel(canvas, 23, 14, _paper);
    _finePixel(canvas, 20, 17, _ink);
  }

  void _fish(Canvas canvas) {
    _row(canvas, 5, 4, 6, _ink);
    _row(canvas, 3, 5, 10, _ink);
    _row(canvas, 2, 6, 12, _metal);
    _row(canvas, 3, 7, 10, _light);
    _row(canvas, 5, 8, 6, _ink);
    _pixel(canvas, 11, 6, _paper);
    _pixel(canvas, 5, 6, _water);
    if (crafted) _pixel(canvas, 7, 7, _copper);
  }

  void _foodMaterial(Canvas canvas) {
    switch (streetScrapFoodGlyphFor(itemId)) {
      case 'wholeFish':
        _fish(canvas);
      case 'fishMeat':
        _row(canvas, 5, 4, 6, _ink);
        _row(canvas, 4, 5, 8, _food);
        _row(canvas, 3, 6, 10, _ink);
        _row(canvas, 4, 7, 8, _food);
        _row(canvas, 5, 8, 6, _light);
        _pixel(canvas, 6, 6, _copper);
        _pixel(canvas, 9, 7, _copper);
      case 'fishBone':
        _row(canvas, 3, 5, 3, _paper);
        _row(canvas, 10, 5, 3, _paper);
        _row(canvas, 4, 6, 8, _ink);
        _row(canvas, 5, 7, 6, _paper);
        _row(canvas, 4, 8, 8, _ink);
        _row(canvas, 3, 9, 3, _paper);
        _row(canvas, 10, 9, 3, _paper);
      case 'fishPack':
        _row(canvas, 4, 4, 8, _ink);
        _row(canvas, 3, 5, 10, _paper);
        _row(canvas, 3, 6, 10, _ink);
        _row(canvas, 4, 7, 8, _water);
        _row(canvas, 3, 8, 10, _ink);
        _row(canvas, 4, 9, 8, _paper);
        _row(canvas, 4, 10, 8, _ink);
        _row(canvas, 6, 5, 4, _copper);
      case 'foodScrap':
        _pixel(canvas, 5, 5, _ink);
        _row(canvas, 6, 5, 3, _food);
        _row(canvas, 4, 6, 7, _ink);
        _row(canvas, 5, 7, 6, _food);
        _pixel(canvas, 10, 8, _greens);
        _pixel(canvas, 6, 9, _ink);
        _pixel(canvas, 8, 10, _copper);
      case 'greens':
        _pixel(canvas, 8, 3, _ink);
        _row(canvas, 6, 4, 3, _greens);
        _row(canvas, 4, 5, 7, _ink);
        _row(canvas, 3, 6, 6, _greens);
        _row(canvas, 8, 6, 5, _greens);
        _row(canvas, 5, 7, 7, _ink);
        _row(canvas, 7, 8, 2, _wood);
        _row(canvas, 7, 9, 2, _ink);
        _row(canvas, 8, 10, 2, _wood);
      case 'foundFood':
        _row(canvas, 4, 5, 8, _ink);
        _row(canvas, 3, 6, 10, _paper);
        _row(canvas, 3, 7, 10, _ink);
        _row(canvas, 4, 8, 8, _food);
        _row(canvas, 5, 9, 6, _ink);
        _pixel(canvas, 6, 6, _greens);
        _pixel(canvas, 9, 6, _copper);
      case 'cleanedFood':
        _row(canvas, 4, 5, 8, _ink);
        _row(canvas, 3, 6, 10, _paper);
        _row(canvas, 4, 7, 8, _food);
        _row(canvas, 5, 8, 6, _light);
        _row(canvas, 5, 9, 6, _ink);
        _pixel(canvas, 6, 6, _greens);
        _pixel(canvas, 9, 6, _greens);
      case 'starchFood':
        _row(canvas, 5, 4, 6, _ink);
        _row(canvas, 4, 5, 8, _paper);
        _row(canvas, 3, 6, 10, _ink);
        _row(canvas, 4, 7, 8, _light);
        _row(canvas, 5, 8, 6, _paper);
        _row(canvas, 6, 9, 4, _ink);
        _pixel(canvas, 7, 6, _food);
      case 'herb':
        _row(canvas, 7, 3, 2, _greens);
        _row(canvas, 5, 4, 3, _ink);
        _row(canvas, 8, 5, 3, _greens);
        _row(canvas, 4, 6, 3, _greens);
        _row(canvas, 7, 7, 3, _ink);
        _row(canvas, 8, 8, 2, _wood);
        _row(canvas, 7, 9, 2, _wood);
        _pixel(canvas, 7, 10, _ink);
      case 'salt':
        _row(canvas, 5, 5, 6, _ink);
        _row(canvas, 4, 6, 8, _paper);
        _row(canvas, 4, 7, 8, _ink);
        _row(canvas, 5, 8, 6, _light);
        _row(canvas, 6, 9, 4, _ink);
        _pixel(canvas, 6, 6, _light);
        _pixel(canvas, 9, 7, _light);
      case 'seasoningPacket':
        _row(canvas, 5, 3, 6, _ink);
        _row(canvas, 4, 4, 8, _paper);
        _row(canvas, 3, 5, 10, _ink);
        _row(canvas, 4, 6, 8, _paper);
        _row(canvas, 5, 7, 6, _copper);
        _row(canvas, 4, 8, 8, _paper);
        _row(canvas, 3, 9, 10, _ink);
        _row(canvas, 5, 10, 6, _paper);
        _row(canvas, 6, 11, 4, _ink);
      case 'seasoningBlend':
        _row(canvas, 5, 3, 6, _ink);
        _row(canvas, 4, 4, 8, _copper);
        _row(canvas, 4, 5, 8, _ink);
        for (var y = 6; y < 11; y++) {
          _row(canvas, 5, y, 6, y.isEven ? _food : _greens);
        }
        _row(canvas, 4, 11, 8, _ink);
        _pixel(canvas, 6, 7, _light);
      case 'basicSoup':
        _soupBowl(canvas, _soup);
      case 'fishSoup':
        _soupBowl(canvas, _water);
        _pixel(canvas, 7, 6, _food);
        _pixel(canvas, 9, 7, _paper);
      case 'vegetableSoup':
        _soupBowl(canvas, _greens);
        _pixel(canvas, 6, 6, _greens);
        _pixel(canvas, 9, 7, _light);
      case 'sharedMeal':
        _row(canvas, 3, 4, 10, _ink);
        _row(canvas, 4, 5, 8, _paper);
        _row(canvas, 3, 6, 10, _ink);
        _row(canvas, 4, 7, 8, _food);
        _row(canvas, 3, 8, 10, _ink);
        _row(canvas, 4, 9, 8, _paper);
        _row(canvas, 3, 10, 10, _ink);
        _pixel(canvas, 6, 6, _greens);
        _pixel(canvas, 9, 8, _water);
      case 'failedMeal':
        _row(canvas, 4, 5, 8, _ink);
        _row(canvas, 3, 6, 10, _copper);
        _row(canvas, 4, 7, 8, _ink);
        _pixel(canvas, 5, 8, _food);
        _pixel(canvas, 10, 8, _charcoal);
        _row(canvas, 5, 9, 6, _ink);
        _pixel(canvas, 11, 5, _charcoal);
      case 'reliefMeal':
        _row(canvas, 3, 4, 10, _ink);
        _row(canvas, 2, 5, 12, _paper);
        _row(canvas, 2, 6, 12, _ink);
        _row(canvas, 3, 7, 10, _food);
        _row(canvas, 3, 8, 10, _paper);
        _row(canvas, 2, 9, 12, _ink);
        _row(canvas, 3, 10, 10, _paper);
        _row(canvas, 3, 11, 10, _ink);
        _pixel(canvas, 5, 7, _greens);
        _pixel(canvas, 9, 7, _water);
      default:
        _fish(canvas);
    }
  }

  void _soupBowl(Canvas canvas, Color filling) {
    _row(canvas, 4, 5, 8, _ink);
    _row(canvas, 3, 6, 10, filling);
    _row(canvas, 4, 7, 8, _ink);
    _row(canvas, 5, 8, 6, _paper);
    _row(canvas, 6, 9, 4, _ink);
    _pixel(canvas, 5, 10, _ink);
    _pixel(canvas, 10, 10, _ink);
  }

  void _paperSheet(Canvas canvas) {
    for (var y = 2; y < 14; y++) {
      _row(canvas, 3, y, 10, _paper);
    }
    _row(canvas, 3, 2, 8, _ink);
    _row(canvas, 3, 13, 10, _ink);
    _pixel(canvas, 11, 3, _light);
    _row(canvas, 5, 6, 6, _metal);
    _row(canvas, 5, 8, 5, _metal);
    if (crafted) _pixel(canvas, 10, 11, _copper);
  }

  void _paperMaterial(Canvas canvas) {
    switch (streetScrapPaperGlyphFor(itemId)) {
      case 'paperScrap':
        _row(canvas, 5, 4, 6, _ink);
        _row(canvas, 4, 5, 8, _paper);
        _row(canvas, 3, 6, 9, _ink);
        _row(canvas, 5, 7, 6, _light);
        _row(canvas, 4, 8, 7, _ink);
        _pixel(canvas, 11, 9, _paper);
        _pixel(canvas, 5, 10, _ink);
      case 'pulp':
        _row(canvas, 5, 4, 6, _ink);
        _row(canvas, 4, 5, 8, _paper);
        _row(canvas, 3, 6, 10, _ink);
        _row(canvas, 4, 7, 8, _light);
        _row(canvas, 4, 8, 8, _paper);
        _row(canvas, 5, 9, 6, _ink);
        _pixel(canvas, 6, 6, _light);
        _pixel(canvas, 9, 8, _paper);
      case 'paperBoard':
        _row(canvas, 3, 3, 10, _ink);
        for (var y = 4; y < 12; y++) {
          _row(canvas, 4, y, 8, y.isEven ? _paper : _light);
          _pixel(canvas, 3, y, _ink);
          _pixel(canvas, 12, y, _ink);
        }
        _row(canvas, 3, 12, 10, _ink);
        _row(canvas, 5, 6, 6, _wood);
      case 'packaging':
        _row(canvas, 5, 3, 6, _ink);
        _row(canvas, 4, 4, 8, _paper);
        _row(canvas, 3, 5, 10, _ink);
        _row(canvas, 4, 6, 8, _light);
        _row(canvas, 4, 7, 8, _paper);
        _row(canvas, 3, 8, 10, _ink);
        _row(canvas, 4, 9, 8, _paper);
        _row(canvas, 5, 10, 6, _ink);
        _pixel(canvas, 7, 6, _copper);
      case 'paperBundle':
        _row(canvas, 4, 4, 8, _ink);
        _row(canvas, 3, 5, 10, _paper);
        _row(canvas, 3, 6, 10, _ink);
        _row(canvas, 4, 7, 8, _light);
        _row(canvas, 3, 8, 10, _ink);
        _row(canvas, 3, 9, 10, _paper);
        _row(canvas, 4, 10, 8, _ink);
        _row(canvas, 7, 5, 2, _copper);
        _row(canvas, 7, 8, 2, _copper);
      default:
        _paperSheet(canvas);
    }
  }

  void _plasticMaterial(Canvas canvas) {
    switch (streetScrapPlasticGlyphFor(itemId)) {
      case 'plasticScrap':
        _row(canvas, 5, 4, 6, _ink);
        _row(canvas, 4, 5, 8, _water);
        _row(canvas, 3, 6, 10, _ink);
        _row(canvas, 4, 7, 8, _water);
        _row(canvas, 5, 8, 6, _ink);
        _pixel(canvas, 4, 9, _water);
        _pixel(canvas, 10, 9, _ink);
      case 'plasticSheet':
        _row(canvas, 4, 3, 8, _ink);
        for (var y = 4; y < 12; y++) {
          _row(canvas, 3, y, 10, _water);
        }
        _row(canvas, 4, 12, 8, _ink);
        _row(canvas, 5, 5, 6, _light);
        _pixel(canvas, 4, 10, _ink);
      case 'floatPart':
        _row(canvas, 6, 3, 4, _ink);
        _row(canvas, 5, 4, 6, _paper);
        _row(canvas, 4, 5, 8, _ink);
        _row(canvas, 4, 6, 8, _copper);
        _row(canvas, 5, 7, 6, _ink);
        _row(canvas, 7, 8, 2, _water);
        _row(canvas, 7, 9, 2, _ink);
        _row(canvas, 6, 10, 4, _metal);
      case 'plasticSeal':
        _row(canvas, 4, 4, 8, _ink);
        _row(canvas, 3, 5, 10, _water);
        _row(canvas, 3, 6, 10, _ink);
        _row(canvas, 4, 7, 8, _water);
        _row(canvas, 5, 8, 6, _ink);
        _row(canvas, 6, 5, 4, _light);
        _row(canvas, 6, 7, 4, _copper);
      case 'plasticBundle':
        _row(canvas, 4, 4, 8, _ink);
        _row(canvas, 3, 5, 10, _water);
        _row(canvas, 3, 6, 10, _ink);
        _row(canvas, 4, 7, 8, _water);
        _row(canvas, 3, 8, 10, _ink);
        _row(canvas, 3, 9, 10, _water);
        _row(canvas, 4, 10, 8, _ink);
        _row(canvas, 7, 5, 2, _copper);
        _row(canvas, 7, 8, 2, _copper);
      default:
        _plasticObject(canvas);
    }
  }

  void _plasticObject(Canvas canvas) {
    _row(canvas, 6, 2, 4, _ink);
    _row(canvas, 5, 3, 6, _metal);
    _row(canvas, 4, 4, 8, _ink);
    for (var y = 5; y < 12; y++) {
      _row(canvas, 3, y, 10, _metal);
    }
    _row(canvas, 4, 12, 8, _ink);
    _row(canvas, 5, 6, 2, _light);
    _row(canvas, 5, 9, 6, _water);
    if (crafted) _pixel(canvas, 10, 8, _copper);
  }

  void _tool(Canvas canvas) {
    for (var i = 0; i < 7; i++) {
      _pixel(canvas, 4 + i, 10 - i, _metal);
    }
    _pixel(canvas, 10, 4, _ink);
    _row(canvas, 9, 3, 4, _ink);
    _row(canvas, 10, 4, 3, _light);
    for (var i = 0; i < 4; i++) {
      _pixel(canvas, 4 + i, 10 + i, _wood);
    }
    _pixel(canvas, 5, 11, _ink);
    if (crafted) _pixel(canvas, 7, 8, _copper);
  }

  void _toolMaterial(Canvas canvas) {
    switch (streetScrapToolGlyphFor(itemId)) {
      case 'needle':
        for (var i = 0; i < 9; i++) {
          _pixel(canvas, 4 + i, 11 - i, _metal);
        }
        _pixel(canvas, 11, 3, _ink);
        _pixel(canvas, 12, 4, _ink);
        _pixel(canvas, 5, 12, _ink);
      case 'paperMould':
        _row(canvas, 4, 3, 8, _ink);
        _row(canvas, 3, 4, 2, _ink);
        _row(canvas, 11, 4, 2, _ink);
        _row(canvas, 3, 5, 2, _wood);
        _row(canvas, 11, 5, 2, _wood);
        _row(canvas, 3, 6, 2, _ink);
        _row(canvas, 11, 6, 2, _ink);
        _row(canvas, 4, 7, 8, _wood);
        _row(canvas, 5, 5, 6, _paper);
        _row(canvas, 5, 6, 6, _light);
      case 'awl':
        for (var i = 0; i < 8; i++) {
          _pixel(canvas, 5 + i, 4 + i, _metal);
        }
        _row(canvas, 3, 4, 4, _wood);
        _row(canvas, 3, 5, 3, _ink);
        _pixel(canvas, 12, 11, _ink);
      case 'crowbar':
        _row(canvas, 4, 10, 7, _copper);
        _row(canvas, 8, 5, 3, _metal);
        _row(canvas, 10, 4, 2, _ink);
        _row(canvas, 9, 5, 2, _ink);
        _pixel(canvas, 8, 6, _ink);
        _row(canvas, 3, 11, 3, _ink);
        _pixel(canvas, 10, 9, _light);
      case 'pliers':
        _pixel(canvas, 7, 4, _ink);
        _pixel(canvas, 8, 5, _metal);
        _pixel(canvas, 6, 5, _metal);
        for (var i = 0; i < 5; i++) {
          _pixel(canvas, 7 - i, 6 + i, _ink);
          _pixel(canvas, 8 + i, 6 + i, _ink);
        }
        for (var i = 0; i < 5; i++) {
          _pixel(canvas, 6 - i, 7 + i, _copper);
          _pixel(canvas, 9 + i, 7 + i, _wood);
        }
      case 'repairKit':
        _row(canvas, 5, 3, 6, _ink);
        _row(canvas, 4, 4, 8, _copper);
        _row(canvas, 3, 5, 10, _ink);
        for (var y = 6; y < 11; y++) {
          _row(canvas, 4, y, 8, _metal);
        }
        _row(canvas, 3, 11, 10, _ink);
        _row(canvas, 6, 7, 4, _light);
      case 'basicRod' || 'repairedRod' || 'advancedRod':
        _toolRod(canvas, streetScrapToolGlyphFor(itemId));
      case 'pot':
        _row(canvas, 4, 5, 8, _ink);
        _row(canvas, 3, 6, 10, _metal);
        _row(canvas, 4, 7, 8, _metal);
        _row(canvas, 4, 8, 8, _ink);
        _row(canvas, 5, 9, 6, _metal);
        _pixel(canvas, 5, 10, _ink);
        _pixel(canvas, 10, 10, _ink);
        _row(canvas, 11, 6, 3, _wood);
      case 'stove':
        _row(canvas, 5, 3, 6, _ink);
        _row(canvas, 4, 4, 8, _metal);
        _row(canvas, 3, 5, 10, _ink);
        _row(canvas, 4, 6, 8, _copper);
        _row(canvas, 5, 7, 6, _ink);
        _row(canvas, 4, 8, 2, _metal);
        _row(canvas, 10, 8, 2, _metal);
        _row(canvas, 3, 9, 3, _ink);
        _row(canvas, 10, 9, 3, _ink);
        _row(canvas, 3, 10, 10, _metal);
      case 'cookKit':
        _row(canvas, 4, 4, 8, _ink);
        _row(canvas, 3, 5, 10, _copper);
        _row(canvas, 3, 6, 10, _ink);
        _row(canvas, 4, 7, 8, _metal);
        _row(canvas, 3, 8, 10, _ink);
        _row(canvas, 4, 9, 8, _copper);
        _row(canvas, 4, 10, 8, _ink);
        _row(canvas, 6, 6, 4, _light);
      case 'condenser':
        _row(canvas, 6, 3, 4, _ink);
        _row(canvas, 5, 4, 6, _water);
        _row(canvas, 4, 5, 8, _ink);
        _row(canvas, 5, 6, 6, _water);
        _row(canvas, 6, 7, 4, _ink);
        _row(canvas, 7, 8, 2, _metal);
        _row(canvas, 5, 9, 6, _ink);
        _row(canvas, 4, 10, 8, _wood);
        _row(canvas, 3, 11, 10, _ink);
      case 'fishingRig':
        _row(canvas, 4, 4, 8, _ink);
        _pixel(canvas, 5, 5, _metal);
        _row(canvas, 6, 6, 4, _metal);
        _row(canvas, 8, 7, 2, _ink);
        _row(canvas, 9, 8, 2, _metal);
        _pixel(canvas, 10, 10, _ink);
        _pixel(canvas, 9, 11, _metal);
      case 'float':
        _row(canvas, 7, 3, 2, _ink);
        _row(canvas, 6, 4, 4, _water);
        _row(canvas, 5, 5, 6, _ink);
        _row(canvas, 5, 6, 6, _copper);
        _row(canvas, 6, 7, 4, _ink);
        _row(canvas, 7, 8, 2, _metal);
        _row(canvas, 7, 9, 2, _ink);
      case 'basicBait':
        _row(canvas, 5, 5, 6, _ink);
        _row(canvas, 4, 6, 8, _food);
        _row(canvas, 5, 7, 6, _ink);
        _pixel(canvas, 5, 8, _food);
        _pixel(canvas, 8, 9, _food);
        _pixel(canvas, 11, 8, _ink);
        _pixel(canvas, 10, 9, _metal);
      case 'herbBait':
        _row(canvas, 6, 5, 4, _greens);
        _row(canvas, 4, 6, 8, _ink);
        _row(canvas, 5, 7, 6, _greens);
        _row(canvas, 7, 8, 2, _wood);
        _pixel(canvas, 8, 9, _ink);
        _pixel(canvas, 9, 10, _metal);
      default:
        _tool(canvas);
    }
  }

  void _containerMaterial(Canvas canvas) {
    switch (streetScrapContainerGlyphFor(itemId)) {
      case 'brokenBottle':
        _brokenBottle(canvas);
      case 'oldBottle':
        _bottle(canvas);
        _row(canvas, 5, 7, 2, _mud);
        _pixel(canvas, 10, 9, _copper);
        _pixel(canvas, 6, 11, _ink);
      case 'cleanBottle':
        _bottle(canvas);
      case 'cleanJar':
        _row(canvas, 5, 3, 6, _ink);
        _row(canvas, 4, 4, 8, _metal);
        _row(canvas, 3, 5, 10, _ink);
        for (var y = 6; y < 12; y++) {
          _row(canvas, 4, y, 8, _light);
          _pixel(canvas, 3, y, _ink);
          _pixel(canvas, 12, y, _ink);
        }
        _row(canvas, 4, 12, 8, _ink);
        _pixel(canvas, 6, 7, _water);
        _pixel(canvas, 9, 10, _water);
      case 'mealBox':
        _row(canvas, 3, 4, 10, _ink);
        _row(canvas, 2, 5, 12, _paper);
        _row(canvas, 2, 6, 12, _ink);
        _row(canvas, 3, 7, 10, _copper);
        _row(canvas, 2, 8, 12, _ink);
        _row(canvas, 3, 9, 10, _paper);
        _row(canvas, 3, 10, 10, _ink);
        _row(canvas, 6, 3, 4, _metal);
      case 'insulatedMealBox':
        _row(canvas, 3, 3, 10, _ink);
        _row(canvas, 2, 4, 12, _copper);
        _row(canvas, 2, 5, 12, _ink);
        _row(canvas, 3, 6, 10, _paper);
        _row(canvas, 3, 7, 10, _ink);
        _row(canvas, 2, 8, 12, _copper);
        _row(canvas, 2, 9, 12, _ink);
        _row(canvas, 3, 10, 10, _paper);
        _row(canvas, 4, 11, 8, _ink);
        _row(canvas, 5, 5, 6, _light);
      default:
        _plasticObject(canvas);
    }
  }

  void _storageMaterial(Canvas canvas) {
    switch (streetScrapStorageGlyphFor(itemId)) {
      case 'basicBackpack':
        _row(canvas, 6, 3, 4, _ink);
        _row(canvas, 5, 4, 6, _wood);
        _row(canvas, 4, 5, 8, _ink);
        _row(canvas, 3, 6, 10, _copper);
        _row(canvas, 3, 7, 10, _ink);
        _row(canvas, 4, 8, 8, _wood);
        _row(canvas, 4, 9, 8, _ink);
        _row(canvas, 5, 10, 6, _wood);
        _row(canvas, 5, 11, 2, _ink);
        _row(canvas, 9, 11, 2, _ink);
      case 'reinforcedBackpack':
        _row(canvas, 6, 2, 4, _ink);
        _row(canvas, 5, 3, 6, _metal);
        _row(canvas, 4, 4, 8, _ink);
        _row(canvas, 3, 5, 10, _copper);
        _row(canvas, 3, 6, 10, _ink);
        _row(canvas, 4, 7, 8, _wood);
        _row(canvas, 4, 8, 8, _ink);
        _row(canvas, 5, 9, 6, _copper);
        _row(canvas, 4, 10, 8, _ink);
        _row(canvas, 5, 11, 2, _metal);
        _row(canvas, 9, 11, 2, _metal);
      case 'weatherproofBag':
        _row(canvas, 5, 3, 6, _ink);
        _row(canvas, 4, 4, 8, _water);
        _row(canvas, 3, 5, 10, _ink);
        _row(canvas, 3, 6, 10, _water);
        _row(canvas, 3, 7, 10, _ink);
        _row(canvas, 4, 8, 8, _water);
        _row(canvas, 4, 9, 8, _ink);
        _row(canvas, 5, 10, 6, _water);
        _row(canvas, 5, 11, 6, _ink);
        _pixel(canvas, 8, 6, _light);
      case 'woodCrate':
        _row(canvas, 3, 4, 10, _ink);
        for (var y = 5; y < 12; y++) {
          _row(canvas, 3, y, 10, _wood);
        }
        _row(canvas, 3, 12, 10, _ink);
        _row(canvas, 4, 6, 8, _ink);
        _row(canvas, 4, 10, 8, _ink);
        _row(canvas, 7, 5, 2, _copper);
      case 'reinforcedChest':
        _row(canvas, 4, 3, 8, _ink);
        _row(canvas, 3, 4, 10, _metal);
        _row(canvas, 2, 5, 12, _ink);
        _row(canvas, 3, 6, 10, _copper);
        _row(canvas, 3, 7, 10, _ink);
        _row(canvas, 3, 8, 10, _metal);
        _row(canvas, 2, 9, 12, _ink);
        _row(canvas, 3, 10, 10, _metal);
        _row(canvas, 4, 11, 8, _ink);
        _row(canvas, 7, 7, 2, _light);
      default:
        _scrapBundle(canvas);
    }
  }

  void _structureMaterial(Canvas canvas) {
    switch (streetScrapStructureGlyphFor(itemId)) {
      case 'raft':
        _row(canvas, 3, 9, 10, _ink);
        _row(canvas, 2, 10, 12, _wood);
        _row(canvas, 3, 11, 10, _ink);
        _row(canvas, 4, 6, 8, _wood);
        _row(canvas, 5, 5, 6, _ink);
        _row(canvas, 7, 4, 2, _metal);
        _row(canvas, 5, 7, 6, _ink);
      case 'tarpShelter':
        _pixel(canvas, 8, 3, _ink);
        _row(canvas, 7, 4, 2, _wood);
        _row(canvas, 6, 5, 4, _ink);
        _row(canvas, 5, 6, 6, _water);
        _row(canvas, 4, 7, 8, _ink);
        _row(canvas, 3, 8, 10, _water);
        _row(canvas, 2, 9, 12, _ink);
        _row(canvas, 4, 10, 2, _wood);
        _row(canvas, 10, 10, 2, _wood);
      case 'foldingShelter':
        _row(canvas, 3, 4, 10, _ink);
        _row(canvas, 4, 5, 8, _copper);
        _row(canvas, 5, 6, 6, _ink);
        _row(canvas, 6, 7, 4, _water);
        _row(canvas, 7, 8, 2, _ink);
        _row(canvas, 3, 9, 2, _wood);
        _row(canvas, 11, 9, 2, _wood);
        _row(canvas, 2, 10, 4, _ink);
        _row(canvas, 10, 10, 4, _ink);
        _pixel(canvas, 8, 6, _light);
      default:
        _scrapBundle(canvas);
    }
  }

  void _toolRod(Canvas canvas, String variant) {
    for (var i = 0; i < 9; i++) {
      _pixel(canvas, 5 + i, 11 - i, _wood);
    }
    _pixel(canvas, 13, 2, _ink);
    _pixel(canvas, 13, 3, _metal);
    _pixel(canvas, 4, 12, _ink);
    _row(canvas, 4, 10, 3, variant == 'basicRod' ? _ink : _copper);
    if (variant == 'repairedRod') {
      _row(canvas, 8, 7, 2, _paper);
      _row(canvas, 9, 6, 2, _paper);
    } else if (variant == 'advancedRod') {
      _pixel(canvas, 8, 8, _copper);
      _pixel(canvas, 9, 7, _light);
      _pixel(canvas, 10, 6, _copper);
      _pixel(canvas, 5, 11, _metal);
    }
  }

  void _scrapBundle(Canvas canvas) {
    _row(canvas, 4, 3, 8, _ink);
    _row(canvas, 3, 4, 10, _ink);
    for (var y = 5; y < 11; y++) {
      _row(canvas, 3, y, 10, y.isEven ? _copper : _metal);
    }
    _row(canvas, 4, 11, 8, _ink);
    _pixel(canvas, 5, 6, _paper);
    _pixel(canvas, 9, 8, _wood);
    if (crafted) _row(canvas, 5, 7, 6, _ink);
  }

  void _craftMark(Canvas canvas) {
    _pixel(canvas, 13, 2, _ink);
    _pixel(canvas, 12, 3, _copper);
    _pixel(canvas, 13, 3, _copper);
  }

  @override
  bool shouldRepaint(covariant _StreetScrapPixelPainter oldDelegate) =>
      itemId != oldDelegate.itemId ||
      contentItemId != oldDelegate.contentItemId ||
      crafted != oldDelegate.crafted;
}
