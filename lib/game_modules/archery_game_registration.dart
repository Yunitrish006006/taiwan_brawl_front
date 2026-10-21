import 'package:flutter/material.dart';
import 'package:taiwan_brawl_game_archery/archery_game_module.dart' as archery;

import 'archery_game_routes.dart';
import 'game_module_home_entry.dart';
import 'game_module_manifest.dart';
import 'game_module_registration.dart';

final archeryGameRegistration = GameModuleRegistration(
  manifest: GameModuleManifest(
    moduleId: archery.archeryGameManifest.moduleId,
    displayName: 'Archery Game',
    description: 'A single-player archery challenge.',
    packageVersion: archery.archeryGameManifest.packageVersion,
    minimumShellVersion: archery.archeryGameManifest.minimumShellVersion,
    hostApiRange: archery.archeryGameHostApiRange,
    dataSchemaVersion: archery.archeryGameManifest.dataSchemaVersion,
    platforms: archery.archeryGameManifest.platforms
        .map(GamePlatform.values.byName)
        .toList(growable: false),
    supportedResourceSchemas: archery.archeryGameSupportedResourceSchemas,
    resources: const [],
  ),
  routes: archeryGameModuleRouteBuilders,
  homeEntries: const [
    GameModuleHomeEntry(
      moduleId: archery.archeryGameModuleId,
      titleKey: 'Archery Game',
      descriptionKey:
          'Test your precision in this single-player archery challenge.',
      tag: 'SOLO',
      icon: Icons.architecture,
      accentColor: Color(0xFF34C759),
      routeName: '/archery',
    ),
  ],
  resourceMigrations: {
    '${archery.archeryGameModuleId}:${archery.archeryRulesResourceId}':
        archery.validateArcheryRulesPayload,
  },
);
