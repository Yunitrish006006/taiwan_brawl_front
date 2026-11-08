import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:taiwan_brawl/game_modules/bundled_game_catalog.dart';
import 'package:taiwan_brawl/game_modules/game_module_home_entries.dart';
import 'package:taiwan_brawl/game_modules/game_module_routes.dart';
import 'package:taiwan_brawl/game_modules/game_module_registrations.dart';
import 'package:taiwan_brawl/services/api_client.dart';
import 'package:taiwan_brawl/services/auth_remote_source.dart';
import 'package:taiwan_brawl/services/auth_service.dart';
import 'package:taiwan_brawl/services/game_library_controller.dart';
import 'package:taiwan_brawl/services/game_library_store.dart';
import 'package:taiwan_brawl/game_modules/game_module_manifest.dart';
import 'package:taiwan_brawl_game_street_scrap/street_scrap_content.dart';
import 'package:taiwan_brawl_game_street_scrap/street_scrap_progress.dart'
    as progress;
import 'package:user_ui_settings/user_ui_settings.dart';

class _MemoryStore implements GameLibraryStore {
  _MemoryStore({Map<String, GameResourceInstallRecord> records = const {}})
    : records = Map.of(records);

  final Map<String, GameResourceInstallRecord> records;

  @override
  Future<Set<String>> readEnabledModuleIds() async => {};
  @override
  Future<Map<String, GameResourceInstallRecord>> readResourceRecords() async =>
      records;
  @override
  Future<void> writeEnabledModuleIds(Set<String> moduleIds) async {}
  @override
  Future<void> writeResourceRecord(GameResourceInstallRecord record) async {
    records['${record.moduleId}:${record.resourceId}'] = record;
  }

  @override
  Future<void> removeResourceRecord(String moduleId, String resourceId) async {
    records.remove('$moduleId:$resourceId');
  }
}

class _MemoryProgressStore implements progress.StreetScrapProgressStore {
  final Map<String, Map<String, Object?>> snapshots = {};
  final List<String> readKeys = [];

  @override
  Future<Map<String, Object?>?> read(String slotKey) async {
    readKeys.add(slotKey);
    return snapshots[slotKey];
  }

  @override
  Future<bool> compareAndSwap({
    required String slotKey,
    required int? expectedRevision,
    required Map<String, Object?> nextSnapshot,
  }) async {
    final currentRevision = snapshots[slotKey]?['revision'] as int?;
    if (currentRevision != expectedRevision) return false;
    snapshots[slotKey] = nextSnapshot;
    return true;
  }
}

class _LeaseTrackingProgressStore extends _MemoryProgressStore
    implements progress.StreetScrapWriterLeaseStore {
  final Set<String> leasedSlots = {};
  int successfulLeaseAcquisitions = 0;

  @override
  Future<progress.StreetScrapWriterLease?> acquireWriterLease(
    String slotKey,
  ) async {
    if (!leasedSlots.add(slotKey)) return null;
    successfulLeaseAcquisitions++;
    return _TestWriterLease(() => leasedSlots.remove(slotKey));
  }
}

class _TestWriterLease implements progress.StreetScrapWriterLease {
  _TestWriterLease(this._onRelease);

  final void Function() _onRelease;
  bool _released = false;

  @override
  Future<void> release() async {
    if (_released) return;
    _released = true;
    _onRelease();
  }
}

class _AuthRemoteSource extends ServerAuthRemoteSource {
  _AuthRemoteSource() : super(ApiClient());

  int userId = 42;

  @override
  Future<Map<String, dynamic>> verifyGoogleToken(String idToken) async => {
    'user': {
      'id': userId,
      'name': 'Test Player',
      'email': 'player@example.invalid',
    },
  };
}

