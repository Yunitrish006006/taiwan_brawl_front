import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:taiwan_brawl/game_modules/game_module_manifest.dart';
import 'package:taiwan_brawl/game_modules/game_module_routes.dart';
import 'package:taiwan_brawl/services/game_library_controller.dart';
import 'package:taiwan_brawl/services/game_library_store.dart';
import 'package:user_ui_settings/user_ui_settings.dart';

class _MemoryStore implements GameLibraryStore {
  @override
  Future<Set<String>> readEnabledModuleIds() async => {};
  @override
  Future<Map<String, GameResourceInstallRecord>> readResourceRecords() async =>
      {};
  @override
  Future<void> writeEnabledModuleIds(Set<String> moduleIds) async {}
  @override
  Future<void> writeResourceRecord(GameResourceInstallRecord record) async {}
  @override
  Future<void> removeResourceRecord(String moduleId, String resourceId) async {}
}

void main() {
  test('a peer game can register routes without importing another game', () {
    Widget thirdGameRoute(BuildContext context) => const SizedBox();

    final routes = buildGameModuleRoutes([
      {'/third-game': thirdGameRoute},
    ]);

    expect(routes.keys, ['/third-game']);
    expect(routes['/third-game'], same(thirdGameRoute));
    expect(
      () => buildGameModuleRoutes([
        {'/third-game': thirdGameRoute},
        {'/third-game': thirdGameRoute},
      ]),
      throwsA(isA<StateError>()),
    );
  });

  testWidgets(
    'disabled game routes return the Game Library instead of launching',
    (tester) async {
      final library = GameLibraryController(
        catalog: GameModuleCatalog([
          GameModuleManifest(
            moduleId: 'game.archery',
            displayName: 'Archery',
            description: 'Single-player test module',
            packageVersion: '1.0.0',
            minimumShellVersion: '1.0.0',
            dataSchemaVersion: 1,
            resources: const [],
          ),
        ]),
        store: _MemoryStore(),
      );
      await library.initialize();
      final locale = LocaleProvider(
        defaultLocale: 'en',
        translationResolver: (_) => const {},
      );
      addTearDown(locale.dispose);

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<GameLibraryController>.value(value: library),
            ChangeNotifierProvider<LocaleProvider>.value(value: locale),
          ],
          child: MaterialApp(
            initialRoute: '/archery',
            routes: gameModuleRoutes,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Game Library'), findsOneWidget);
      expect(find.text('Archery'), findsOneWidget);
    },
  );

  testWidgets('disabled Mini Royale route returns the Game Library', (
    tester,
  ) async {
    final library = GameLibraryController(
      catalog: GameModuleCatalog([
        GameModuleManifest(
          moduleId: 'game.archery',
          displayName: 'Archery',
          description: 'Single-player test module',
          packageVersion: '1.0.0',
          minimumShellVersion: '1.0.0',
          dataSchemaVersion: 1,
          resources: const [],
        ),
      ]),
      store: _MemoryStore(),
    );
    await library.initialize();
    final locale = LocaleProvider(
      defaultLocale: 'en',
      translationResolver: (_) => const {},
    );
    addTearDown(locale.dispose);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<GameLibraryController>.value(value: library),
          ChangeNotifierProvider<LocaleProvider>.value(value: locale),
        ],
        child: MaterialApp(
          initialRoute: '/royale-deck',
          routes: gameModuleRoutes,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Game Library'), findsOneWidget);
    expect(find.text('Archery'), findsOneWidget);
  });
}
