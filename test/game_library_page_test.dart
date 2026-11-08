import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:taiwan_brawl/game_modules/bundled_game_catalog.dart';
import 'package:taiwan_brawl/game_modules/game_module_manifest.dart';
import 'package:taiwan_brawl/constants/locale_catalog.dart';
import 'package:taiwan_brawl/pages/game/game_library_page.dart';
import 'package:taiwan_brawl/services/api_client.dart';
import 'package:taiwan_brawl/services/game_library_controller.dart';
import 'package:taiwan_brawl/services/game_library_store.dart';
import 'package:taiwan_brawl/services/game_resource_catalog_source.dart';
import 'package:taiwan_brawl/services/game_resource_content_store.dart';
import 'package:taiwan_brawl/services/game_resource_installer.dart';
import 'package:taiwan_brawl/services/game_resource_library_service.dart';
import 'package:taiwan_brawl_game_mini_royale/taiwan_brawl_game_mini_royale.dart';
import 'package:taiwan_brawl_game_street_scrap/street_scrap_content.dart';
import 'package:user_ui_settings/user_ui_settings.dart';

class _MemoryGameLibraryStore implements GameLibraryStore {
  Set<String> enabled = {};
  final Map<String, GameResourceInstallRecord> records = {};

  @override
  Future<Set<String>> readEnabledModuleIds() async => Set.of(enabled);

  @override
  Future<void> writeEnabledModuleIds(Set<String> moduleIds) async {
    enabled = Set.of(moduleIds);
  }

  @override
  Future<Map<String, GameResourceInstallRecord>> readResourceRecords() async =>
      Map.of(records);

  @override
  Future<void> writeResourceRecord(GameResourceInstallRecord record) async {
    records['${record.moduleId}:${record.resourceId}'] = record;
  }

  @override
  Future<void> removeResourceRecord(String moduleId, String resourceId) async {
    records.remove('$moduleId:$resourceId');
  }
}

