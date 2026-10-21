import 'package:flutter/material.dart';
import 'package:taiwan_brawl_game_mini_royale/taiwan_brawl_game_mini_royale.dart'
    as mini_royale;

import 'game_module_home_entry.dart';
import 'game_module_manifest.dart';
import 'game_module_registration.dart';
import 'mini_royale/room_invite_handler.dart';
import 'mini_royale_game_routes.dart';

final miniRoyaleGameRegistration = GameModuleRegistration(
  manifest: GameModuleManifest(
    moduleId: mini_royale.miniRoyaleModuleId,
    displayName: 'Mini Royale',
    description: 'A multiplayer strategy battle.',
    packageVersion: mini_royale.miniRoyaleManifest.packageVersion,
    minimumShellVersion: mini_royale.miniRoyaleManifest.minimumShellVersion,
    hostApiRange: mini_royale.miniRoyaleHostApiRange,
    dataSchemaVersion: mini_royale.miniRoyaleManifest.dataSchemaVersion,
    platforms: mini_royale.miniRoyaleManifest.platforms
        .map(GamePlatform.values.byName)
        .toList(growable: false),
    multiplayer: GameMultiplayerManifest(
      protocolVersion: mini_royale.miniRoyaleManifest.protocolVersion,
      compatibleProtocolRange:
          mini_royale.miniRoyaleManifest.compatibleProtocolRange,
      rulesetId: mini_royale.miniRoyaleManifest.rulesetId,
      rulesetVersion: mini_royale.miniRoyaleManifest.rulesetVersion,
      gameplayContentDigest:
          mini_royale.miniRoyaleManifest.gameplayContentDigest,
    ),
    supportedResourceSchemas: mini_royale.miniRoyaleSupportedResourceSchemas,
    resources: const [],
  ),
  routes: miniRoyaleGameModuleRouteBuilders,
  homeEntries: const [
    GameModuleHomeEntry(
      moduleId: mini_royale.miniRoyaleModuleId,
      titleKey: 'Mini Royale Lobby Battle',
      descriptionKey: 'Join a lobby, build your strategy and fight to the top.',
      tag: 'MULTIPLAYER',
      icon: Icons.sports_esports_outlined,
      accentColor: Color(0xFF0070D1),
      routeName: '/royale-lobby',
      isPrimary: true,
    ),
  ],
  homeCollections: const [
    GameModuleHomeCollectionEntry(
      moduleId: mini_royale.miniRoyaleModuleId,
      titleKey: 'Mini Royale Deck Builder',
      descriptionKey: 'Build and manage your decks',
      icon: Icons.style_outlined,
      routeName: '/royale-deck',
    ),
  ],
  libraryExtension: (_) => const mini_royale.MiniRoyaleLibrarySettingsSection(),
  roomInviteHandler: const MiniRoyaleRoomInviteHandler(),
  resourceMigrations: {
    '${mini_royale.miniRoyaleModuleId}:${mini_royale.miniRoyaleGameplayRulesResourceId}':
        mini_royale.validateMiniRoyaleGameplayRulesPayload,
    '${mini_royale.miniRoyaleModuleId}:${mini_royale.miniRoyaleArenaPresentationResourceId}':
        mini_royale.validateMiniRoyaleArenaPresentationPayload,
  },
);
