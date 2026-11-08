import 'package:flutter/material.dart';
import 'package:taiwan_brawl_game_street_scrap/street_scrap_content.dart'
    as street_scrap;

import 'game_module_home_entry.dart';
import 'game_module_manifest.dart';
import 'game_module_registration.dart';
import 'street_scrap_game_routes.dart';

final streetScrapGameRegistration = GameModuleRegistration(
  manifest: GameModuleManifest.fromPackageJson(
    Map<String, dynamic>.from(street_scrap.StreetScrapGameManifest().toJson()),
  ),
  routes: streetScrapGameModuleRouteBuilders,
  homeEntries: const [
    GameModuleHomeEntry(
      moduleId: street_scrap.streetScrapModuleId,
      titleKey: '街角拾荒',
      descriptionKey: '在街區翻找材料、修補生活用品，完成街坊委託。',
      tag: 'SOLO',
      icon: Icons.recycling_outlined,
      accentColor: Color(0xFF6C8382),
      routeName: '/street-scrap',
    ),
  ],
  resourceMigrations: {
    '${street_scrap.streetScrapModuleId}:${street_scrap.streetScrapContentResourceId}':
        street_scrap.validateStreetScrapContentBytes,
    '${street_scrap.streetScrapModuleId}:${street_scrap.streetScrapChapter5ResourceId}':
        street_scrap.validateStreetScrapChapter5ContentBytes,
    '${street_scrap.streetScrapModuleId}:${street_scrap.streetScrapArtResourceId}':
        street_scrap.validateStreetScrapArtBytes,
    '${street_scrap.streetScrapModuleId}:${street_scrap.streetScrapThreadSpoolArtResourceId}':
        street_scrap.validateStreetScrapArtBytes,
    '${street_scrap.streetScrapModuleId}:${street_scrap.streetScrapMaterialAtlasResourceId}':
        street_scrap.validateStreetScrapMaterialAtlasBytes,
    '${street_scrap.streetScrapModuleId}:${street_scrap.streetScrapToolAtlasResourceId}':
        street_scrap.validateStreetScrapToolAtlasBytes,
    '${street_scrap.streetScrapModuleId}:${street_scrap.streetScrapMaterialPackArtResourceId}':
        street_scrap.validateStreetScrapMaterialPackArtBytes,
    '${street_scrap.streetScrapModuleId}:${street_scrap.streetScrapMineralPackArtResourceId}':
        street_scrap.validateStreetScrapArtBytes,
    '${street_scrap.streetScrapModuleId}:${street_scrap.streetScrapWoodChipBundleArtResourceId}':
        street_scrap.validateStreetScrapArtBytes,
    '${street_scrap.streetScrapModuleId}:${street_scrap.streetScrapFishingSceneArtResourceId}':
        street_scrap.validateStreetScrapFishingSceneArtBytes,
    '${street_scrap.streetScrapModuleId}:${street_scrap.streetScrapProtagonistArtResourceId}':
        street_scrap.validateStreetScrapProtagonistArtBytes,
  },
);