void main() {
  testWidgets('unpublished optional packs explain why download is unavailable', (
    tester,
  ) async {
    final library = GameLibraryController(
      catalog: bundledGameCatalog,
      store: _MemoryGameLibraryStore(),
    );
    await library.initialize();
    final service = GameResourceLibraryService(
      controller: library,
      catalogSource: GameResourceCatalogSource(ApiClient()),
      contentStore: _UnusedContentStore(),
      installer: GameResourceInstaller(
        controller: library,
        contentStore: _UnusedContentStore(),
        signatureVerifier: _AcceptSignatureVerifier(),
      ),
    );
    final locale = LocaleProvider(
      defaultLocale: 'en',
      translationResolver: translationForLocale,
    );
    final cacheService = BattleAnimationCacheService(
      store: _MemoryAnimationCacheStore(),
      remoteSource: _EmptyAnimationRemoteSource(),
    );
    addTearDown(locale.dispose);
    addTearDown(cacheService.dispose);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<GameLibraryController>.value(value: library),
          Provider<GameResourceLibraryService?>.value(value: service),
          ChangeNotifierProvider<LocaleProvider>.value(value: locale),
          ChangeNotifierProvider<BattleAnimationCacheService>.value(
            value: cacheService,
          ),
        ],
        child: const MaterialApp(home: GameLibraryPage()),
      ),
    );

    expect(library.catalog['game.street-scrap']!.resources, hasLength(11));
    final resourceFinder = find.text('Street Scrap: Chapters 0–4');
    await tester.scrollUntilVisible(resourceFinder, 250);
    expect(resourceFinder, findsOneWidget);
    expect(find.text(streetScrapContentResourceId), findsNothing);
    final resourceTile = find.ancestor(
      of: resourceFinder,
      matching: find.byType(ListTile),
    );
    final installAction = tester.widget<IconButton>(
      find.descendant(of: resourceTile, matching: find.byType(IconButton)),
    );
    expect(installAction.onPressed, isNull);
    expect(
      installAction.tooltip,
      'Download unavailable: signed package not published',
    );
    expect(
      find.textContaining(
        'Not available to download yet; the publisher has not released this signed pack.',
      ),
      findsWidgets,
    );
    expect(find.textContaining('Package size: Not specified'), findsWidgets);
    locale.setLocale('zh-Hant');
    expect(locale.translation['Package size'], '套件大小');
    await tester.pump();
    expect(find.textContaining('套件大小: 尚未提供'), findsWidgets);
  });

  testWidgets('resource failures show safe retry guidance, not exception text', (
    tester,
  ) async {
    const moduleId = 'game.street-scrap';
    const resourceId = streetScrapContentResourceId;
    final baseModule = bundledGameCatalog[moduleId]!;
    final baseResource = baseModule.resources.firstWhere(
      (resource) => resource.resourceId == resourceId,
    );
    final resource = GameResourceManifest(
      resourceId: resourceId,
      version: baseResource.version,
      kind: baseResource.kind,
      sha256: List.filled(64, 'a').join(),
      affectsGameplay: baseResource.affectsGameplay,
      payloadSchemaVersion: baseResource.payloadSchemaVersion,
      downloadUrl: 'https://assets.example.test/street-scrap/content.json',
      byteLength: 128,
      signature: 'test-signature',
      signingKeyId: 'test-key',
      dependencies: baseResource.dependencies,
      platforms: baseResource.platforms,
      displayNameKey: baseResource.displayNameKey,
      descriptionKey: baseResource.descriptionKey,
    );
    final remoteModule = GameModuleManifest(
      moduleId: baseModule.moduleId,
      displayName: baseModule.displayName,
      description: baseModule.description,
      packageVersion: baseModule.packageVersion,
      minimumShellVersion: baseModule.minimumShellVersion,
      hostApiRange: baseModule.hostApiRange,
      dataSchemaVersion: baseModule.dataSchemaVersion,
      dependencies: baseModule.dependencies,
      multiplayer: baseModule.multiplayer,
      supportedResourceSchemas: baseModule.supportedResourceSchemas,
      resources: [resource],
      platforms: baseModule.platforms,
    );
    final library = GameLibraryController(
      catalog: bundledGameCatalog,
      store: _MemoryGameLibraryStore(),
      clock: () => DateTime.utc(2026, 10, 24),
    );
    await library.initialize();
    library.replaceRemoteManifests(
      [remoteModule],
      issuedAt: DateTime.utc(2026, 10, 24),
      expiresAt: DateTime.utc(2026, 10, 25),
    );
    final contentStore = _MemoryGameResourceContentStore();
    final service = GameResourceLibraryService(
      controller: library,
      catalogSource: GameResourceCatalogSource(ApiClient()),
      contentStore: contentStore,
      resourceMigrations: {'$moduleId:$resourceId': (_) async {}},
      installer: GameResourceInstaller(
        controller: library,
        contentStore: contentStore,
        signatureVerifier: _AcceptSignatureVerifier(),
        client: _FailingClient(),
      ),
    );
    final locale = LocaleProvider(
      defaultLocale: 'en',
      translationResolver: translationForLocale,
    );
    final cacheService = BattleAnimationCacheService(
      store: _MemoryAnimationCacheStore(),
      remoteSource: _EmptyAnimationRemoteSource(),
    );
    addTearDown(locale.dispose);
    addTearDown(cacheService.dispose);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<GameLibraryController>.value(value: library),
          Provider<GameResourceLibraryService?>.value(value: service),
          ChangeNotifierProvider<LocaleProvider>.value(value: locale),
          ChangeNotifierProvider<BattleAnimationCacheService>.value(
            value: cacheService,
          ),
        ],
        child: const MaterialApp(home: GameLibraryPage()),
      ),
    );

    final resourceTitle = find.text('Street Scrap: Chapters 0–4');
    await tester.scrollUntilVisible(resourceTitle, 250);
    final resourceTile = find.ancestor(
      of: resourceTitle,
      matching: find.byType(ListTile),
    );
    await tester.tap(
      find.descendant(of: resourceTile, matching: find.byIcon(Icons.download)),
    );
    await tester.pumpAndSettle();

    expect(
      find.text(
        'Resource action failed. Reload the app, refresh the game catalog, then try again.',
      ),
      findsOneWidget,
    );
    expect(find.textContaining('private-test-detail'), findsNothing);
    expect(
      library.resourceRecord(moduleId, resourceId)?.status,
      GameResourceInstallStatus.failed,
    );
    library.dispose();
  });

  testWidgets(
    'Street Scrap pack installs from the library and survives controller reload',
    (tester) async {
      const moduleId = 'game.street-scrap';
      const resourceId = streetScrapContentResourceId;
      final payload = Uint8List.fromList(List<int>.filled(1536, 42));
      final digest = sha256.convert(payload).toString();
      final baseModule = bundledGameCatalog[moduleId]!;
      final baseResource = baseModule.resources.firstWhere(
        (resource) => resource.resourceId == resourceId,
      );
      final resource = GameResourceManifest(
        resourceId: resourceId,
        version: baseResource.version,
        kind: baseResource.kind,
        sha256: digest,
        affectsGameplay: baseResource.affectsGameplay,
        payloadSchemaVersion: baseResource.payloadSchemaVersion,
        downloadUrl:
            'https://taiwan-brawl-api.yunitrish0419.workers.dev'
            '/game-resources/street-scrap/$resourceId/${baseResource.version}',
        byteLength: payload.length,
        signature: 'test-signature',
        signingKeyId: 'test-key',
        dependencies: baseResource.dependencies,
        platforms: baseResource.platforms,
        displayNameKey: baseResource.displayNameKey,
        descriptionKey: baseResource.descriptionKey,
      );
      final remoteModule = GameModuleManifest(
        moduleId: baseModule.moduleId,
        displayName: baseModule.displayName,
        description: baseModule.description,
        packageVersion: baseModule.packageVersion,
        minimumShellVersion: baseModule.minimumShellVersion,
        hostApiRange: baseModule.hostApiRange,
        dataSchemaVersion: baseModule.dataSchemaVersion,
        dependencies: baseModule.dependencies,
        multiplayer: baseModule.multiplayer,
        supportedResourceSchemas: baseModule.supportedResourceSchemas,
        resources: [resource],
        platforms: baseModule.platforms,
      );
      final libraryStore = _MemoryGameLibraryStore();
      final library = GameLibraryController(
        catalog: bundledGameCatalog,
        store: libraryStore,
        clock: () => DateTime.utc(2026, 10, 24),
      );
      await library.initialize();
      library.replaceRemoteManifests(
        [remoteModule],
        issuedAt: DateTime.utc(2026, 10, 24),
        expiresAt: DateTime.utc(2026, 10, 25),
      );
      final contentStore = _MemoryGameResourceContentStore();
      final service = GameResourceLibraryService(
        controller: library,
        catalogSource: GameResourceCatalogSource(ApiClient()),
        contentStore: contentStore,
        resourceMigrations: {'$moduleId:$resourceId': (_) async {}},
        installer: GameResourceInstaller(
          controller: library,
          contentStore: contentStore,
          signatureVerifier: _AcceptSignatureVerifier(),
          client: _PayloadClient(payload),
        ),
      );
      final locale = LocaleProvider(
        defaultLocale: 'en',
        translationResolver: translationForLocale,
      );
      final cacheService = BattleAnimationCacheService(
        store: _MemoryAnimationCacheStore(),
        remoteSource: _EmptyAnimationRemoteSource(),
      );
      addTearDown(locale.dispose);
      addTearDown(cacheService.dispose);

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<GameLibraryController>.value(value: library),
            Provider<GameResourceLibraryService?>.value(value: service),
            ChangeNotifierProvider<LocaleProvider>.value(value: locale),
            ChangeNotifierProvider<BattleAnimationCacheService>.value(
              value: cacheService,
            ),
          ],
          child: const MaterialApp(home: GameLibraryPage()),
        ),
      );
      final resourceTitle = find.text('Street Scrap: Chapters 0–4');
      await tester.scrollUntilVisible(resourceTitle, 250);
      expect(find.textContaining('Package size: 1.5 KB'), findsOneWidget);
      final resourceTile = find.ancestor(
        of: resourceTitle,
        matching: find.byType(ListTile),
      );
      await tester.tap(
        find.descendant(
          of: resourceTile,
          matching: find.byIcon(Icons.download),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        library.resourceRecord(moduleId, resourceId)?.status,
        GameResourceInstallStatus.installed,
      );
      expect(
        await contentStore.readActive(moduleId, resourceId),
        orderedEquals(payload),
      );

      final reloadedLibrary = GameLibraryController(
        catalog: bundledGameCatalog,
        store: libraryStore,
        clock: () => DateTime.utc(2026, 10, 24),
      );
      await reloadedLibrary.initialize();
      expect(
        reloadedLibrary.resourceRecord(moduleId, resourceId)?.status,
        GameResourceInstallStatus.installed,
      );
      expect(
        await contentStore.readActive(moduleId, resourceId),
        orderedEquals(payload),
      );
      library.dispose();
      reloadedLibrary.dispose();
    },
  );

  testWidgets('player can select a game from the shell library', (
    tester,
  ) async {
    final library = GameLibraryController(
      catalog: bundledGameCatalog,
      store: _MemoryGameLibraryStore(),
    );
    await library.initialize();
    final locale = LocaleProvider(
      defaultLocale: 'en',
      translationResolver: (_) => const {},
    );
    final cacheService = BattleAnimationCacheService(
      store: _MemoryAnimationCacheStore(),
      remoteSource: _EmptyAnimationRemoteSource(),
    );
    addTearDown(locale.dispose);
    addTearDown(cacheService.dispose);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<GameLibraryController>.value(value: library),
          ChangeNotifierProvider<LocaleProvider>.value(value: locale),
          ChangeNotifierProvider<BattleAnimationCacheService>.value(
            value: cacheService,
          ),
        ],
        child: const MaterialApp(home: GameLibraryPage()),
      ),
    );

    expect(find.text('Archery Game'), findsOneWidget);
    final archerySwitch = tester.widget<SwitchListTile>(
      find.ancestor(
        of: find.text('Archery Game'),
        matching: find.byType(SwitchListTile),
      ),
    );
    expect(archerySwitch.value, isFalse);

    await tester.tap(find.text('Archery Game'));
    await tester.pumpAndSettle();
    expect(library.isModuleEnabled('game.archery'), isTrue);

    expect(find.text('Preload and keep battle animations'), findsOneWidget);
    final cacheSwitch = tester.widget<SwitchListTile>(
      find.byType(SwitchListTile).last,
    );
    expect(cacheSwitch.value, isFalse);
    await tester.tap(find.text('Preload and keep battle animations'));
    await tester.pumpAndSettle();
    expect(cacheService.enabled, isTrue);
  });

  testWidgets('disabled games can still manage their optional resource packs', (
    tester,
  ) async {
    final now = DateTime.utc(2026, 10, 21, 12);
    const installedId = 'game.archery.rules';
    const downloadableId = 'game.archery.arena';
    final installedResource = GameResourceManifest(
      resourceId: installedId,
      version: '1.0.0',
      kind: GameResourceKind.gameplayData,
      sha256:
          'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
      affectsGameplay: true,
      payloadSchemaVersion: 1,
      downloadUrl: 'https://assets.example.test/archery/rules.json',
      byteLength: 16,
      signature: 'signed-rules',
      signingKeyId: 'test-key',
    );
    final downloadableResource = GameResourceManifest(
      resourceId: downloadableId,
      version: '1.0.0',
      kind: GameResourceKind.presentation,
      sha256:
          'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb',
      affectsGameplay: false,
      payloadSchemaVersion: 1,
      downloadUrl: 'https://assets.example.test/archery/arena.json',
      byteLength: 16,
      signature: 'signed-arena',
      signingKeyId: 'test-key',
    );
    final store = _MemoryGameLibraryStore()
      ..records['game.archery:$installedId'] = const GameResourceInstallRecord(
        moduleId: 'game.archery',
        resourceId: installedId,
        version: '1.0.0',
        sha256:
            'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
        status: GameResourceInstallStatus.installed,
      );
    final module = GameModuleManifest(
      moduleId: 'game.archery',
      displayName: 'Archery Game',
      description: 'A single-player archery challenge.',
      packageVersion: '0.1.0',
      minimumShellVersion: '0.132.0',
      dataSchemaVersion: 1,
      supportedResourceSchemas: {installedId: 1, downloadableId: 1},
      resources: [installedResource, downloadableResource],
    );
    final library = GameLibraryController(
      catalog: GameModuleCatalog([module]),
      store: store,
      clock: () => now,
    );
    await library.initialize();
    library.replaceRemoteManifests([
      module,
    ], expiresAt: now.add(const Duration(minutes: 1)));
    final contentStore = _UnusedContentStore();
    final service = GameResourceLibraryService(
      controller: library,
      catalogSource: GameResourceCatalogSource(ApiClient()),
      contentStore: contentStore,
      installer: GameResourceInstaller(
        controller: library,
        contentStore: contentStore,
        signatureVerifier: _AcceptSignatureVerifier(),
      ),
    );
    final locale = LocaleProvider(
      defaultLocale: 'en',
      translationResolver: (_) => const {},
    );
    addTearDown(locale.dispose);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<GameLibraryController>.value(value: library),
          Provider<GameResourceLibraryService?>.value(value: service),
          ChangeNotifierProvider<LocaleProvider>.value(value: locale),
        ],
        child: const MaterialApp(home: GameLibraryPage()),
      ),
    );

    final moduleSwitch = tester.widget<SwitchListTile>(
      find.ancestor(
        of: find.text('Archery Game'),
        matching: find.byType(SwitchListTile),
      ),
    );
    expect(moduleSwitch.value, isFalse);
    expect(find.text(installedId), findsOneWidget);
    expect(find.text(downloadableId), findsOneWidget);

    final removeInstalled = tester.widget<IconButton>(
      find
          .ancestor(
            of: find.byTooltip('Remove download'),
            matching: find.byType(IconButton),
          )
          .first,
    );
    final downloadOptional = tester.widget<IconButton>(
      find
          .ancestor(
            of: find.byTooltip('Download resource'),
            matching: find.byType(IconButton),
          )
          .first,
    );
    expect(removeInstalled.onPressed, isNotNull);
    expect(downloadOptional.onPressed, isNotNull);
    expect(library.isModuleEnabled('game.archery'), isFalse);
    library.dispose();
  });

  testWidgets('an installed old resource offers update and remove actions', (
    tester,
  ) async {
    var now = DateTime.utc(2026, 10, 21, 12);
    const resourceId = 'game.archery.rules';
    final resource = GameResourceManifest(
      resourceId: resourceId,
      version: '2.0.0',
      kind: GameResourceKind.gameplayData,
      sha256:
          'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb',
      affectsGameplay: true,
      payloadSchemaVersion: 1,
      downloadUrl: 'https://assets.example.test/archery/rules-2.json',
      byteLength: 32,
      signature: 'test-signature',
      signingKeyId: 'test-key',
    );
    final store = _MemoryGameLibraryStore()
      ..records['game.archery:$resourceId'] = const GameResourceInstallRecord(
        moduleId: 'game.archery',
        resourceId: resourceId,
        version: '1.0.0',
        sha256:
            'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
        status: GameResourceInstallStatus.installed,
      );
    final library = GameLibraryController(
      catalog: GameModuleCatalog([
        GameModuleManifest(
          moduleId: 'game.archery',
          displayName: 'Archery Game',
          description: 'A single-player archery challenge.',
          packageVersion: '0.1.0',
          minimumShellVersion: '0.132.0',
          dataSchemaVersion: 1,
          supportedResourceSchemas: {resourceId: 1},
          resources: [resource],
        ),
      ]),
      store: store,
      clock: () => now,
    );
    await library.initialize();
    final catalogExpiry = now.add(const Duration(minutes: 1));
    library.replaceRemoteManifests(
      library.catalog.manifests,
      expiresAt: catalogExpiry,
    );
    final contentStore = _UnusedContentStore();
    final service = GameResourceLibraryService(
      controller: library,
      catalogSource: GameResourceCatalogSource(ApiClient()),
      contentStore: contentStore,
      installer: GameResourceInstaller(
        controller: library,
        contentStore: contentStore,
        signatureVerifier: _AcceptSignatureVerifier(),
      ),
    );
    final locale = LocaleProvider(
      defaultLocale: 'en',
      translationResolver: (_) => const {},
    );
    addTearDown(locale.dispose);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<GameLibraryController>.value(value: library),
          Provider<GameResourceLibraryService?>.value(value: service),
          ChangeNotifierProvider<LocaleProvider>.value(value: locale),
        ],
        child: const MaterialApp(home: GameLibraryPage()),
      ),
    );

    expect(find.textContaining('Update available'), findsOneWidget);
    expect(find.textContaining('catalog has expired'), findsNothing);
    final update = tester.widget<IconButton>(
      find.ancestor(
        of: find.byIcon(Icons.system_update_alt),
        matching: find.byType(IconButton),
      ),
    );
    final remove = tester.widget<IconButton>(
      find.ancestor(
        of: find.byIcon(Icons.delete_outline),
        matching: find.byType(IconButton),
      ),
    );
    expect(update.onPressed, isNotNull);
    expect(remove.onPressed, isNotNull);

    now = catalogExpiry;
    await tester.pump(const Duration(minutes: 1));
    expect(find.textContaining('catalog has expired'), findsOneWidget);
    final expiredUpdate = tester.widget<IconButton>(
      find.ancestor(
        of: find.byIcon(Icons.system_update_alt),
        matching: find.byType(IconButton),
      ),
    );
    expect(expiredUpdate.onPressed, isNull);

    library.mergeRemoteManifests([
      GameModuleManifest(
        moduleId: 'game.archery',
        displayName: 'Archery Game',
        description: 'A single-player archery challenge.',
        packageVersion: '0.1.0',
        minimumShellVersion: '0.132.0',
        dataSchemaVersion: 1,
        resources: const [],
      ),
    ]);
    await tester.pumpAndSettle();

    expect(find.textContaining('Update available'), findsNothing);
    expect(find.text('game.archery.rules'), findsOneWidget);
    final withdrawnRemove = tester.widget<IconButton>(
      find.ancestor(
        of: find.byIcon(Icons.delete_outline),
        matching: find.byType(IconButton),
      ),
    );
    expect(withdrawnRemove.onPressed, isNotNull);
    expect(find.byIcon(Icons.system_update_alt), findsNothing);
  });
}