void main() {
  test('Street Scrap registers as an independent optional-content peer', () {
    final manifest = bundledGameCatalog[streetScrapModuleId]!;
    final packageManifest = GameModuleManifest.fromPackageJson(
      Map<String, dynamic>.from(StreetScrapGameManifest().toJson()),
    );
    expect(manifest.toJson(), packageManifest.toJson());
    expect(
      manifest.supportedResourceSchemas,
      packageManifest.supportedResourceSchemas,
    );
    expect(
      GameModuleManifest.fromJson(
        Map<String, dynamic>.from(StreetScrapGameManifest().toJson()),
      ).supportedResourceSchemas,
      isEmpty,
      reason: 'remote catalog parsing cannot claim bundled decoders',
    );
    expect(manifest.packageVersion, streetScrapPackageVersion);
    expect(manifest.minimumShellVersion, streetScrapMinimumShellVersion);
    expect(manifest.dataSchemaVersion, streetScrapSaveSchemaVersion);
    expect(
      manifest.platforms.map((platform) => platform.name),
      streetScrapSupportedPlatforms,
    );
    for (final resource in manifest.resources) {
      expect(
        manifest.platforms,
        containsAll(resource.platforms),
        reason: '${resource.resourceId} must stay within its module platforms',
      );
    }
    expect(manifest.supportedResourceSchemas[streetScrapContentResourceId], 1);
    expect(
      manifest.supportedResourceSchemas[streetScrapFishingSceneArtResourceId],
      streetScrapFishingSceneArtSchemaVersion,
    );
    expect(manifest.resources, hasLength(11));
    final base = manifest.resources.firstWhere(
      (resource) => resource.resourceId == streetScrapContentResourceId,
    );
    final chapter5 = manifest.resources.firstWhere(
      (resource) => resource.resourceId == streetScrapChapter5ResourceId,
    );
    final art = manifest.resources.firstWhere(
      (resource) => resource.resourceId == streetScrapArtResourceId,
    );
    final threadSpoolArt = manifest.resources.firstWhere(
      (resource) => resource.resourceId == streetScrapThreadSpoolArtResourceId,
    );
    final materialAtlas = manifest.resources.firstWhere(
      (resource) => resource.resourceId == streetScrapMaterialAtlasResourceId,
    );
    final mineralPackArt = manifest.resources.firstWhere(
      (resource) => resource.resourceId == streetScrapMineralPackArtResourceId,
    );
    final woodChipBundleArt = manifest.resources.firstWhere(
      (resource) =>
          resource.resourceId == streetScrapWoodChipBundleArtResourceId,
    );
    final toolAtlas = manifest.resources.firstWhere(
      (resource) => resource.resourceId == streetScrapToolAtlasResourceId,
    );
    final materialPackArt = manifest.resources.firstWhere(
      (resource) => resource.resourceId == streetScrapMaterialPackArtResourceId,
    );
    final fishingSceneArt = manifest.resources.firstWhere(
      (resource) => resource.resourceId == streetScrapFishingSceneArtResourceId,
    );
    final protagonistArt = manifest.resources.firstWhere(
      (resource) => resource.resourceId == streetScrapProtagonistArtResourceId,
    );
    expect(base.required, isFalse);
    expect(chapter5.required, isFalse);
    expect(chapter5.dependencies, hasLength(1));
    expect(art.kind, GameResourceKind.presentation);
    expect(art.affectsGameplay, isFalse);
    expect(art.required, isFalse);
    expect(art.payloadSchemaVersion, streetScrapArtSchemaVersion);
    expect(art.sha256, streetScrapArtSha256);
    expect(art.downloadUrl, isNull);
    expect(threadSpoolArt.kind, GameResourceKind.presentation);
    expect(threadSpoolArt.affectsGameplay, isFalse);
    expect(threadSpoolArt.required, isFalse);
    expect(
      threadSpoolArt.payloadSchemaVersion,
      streetScrapThreadSpoolArtSchemaVersion,
    );
    expect(materialAtlas.kind, GameResourceKind.presentation);
    expect(materialAtlas.affectsGameplay, isFalse);
    expect(materialAtlas.required, isFalse);
    expect(toolAtlas.kind, GameResourceKind.presentation);
    expect(toolAtlas.affectsGameplay, isFalse);
    expect(toolAtlas.required, isFalse);
    expect(toolAtlas.payloadSchemaVersion, streetScrapToolAtlasSchemaVersion);
    expect(toolAtlas.sha256, streetScrapToolAtlasSha256);
    expect(materialPackArt.kind, GameResourceKind.presentation);
    expect(materialPackArt.affectsGameplay, isFalse);
    expect(materialPackArt.required, isFalse);
    expect(
      materialPackArt.payloadSchemaVersion,
      streetScrapMaterialPackArtSchemaVersion,
    );
    expect(materialPackArt.sha256, streetScrapMaterialPackArtSha256);
    expect(materialPackArt.downloadUrl, isNull);
    expect(fishingSceneArt.kind, GameResourceKind.presentation);
    expect(fishingSceneArt.affectsGameplay, isFalse);
    expect(fishingSceneArt.required, isFalse);
    expect(
      fishingSceneArt.payloadSchemaVersion,
      streetScrapFishingSceneArtSchemaVersion,
    );
    expect(fishingSceneArt.sha256, streetScrapFishingSceneArtSha256);
    expect(fishingSceneArt.downloadUrl, isNull);
    expect(protagonistArt.kind, GameResourceKind.presentation);
    expect(protagonistArt.affectsGameplay, isFalse);
    expect(protagonistArt.required, isFalse);
    expect(
      protagonistArt.payloadSchemaVersion,
      streetScrapProtagonistArtSchemaVersion,
    );
    expect(protagonistArt.sha256, streetScrapProtagonistArtSha256);
    expect(protagonistArt.downloadUrl, isNull);
    expect(
      materialAtlas.payloadSchemaVersion,
      streetScrapMaterialAtlasSchemaVersion,
    );
    expect(materialAtlas.sha256, streetScrapMaterialAtlasSha256);
    expect(mineralPackArt.kind, GameResourceKind.presentation);
    expect(mineralPackArt.affectsGameplay, isFalse);
    expect(mineralPackArt.required, isFalse);
    expect(
      mineralPackArt.payloadSchemaVersion,
      streetScrapMineralPackArtSchemaVersion,
    );
    expect(mineralPackArt.sha256, streetScrapMineralPackArtSha256);
    expect(mineralPackArt.downloadUrl, isNull);
    expect(woodChipBundleArt.kind, GameResourceKind.presentation);
    expect(woodChipBundleArt.affectsGameplay, isFalse);
    expect(woodChipBundleArt.required, isFalse);
    expect(
      woodChipBundleArt.payloadSchemaVersion,
      streetScrapWoodChipBundleArtSchemaVersion,
    );
    expect(woodChipBundleArt.sha256, streetScrapWoodChipBundleArtSha256);
    expect(woodChipBundleArt.downloadUrl, isNull);
    expect(threadSpoolArt.sha256, streetScrapThreadSpoolArtSha256);
    expect(threadSpoolArt.downloadUrl, isNull);
    expect(manifest.supportedResourceSchemas[streetScrapChapter5ResourceId], 1);
    expect(
      base.downloadUrl,
      isNull,
      reason: 'A publisher has not yet published a signed download URL.',
    );
    expect(
      gameModuleRegistrations.map((entry) => entry.moduleId),
      contains(streetScrapModuleId),
    );
    expect(gameModuleRoutes, contains('/street-scrap'));
    expect(
      gameModuleHomeEntries.map((entry) => entry.moduleId),
      contains(streetScrapModuleId),
    );
  });

  testWidgets(
    'enabled route explains missing optional resource and opens Library',
    (tester) async {
      final authRemote = _AuthRemoteSource();
      final auth = AuthService(remoteSource: authRemote);
      await auth.verifyGoogleToken('test-token');
      addTearDown(auth.dispose);
      final progressStore = _LeaseTrackingProgressStore();
      final library = GameLibraryController(
        catalog: GameModuleCatalog([
          GameModuleManifest(
            moduleId: streetScrapModuleId,
            displayName: '街角拾荒',
            description: 'Fixture',
            packageVersion: streetScrapPackageVersion,
            minimumShellVersion: streetScrapMinimumShellVersion,
            dataSchemaVersion: streetScrapSaveSchemaVersion,
            supportedResourceSchemas: {streetScrapContentResourceId: 1},
            resources: [
              GameResourceManifest(
                resourceId: streetScrapContentResourceId,
                version: streetScrapContentResourceVersion,
                kind: GameResourceKind.gameplayData,
                sha256: streetScrapContentSha256,
                affectsGameplay: true,
                payloadSchemaVersion: streetScrapContentSchemaVersion,
              ),
            ],
          ),
        ]),
        store: _MemoryStore(),
      );
      await library.initialize();
      await library.setModuleEnabled(streetScrapModuleId, true);
      final locale = LocaleProvider(
        defaultLocale: 'en',
        translationResolver: (_) => const {},
      );
      addTearDown(locale.dispose);

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<GameLibraryController>.value(value: library),
            ChangeNotifierProvider<AuthService>.value(value: auth),
            Provider<progress.StreetScrapProgressStore>.value(
              value: progressStore,
            ),
            ChangeNotifierProvider<LocaleProvider>.value(value: locale),
          ],
          child: MaterialApp(
            initialRoute: '/street-scrap',
            routes: {
              ...gameModuleRoutes,
              '/game-library': (_) =>
                  const Scaffold(body: Text('Library destination')),
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Local save loaded'), findsOneWidget);
      expect(
        find.textContaining('Neighborhood content is not installed'),
        findsOneWidget,
      );
      expect(progressStore.readKeys, hasLength(1));
      locale.setLocale('zh-Hant');
      await tester.pumpAndSettle();
      expect(find.text('本機存檔已載入'), findsOneWidget);
      expect(find.textContaining('街區內容尚未安裝'), findsOneWidget);
      authRemote.userId = 43;
      await auth.verifyGoogleToken('switch-profile');
      await tester.pumpAndSettle();
      expect(progressStore.readKeys, hasLength(2));
      expect(progressStore.readKeys.first, isNot(progressStore.readKeys.last));
      await tester.tap(find.text('前往遊戲庫'));
      await tester.pumpAndSettle();
      expect(find.text('Library destination'), findsOneWidget);
      await library.recordResourceState(
        GameResourceInstallRecord(
          moduleId: streetScrapModuleId,
          resourceId: streetScrapContentResourceId,
          version: streetScrapContentResourceVersion,
          sha256: streetScrapContentSha256,
          payloadSchemaVersion: streetScrapContentSchemaVersion,
          status: GameResourceInstallStatus.installed,
        ),
      );
      Navigator.of(tester.element(find.text('Library destination'))).pop();
      await tester.pumpAndSettle();
      expect(
        find.textContaining('已安裝的街區內容無法讀取'),
        findsOneWidget,
        reason: 'Returning from the library must rebuild the installed route.',
      );
      expect(progressStore.successfulLeaseAcquisitions, 3);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'formal game route is read-only in a second tab and writable after reopen',
    (tester) async {
      final auth = AuthService(remoteSource: _AuthRemoteSource());
      await auth.verifyGoogleToken('test-token');
      addTearDown(auth.dispose);
      final progressStore = _MemoryProgressStore();
      final library = GameLibraryController(
        catalog: bundledGameCatalog,
        store: _MemoryStore(),
      );
      await library.initialize();
      await library.setModuleEnabled(streetScrapModuleId, true);
      final locale = LocaleProvider(
        defaultLocale: 'en',
        translationResolver: (_) => const {},
      );
      addTearDown(locale.dispose);

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<GameLibraryController>.value(value: library),
            ChangeNotifierProvider<AuthService>.value(value: auth),
            Provider<progress.StreetScrapProgressStore>.value(
              value: progressStore,
            ),
            ChangeNotifierProvider<LocaleProvider>.value(value: locale),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => TextButton(
                  onPressed: () =>
                      Navigator.of(context).pushNamed('/street-scrap'),
                  child: const Text('Open Street Scrap'),
                ),
              ),
            ),
            routes: gameModuleRoutes,
          ),
        ),
      );

      await tester.tap(find.text('Open Street Scrap'));
      await tester.pumpAndSettle();
      expect(find.text('Local save loaded'), findsOneWidget);
      expect(
        find.text('This save is open in another tab and is read-only.'),
        findsNothing,
      );

      final firstPageContext = tester.element(find.text('Local save loaded'));
      Navigator.of(firstPageContext).pushNamed('/street-scrap');
      await tester.pumpAndSettle();
      expect(
        find.text('Local save loaded', skipOffstage: false),
        findsNWidgets(2),
      );
      expect(
        find.text('This save is open in another tab and is read-only.'),
        findsOneWidget,
      );

      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(
        find.text('This save is open in another tab and is read-only.'),
        findsNothing,
      );
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.text('Open Street Scrap'), findsOneWidget);

      await tester.tap(find.text('Open Street Scrap'));
      await tester.pumpAndSettle();
      expect(find.text('Local save loaded'), findsOneWidget);
      expect(
        find.text('This save is open in another tab and is read-only.'),
        findsNothing,
      );
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets('installed metadata with unavailable local bytes fails closed', (
    tester,
  ) async {
    final authRemote = _AuthRemoteSource()..userId = 77;
    final auth = AuthService(remoteSource: authRemote);
    await auth.verifyGoogleToken('test-token');
    addTearDown(auth.dispose);
    final progressStore = _MemoryProgressStore();
    final installed = GameResourceInstallRecord(
      moduleId: streetScrapModuleId,
      resourceId: streetScrapContentResourceId,
      version: '0.1.0',
      sha256: streetScrapContentSha256,
      payloadSchemaVersion: streetScrapContentSchemaVersion,
      status: GameResourceInstallStatus.installed,
    );
    final library = GameLibraryController(
      catalog: bundledGameCatalog,
      store: _MemoryStore(
        records: {
          '$streetScrapModuleId:$streetScrapContentResourceId': installed,
        },
      ),
    );
    await library.initialize();
    await library.setModuleEnabled(streetScrapModuleId, true);
    library.mergeRemoteManifests([
      GameModuleManifest(
        moduleId: streetScrapModuleId,
        displayName: '街角拾荒',
        description: 'Fixture',
        packageVersion: streetScrapPackageVersion,
        minimumShellVersion: streetScrapMinimumShellVersion,
        dataSchemaVersion: streetScrapSaveSchemaVersion,
        supportedResourceSchemas: {streetScrapContentResourceId: 1},
        resources: [
          GameResourceManifest(
            resourceId: streetScrapContentResourceId,
            version: '0.2.0',
            kind: GameResourceKind.gameplayData,
            sha256: 'a' * 64,
            affectsGameplay: true,
            payloadSchemaVersion: 1,
            required: false,
          ),
        ],
      ),
    ]);
    final locale = LocaleProvider(
      defaultLocale: 'en',
      translationResolver: (_) => const {},
    );
    addTearDown(locale.dispose);
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<GameLibraryController>.value(value: library),
          ChangeNotifierProvider<AuthService>.value(value: auth),
          Provider<progress.StreetScrapProgressStore>.value(
            value: progressStore,
          ),
          ChangeNotifierProvider<LocaleProvider>.value(value: locale),
        ],
        child: MaterialApp(
          initialRoute: '/street-scrap',
          routes: gameModuleRoutes,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      find.textContaining('Installed neighborhood content could not be read'),
      findsOneWidget,
    );
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
