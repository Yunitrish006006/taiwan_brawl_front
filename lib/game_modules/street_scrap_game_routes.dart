import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:taiwan_brawl_game_street_scrap/taiwan_brawl_game_street_scrap.dart'
    deferred as street_scrap_page;
import 'package:taiwan_brawl_game_street_scrap/street_scrap_localizations.dart'
    as street_scrap_i18n;
import 'package:taiwan_brawl_game_street_scrap/street_scrap_content.dart'
    as street_scrap;
import 'package:taiwan_brawl_game_street_scrap/street_scrap_progress.dart'
    as street_scrap_progress;

import '../pages/game/game_library_page.dart';
import '../services/auth_service.dart';
import '../services/game_library_controller.dart';
import '../services/game_resource_library_service.dart';
import '../services/locale_provider.dart';
import 'game_module_manifest.dart';
import 'deferred_game_module_page.dart';

const streetScrapGameModuleRouteBuilders = <String, WidgetBuilder>{
  '/street-scrap': _streetScrapRoute,
};

Widget _streetScrapRoute(BuildContext context) {
  if (!context.read<GameLibraryController>().isModuleEnabled(
    'game.street-scrap',
  )) {
    return const GameLibraryPage();
  }
  final library = context.read<GameLibraryController>();
  final record = library.resourceRecord(
    street_scrap.streetScrapModuleId,
    street_scrap.streetScrapContentResourceId,
  );
  final contentInstalled =
      record != null &&
      record.status == GameResourceInstallStatus.installed &&
      record.moduleId == street_scrap.streetScrapModuleId &&
      record.resourceId == street_scrap.streetScrapContentResourceId &&
      record.payloadSchemaVersion ==
          street_scrap.streetScrapContentSchemaVersion &&
      record.version.isNotEmpty &&
      RegExp(r'^[a-fA-F0-9]{64}$').hasMatch(record.sha256);
  final chapter5Record = library.resourceRecord(
    street_scrap.streetScrapModuleId,
    street_scrap.streetScrapChapter5ResourceId,
  );
  final chapter5Installed =
      chapter5Record != null &&
      chapter5Record.status == GameResourceInstallStatus.installed &&
      chapter5Record.moduleId == street_scrap.streetScrapModuleId &&
      chapter5Record.resourceId == street_scrap.streetScrapChapter5ResourceId &&
      chapter5Record.payloadSchemaVersion ==
          street_scrap.streetScrapContentSchemaVersion &&
      chapter5Record.version.isNotEmpty &&
      RegExp(r'^[a-fA-F0-9]{64}$').hasMatch(chapter5Record.sha256);
  final artRecord = library.resourceRecord(
    street_scrap.streetScrapModuleId,
    street_scrap.streetScrapArtResourceId,
  );
  final artInstalled =
      artRecord != null &&
      artRecord.status == GameResourceInstallStatus.installed &&
      artRecord.moduleId == street_scrap.streetScrapModuleId &&
      artRecord.resourceId == street_scrap.streetScrapArtResourceId &&
      artRecord.payloadSchemaVersion ==
          street_scrap.streetScrapArtSchemaVersion &&
      artRecord.version.isNotEmpty &&
      RegExp(r'^[a-fA-F0-9]{64}$').hasMatch(artRecord.sha256);
  final threadSpoolArtRecord = library.resourceRecord(
    street_scrap.streetScrapModuleId,
    street_scrap.streetScrapThreadSpoolArtResourceId,
  );
  final threadSpoolArtInstalled =
      threadSpoolArtRecord != null &&
      threadSpoolArtRecord.status == GameResourceInstallStatus.installed &&
      threadSpoolArtRecord.moduleId == street_scrap.streetScrapModuleId &&
      threadSpoolArtRecord.resourceId ==
          street_scrap.streetScrapThreadSpoolArtResourceId &&
      threadSpoolArtRecord.payloadSchemaVersion ==
          street_scrap.streetScrapThreadSpoolArtSchemaVersion &&
      threadSpoolArtRecord.version.isNotEmpty &&
      RegExp(r'^[a-fA-F0-9]{64}$').hasMatch(threadSpoolArtRecord.sha256);
  final materialAtlasRecord = library.resourceRecord(
    street_scrap.streetScrapModuleId,
    street_scrap.streetScrapMaterialAtlasResourceId,
  );
  final materialAtlasInstalled =
      materialAtlasRecord != null &&
      materialAtlasRecord.status == GameResourceInstallStatus.installed &&
      materialAtlasRecord.moduleId == street_scrap.streetScrapModuleId &&
      materialAtlasRecord.resourceId ==
          street_scrap.streetScrapMaterialAtlasResourceId &&
      materialAtlasRecord.payloadSchemaVersion ==
          street_scrap.streetScrapMaterialAtlasSchemaVersion &&
      materialAtlasRecord.version.isNotEmpty &&
      RegExp(r'^[a-fA-F0-9]{64}$').hasMatch(materialAtlasRecord.sha256);
  final toolAtlasRecord = library.resourceRecord(
    street_scrap.streetScrapModuleId,
    street_scrap.streetScrapToolAtlasResourceId,
  );
  final toolAtlasInstalled =
      toolAtlasRecord != null &&
      toolAtlasRecord.status == GameResourceInstallStatus.installed &&
      toolAtlasRecord.moduleId == street_scrap.streetScrapModuleId &&
      toolAtlasRecord.resourceId ==
          street_scrap.streetScrapToolAtlasResourceId &&
      toolAtlasRecord.payloadSchemaVersion ==
          street_scrap.streetScrapToolAtlasSchemaVersion &&
      toolAtlasRecord.version.isNotEmpty &&
      RegExp(r'^[a-fA-F0-9]{64}$').hasMatch(toolAtlasRecord.sha256);
  final materialPackArtRecord = library.resourceRecord(
    street_scrap.streetScrapModuleId,
    street_scrap.streetScrapMaterialPackArtResourceId,
  );
  final materialPackArtInstalled =
      materialPackArtRecord != null &&
      materialPackArtRecord.status == GameResourceInstallStatus.installed &&
      materialPackArtRecord.moduleId == street_scrap.streetScrapModuleId &&
      materialPackArtRecord.resourceId ==
          street_scrap.streetScrapMaterialPackArtResourceId &&
      materialPackArtRecord.payloadSchemaVersion ==
          street_scrap.streetScrapMaterialPackArtSchemaVersion &&
      materialPackArtRecord.version.isNotEmpty &&
      RegExp(r'^[a-fA-F0-9]{64}$').hasMatch(materialPackArtRecord.sha256);
  final mineralPackArtRecord = library.resourceRecord(
    street_scrap.streetScrapModuleId,
    street_scrap.streetScrapMineralPackArtResourceId,
  );
  final mineralPackArtInstalled =
      mineralPackArtRecord != null &&
      mineralPackArtRecord.status == GameResourceInstallStatus.installed &&
      mineralPackArtRecord.moduleId == street_scrap.streetScrapModuleId &&
      mineralPackArtRecord.resourceId ==
          street_scrap.streetScrapMineralPackArtResourceId &&
      mineralPackArtRecord.payloadSchemaVersion ==
          street_scrap.streetScrapMineralPackArtSchemaVersion &&
      mineralPackArtRecord.version.isNotEmpty &&
      RegExp(r'^[a-fA-F0-9]{64}$').hasMatch(mineralPackArtRecord.sha256);
  final woodChipBundleArtRecord = library.resourceRecord(
    street_scrap.streetScrapModuleId,
    street_scrap.streetScrapWoodChipBundleArtResourceId,
  );
  final woodChipBundleArtInstalled =
      woodChipBundleArtRecord != null &&
      woodChipBundleArtRecord.status == GameResourceInstallStatus.installed &&
      woodChipBundleArtRecord.moduleId == street_scrap.streetScrapModuleId &&
      woodChipBundleArtRecord.resourceId ==
          street_scrap.streetScrapWoodChipBundleArtResourceId &&
      woodChipBundleArtRecord.payloadSchemaVersion ==
          street_scrap.streetScrapWoodChipBundleArtSchemaVersion &&
      woodChipBundleArtRecord.version.isNotEmpty &&
      RegExp(r'^[a-fA-F0-9]{64}$').hasMatch(woodChipBundleArtRecord.sha256);
  final fishingSceneArtRecord = library.resourceRecord(
    street_scrap.streetScrapModuleId,
    street_scrap.streetScrapFishingSceneArtResourceId,
  );
  final fishingSceneArtInstalled =
      fishingSceneArtRecord != null &&
      fishingSceneArtRecord.status == GameResourceInstallStatus.installed &&
      fishingSceneArtRecord.moduleId == street_scrap.streetScrapModuleId &&
      fishingSceneArtRecord.resourceId ==
          street_scrap.streetScrapFishingSceneArtResourceId &&
      fishingSceneArtRecord.payloadSchemaVersion ==
          street_scrap.streetScrapFishingSceneArtSchemaVersion &&
      fishingSceneArtRecord.version.isNotEmpty &&
      RegExp(r'^[a-fA-F0-9]{64}$').hasMatch(fishingSceneArtRecord.sha256);
  final protagonistArtRecord = library.resourceRecord(
    street_scrap.streetScrapModuleId,
    street_scrap.streetScrapProtagonistArtResourceId,
  );
  final protagonistArtInstalled =
      protagonistArtRecord != null &&
      protagonistArtRecord.status == GameResourceInstallStatus.installed &&
      protagonistArtRecord.moduleId == street_scrap.streetScrapModuleId &&
      protagonistArtRecord.resourceId ==
          street_scrap.streetScrapProtagonistArtResourceId &&
      protagonistArtRecord.payloadSchemaVersion ==
          street_scrap.streetScrapProtagonistArtSchemaVersion &&
      protagonistArtRecord.version ==
          street_scrap.streetScrapProtagonistArtResourceVersion &&
      protagonistArtRecord.sha256 ==
          street_scrap.streetScrapProtagonistArtSha256;
  final profileId = context.select<AuthService, int?>((auth) => auth.user?.id);
  if (profileId == null) {
    return Builder(
      builder: (localizedContext) {
        final strings = street_scrap_i18n.StreetScrapLocalizations(
          localizedContext.watch<LocaleProvider>().locale,
        );
        return Scaffold(
          appBar: AppBar(title: Text(strings.text('game.title'))),
          body: Center(child: Text(strings.text('entry.loginExpired'))),
        );
      },
    );
  }
  final progressStore = context
      .read<street_scrap_progress.StreetScrapProgressStore>();
  final session = street_scrap_progress.StreetScrapSession(
    profileScope: profileId.toString(),
    store: progressStore,
    contentVersions: {
      if (contentInstalled)
        street_scrap.streetScrapContentResourceId: record.version,
      if (chapter5Installed)
        street_scrap.streetScrapChapter5ResourceId: chapter5Record.version,
      if (contentInstalled)
        street_scrap.streetScrapActiveContentVersionKey:
            '${record.version}+${chapter5Installed ? chapter5Record.version : 'none'}',
    },
    compatibleContentVersions: {
      if (contentInstalled)
        street_scrap.streetScrapContentResourceId:
            street_scrap.streetScrapSaveCompatibleBaseContentVersions[record
                .version] ??
            const <String>{},
    },
    rulesetVersion: street_scrap.streetScrapRulesetVersion,
  );
  return DeferredGameModulePage(
    loadLibrary: street_scrap_page.loadLibrary,
    builder: (_) => Builder(
      builder: (localizedContext) => street_scrap_i18n.StreetScrapLocalizationsScope(
        locale: localizedContext.watch<LocaleProvider>().locale,
        child: street_scrap_page.StreetScrapProgressEntryPage(
          key: ValueKey('street-scrap:$profileId'),
          session: session,
          contentInstalled: contentInstalled,
          chapter5Installed: chapter5Installed,
          artInstalled: artInstalled,
          readArt: () async {
            if (!artInstalled) return null;
            try {
              return await context
                  .read<GameResourceLibraryService>()
                  .contentStore
                  .readActive(
                    street_scrap.streetScrapModuleId,
                    street_scrap.streetScrapArtResourceId,
                  );
            } on Object {
              return null;
            }
          },
          threadSpoolArtInstalled: threadSpoolArtInstalled,
          readThreadSpoolArt: () async {
            if (!threadSpoolArtInstalled) return null;
            try {
              return await context
                  .read<GameResourceLibraryService>()
                  .contentStore
                  .readActive(
                    street_scrap.streetScrapModuleId,
                    street_scrap.streetScrapThreadSpoolArtResourceId,
                  );
            } on Object {
              return null;
            }
          },
          materialAtlasInstalled: materialAtlasInstalled,
          readMaterialAtlas: () async {
            if (!materialAtlasInstalled) return null;
            try {
              return await context
                  .read<GameResourceLibraryService>()
                  .contentStore
                  .readActive(
                    street_scrap.streetScrapModuleId,
                    street_scrap.streetScrapMaterialAtlasResourceId,
                  );
            } on Object {
              return null;
            }
          },
          toolAtlasInstalled: toolAtlasInstalled,
          readToolAtlas: () async {
            if (!toolAtlasInstalled) return null;
            try {
              return await context
                  .read<GameResourceLibraryService>()
                  .contentStore
                  .readActive(
                    street_scrap.streetScrapModuleId,
                    street_scrap.streetScrapToolAtlasResourceId,
                  );
            } on Object {
              return null;
            }
          },
          materialPackArtInstalled: materialPackArtInstalled,
          readMaterialPackArt: () async {
            if (!materialPackArtInstalled) return null;
            try {
              return await context
                  .read<GameResourceLibraryService>()
                  .contentStore
                  .readActive(
                    street_scrap.streetScrapModuleId,
                    street_scrap.streetScrapMaterialPackArtResourceId,
                  );
            } on Object {
              return null;
            }
          },
          mineralPackArtInstalled: mineralPackArtInstalled,
          readMineralPackArt: () async {
            if (!mineralPackArtInstalled) return null;
            try {
              return await context
                  .read<GameResourceLibraryService>()
                  .contentStore
                  .readActive(
                    street_scrap.streetScrapModuleId,
                    street_scrap.streetScrapMineralPackArtResourceId,
                  );
            } on Object {
              return null;
            }
          },
          woodChipBundleArtInstalled: woodChipBundleArtInstalled,
          readWoodChipBundleArt: () async {
            if (!woodChipBundleArtInstalled) return null;
            try {
              return await context
                  .read<GameResourceLibraryService>()
                  .contentStore
                  .readActive(
                    street_scrap.streetScrapModuleId,
                    street_scrap.streetScrapWoodChipBundleArtResourceId,
                  );
            } on Object {
              return null;
            }
          },
          fishingSceneArtInstalled: fishingSceneArtInstalled,
          readFishingSceneArt: () async {
            if (!fishingSceneArtInstalled) return null;
            try {
              return await context
                  .read<GameResourceLibraryService>()
                  .contentStore
                  .readActive(
                    street_scrap.streetScrapModuleId,
                    street_scrap.streetScrapFishingSceneArtResourceId,
                  );
            } on Object {
              return null;
            }
          },
          protagonistArtInstalled: protagonistArtInstalled,
          readProtagonistArt: () async {
            if (!protagonistArtInstalled) return null;
            try {
              return await context
                  .read<GameResourceLibraryService>()
                  .contentStore
                  .readActive(
                    street_scrap.streetScrapModuleId,
                    street_scrap.streetScrapProtagonistArtResourceId,
                  );
            } on Object {
              return null;
            }
          },
          readContent: () async {
            try {
              final store = context
                  .read<GameResourceLibraryService>()
                  .contentStore;
              final base = await store.readActive(
                street_scrap.streetScrapModuleId,
                street_scrap.streetScrapContentResourceId,
              );
              final extension = chapter5Installed
                  ? await store.readActive(
                      street_scrap.streetScrapModuleId,
                      street_scrap.streetScrapChapter5ResourceId,
                    )
                  : null;
              if (base == null || (chapter5Installed && extension == null)) {
                return null;
              }
              final merged = street_scrap.mergeStreetScrapContentPayloads(
                base: utf8.decode(base, allowMalformed: false),
                chapter5: extension == null
                    ? null
                    : utf8.decode(extension, allowMalformed: false),
              );
              return Uint8List.fromList(utf8.encode(merged));
            } on Object {
              // Installed metadata without readable local bytes is fail-closed in
              // the game page; it must not prevent the rest of the App from opening.
              return null;
            }
          },
          onOpenLibrary: () async {
            await Navigator.of(context).pushNamed('/game-library');
            // Release the previous route's profile writer before building its
            // replacement. The replacement session waits for closing leases,
            // but a still-open session would otherwise make it read-only.
            await session.close();
            if (!context.mounted) return;
            // The entry route remains mounted underneath the library page.
            // Replace it after returning so newly installed content and art
            // are read from the active local resource set instead of leaving
            // the player on a stale "not installed" screen.
            await Navigator.of(context).pushReplacementNamed('/street-scrap');
          },
        ),
      ),
    ),
  );
}