class _UnusedContentStore implements GameResourceContentStore {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _MemoryGameResourceContentStore implements GameResourceContentStore {
  final Map<String, Uint8List> _staged = {};
  final Map<String, Uint8List> _active = {};
  final Map<String, Map<String, String>> _activeSets = {};

  String _key(String moduleId, String resourceId, String version) =>
      '$moduleId:$resourceId:$version';

  @override
  Future<void> writeStaged(
    String moduleId,
    String resourceId,
    String version,
    Uint8List bytes,
  ) async {
    _staged[_key(moduleId, resourceId, version)] = Uint8List.fromList(bytes);
  }

  @override
  Future<List<Uint8List>> readStagedChunks(
    String moduleId,
    String resourceId,
    String version,
  ) async => const [];

  @override
  Future<void> writeStagedChunk(
    String moduleId,
    String resourceId,
    String version,
    int index,
    Uint8List bytes,
  ) async {}

  @override
  Future<void> activate(
    String moduleId,
    String resourceId,
    String version,
  ) async => activateSet(moduleId, {
    ...await readActiveSet(moduleId),
    resourceId: version,
  });

  @override
  Future<void> activateSet(
    String moduleId,
    Map<String, String> versions,
  ) async {
    for (final entry in versions.entries) {
      final key = _key(moduleId, entry.key, entry.value);
      final bytes = _staged.remove(key) ?? _active[key];
      if (bytes == null) throw StateError('Missing staged test resource $key.');
      _active[key] = Uint8List.fromList(bytes);
    }
    _activeSets[moduleId] = Map.of(versions);
  }

