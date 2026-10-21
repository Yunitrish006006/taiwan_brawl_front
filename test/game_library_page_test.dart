import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:taiwan_brawl/game_modules/bundled_game_catalog.dart';
import 'package:taiwan_brawl/game_modules/game_module_manifest.dart';
import 'package:taiwan_brawl/pages/game/game_library_page.dart';
import 'package:taiwan_brawl/services/api_client.dart';
import 'package:taiwan_brawl/services/game_library_controller.dart';
import 'package:taiwan_brawl/services/game_library_store.dart';
import 'package:taiwan_brawl/services/game_resource_catalog_source.dart';
import 'package:taiwan_brawl/services/game_resource_content_store.dart';
import 'package:taiwan_brawl/services/game_resource_installer.dart';
import 'package:taiwan_brawl/services/game_resource_library_service.dart';
import 'package:taiwan_brawl_game_mini_royale/taiwan_brawl_game_mini_royale.dart';
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