  @override
  Future<Uint8List?> readActive(String moduleId, String resourceId) async {
    final version = (await readActiveSet(moduleId))[resourceId];
    final bytes = version == null
        ? null
        : _active[_key(moduleId, resourceId, version)];
    return bytes == null ? null : Uint8List.fromList(bytes);
  }

  @override
  Future<String?> readActiveVersion(String moduleId, String resourceId) async =>
      (await readActiveSet(moduleId))[resourceId];

  @override
  Future<Map<String, String>> readActiveSet(String moduleId) async =>
      Map.of(_activeSets[moduleId] ?? const {});

  @override
  Future<void> restoreActiveVersion(
    String moduleId,
    String resourceId,
    String? version,
  ) async {
    final next = await readActiveSet(moduleId);
    if (version == null) {
      next.remove(resourceId);
    } else {
      next[resourceId] = version;
    }
    await restoreActiveSet(moduleId, next);
  }

  @override
  Future<void> restoreActiveSet(
    String moduleId,
    Map<String, String> versions,
  ) async {
    _activeSets[moduleId] = Map.of(versions);
  }

  @override
  Future<void> discardStaged(
    String moduleId,
    String resourceId,
    String version,
  ) async {
    _staged.remove(_key(moduleId, resourceId, version));
  }

  @override
  Future<void> remove(String moduleId, String resourceId) async =>
      removeSet(moduleId, [resourceId]);

  @override
  Future<void> removeSet(String moduleId, List<String> resourceIds) async {
    final versions = await readActiveSet(moduleId);
    for (final resourceId in resourceIds) {
      versions.remove(resourceId);
    }
    _activeSets[moduleId] = versions;
  }
}

class _PayloadClient extends http.BaseClient {
  _PayloadClient(this.payload);

  final Uint8List payload;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async =>
      http.StreamedResponse(
        Stream<List<int>>.value(payload),
        200,
        request: request,
        headers: {'content-length': '${payload.length}'},
      );
}

class _FailingClient extends http.BaseClient {
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    throw StateError('private-test-detail: signing-key contents');
  }
}

class _AcceptSignatureVerifier implements GameResourceSignatureVerifier {
  @override
  Future<bool> verify({
    required String keyId,
    required String signature,
    required String moduleId,
    required String resourceId,
    required String version,
    required String sha256,
    required Uint8List payload,
  }) async => true;
}

class _MemoryAnimationCacheStore implements BattleAnimationCacheStore {
  bool enabled = false;
  @override
  Future<void> initialize() async {}
  @override
  Future<bool> readEnabled() async => enabled;
  @override
  Future<void> writeEnabled(bool value) async => enabled = value;
  @override
  bool containsBytes(String cacheKey) => false;
  @override
  String? readBytes(String cacheKey) => null;
  @override
  Future<void> writeBytes(String cacheKey, String encodedBytes) async {}
  @override
  Future<void> deleteBytes(String cacheKey) async {}
  @override
  String? readMeta(String identity) => null;
  @override
  Future<void> writeMeta(String identity, String encodedMeta) async {}
  @override
  Future<void> deleteMeta(String identity) async {}
}

class _EmptyAnimationRemoteSource implements BattleAnimationRemoteSource {
  @override
  Future<Uint8List?> download(Uri uri) async => null;
  @override
  void dispose() {}
}
