import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taiwan_brawl/game_modules/bundled_game_catalog.dart';
import 'package:taiwan_brawl/game_modules/game_module_home_entries.dart';
import 'package:taiwan_brawl/game_modules/game_module_library_extensions.dart';
import 'package:taiwan_brawl/game_modules/game_module_manifest.dart';
import 'package:taiwan_brawl/game_modules/game_module_registration.dart';
import 'package:taiwan_brawl/game_modules/game_module_registrations.dart';
import 'package:taiwan_brawl/game_modules/game_module_routes.dart';
import 'package:taiwan_brawl/game_modules/game_module_room_invite_handler.dart';
import 'package:taiwan_brawl/game_modules/game_module_room_invite_registry.dart';
import 'package:taiwan_brawl/game_modules/game_resource_migrations.dart';
import 'package:taiwan_brawl/models/friends_models.dart';

class _FixtureRoomInviteHandler implements GameModuleRoomInviteHandler {
  const _FixtureRoomInviteHandler();

  @override
  String get gameId => 'game.fixture';

  @override
  Future<void> accept(BuildContext context, RoomInviteItem invite) async {}
}

GameModuleRegistration _registration(
  String moduleId, {
  Map<String, WidgetBuilder> routes = const {},
}) => GameModuleRegistration(
  manifest: GameModuleManifest(
    moduleId: moduleId,
    displayName: moduleId,
    description: 'Registration fixture',
    packageVersion: '1.0.0',
    minimumShellVersion: '1.0.0',
    dataSchemaVersion: 1,
    resources: const [],
  ),
  routes: routes,
);

void main() {
  test(
    'catalog, routes, Home, Library and validators derive from registrations',
    () {
      final registeredIds = gameModuleRegistrations
          .map((registration) => registration.moduleId)
          .toSet();

      expect(
        bundledGameCatalog.manifests
            .map((manifest) => manifest.moduleId)
            .toSet(),
        registeredIds,
      );
      expect(
        gameModuleRoutes.keys.toSet(),
        gameModuleRegistrations
            .expand((registration) => registration.routes.keys)
            .toSet(),
      );
      expect(
        gameModuleHomeEntries.every(
              (entry) => registeredIds.contains(entry.moduleId),
            ) &&
            gameModuleHomeCollections.every(
              (entry) => registeredIds.contains(entry.moduleId),
            ),
        isTrue,
      );
      expect(
        gameModuleLibraryExtensions.keys.every(registeredIds.contains),
        isTrue,
      );
      expect(
        gameResourceMigrations.keys.every(
          (key) =>
              registeredIds.any((moduleId) => key.startsWith('$moduleId:')),
        ),
        isTrue,
      );
    },
  );

  test('duplicate module IDs and routes fail at registry composition', () {
    expect(
      () => buildGameModuleRegistrations([
        _registration('game.fixture'),
        _registration('game.fixture'),
      ]),
      throwsFormatException,
    );
    expect(
      () => buildGameModuleRegistrations([
        _registration(
          'game.first',
          routes: {'/fixture': (_) => const SizedBox()},
        ),
        _registration(
          'game.second',
          routes: {'/fixture': (_) => const SizedBox()},
        ),
      ]),
      throwsFormatException,
    );
  });

  test('registry safely materializes a lazy registration iterable once', () {
    Iterable<GameModuleRegistration> registrations() sync* {
      yield _registration('game.lazy');
    }

    expect(
      buildGameModuleRegistrations(registrations()).single.moduleId,
      'game.lazy',
    );
  });

  test('a new peer game composes into every generic host contribution', () {
    final fixture = GameModuleRegistration(
      manifest: GameModuleManifest(
        moduleId: 'game.fixture',
        displayName: 'Fixture Game',
        description: 'Synthetic third game for host composition coverage.',
        packageVersion: '1.0.0',
        minimumShellVersion: '1.0.0',
        dataSchemaVersion: 1,
        resources: const [
          GameResourceManifest(
            resourceId: 'game.fixture.rules',
            version: '1.0.0',
            kind: GameResourceKind.gameplayData,
            sha256:
                'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
            affectsGameplay: true,
          ),
        ],
      ),
      routes: {'/fixture-game': (_) => const SizedBox()},
      homeEntries: const [
        GameModuleHomeEntry(
          moduleId: 'game.fixture',
          titleKey: 'fixture.title',
          descriptionKey: 'fixture.description',
          tag: 'TEST',
          icon: Icons.gamepad,
          accentColor: Colors.green,
          routeName: '/fixture-game',
        ),
      ],
      homeCollections: const [
        GameModuleHomeCollectionEntry(
          moduleId: 'game.fixture',
          titleKey: 'fixture.collection.title',
          descriptionKey: 'fixture.collection.description',
          icon: Icons.folder,
          routeName: '/fixture-game',
        ),
      ],
      libraryExtension: (_) => const SizedBox(),
      roomInviteHandler: const _FixtureRoomInviteHandler(),
      resourceMigrations: {'game.fixture:game.fixture.rules': (_) async {}},
    );
    final registrations = buildGameModuleRegistrations([fixture]);

    expect(
      buildBundledGameCatalog(registrations)['game.fixture'],
      same(fixture.manifest),
    );
    expect(buildGameModuleRoutesFromRegistrations(registrations).keys, [
      '/fixture-game',
    ]);
    expect(
      buildGameModuleHomeEntries(registrations).single.moduleId,
      'game.fixture',
    );
    expect(
      buildGameModuleHomeCollections(registrations).single.moduleId,
      'game.fixture',
    );
    expect(buildGameModuleLibraryExtensions(registrations).keys, [
      'game.fixture',
    ]);
    expect(buildGameModuleRoomInviteHandlers(registrations).keys, [
      'game.fixture',
    ]);
    expect(buildGameResourceMigrations(registrations).keys, [
      'game.fixture:game.fixture.rules',
    ]);
  });

  test('room invite handlers must be owned by their registered game', () {
    expect(
      () => GameModuleRegistration(
        manifest: _registration('game.owner').manifest,
        roomInviteHandler: const _FixtureRoomInviteHandler(),
      ),
      throwsFormatException,
    );
  });

  test(
    'Home entries cannot point at another module or an unregistered route',
    () {
      expect(
        () => GameModuleRegistration(
          manifest: _registration('game.owner').manifest,
          routes: {'/owner': (_) => const SizedBox()},
          homeEntries: const [
            GameModuleHomeEntry(
              moduleId: 'game.other',
              titleKey: 'Other',
              descriptionKey: 'Other',
              tag: 'SOLO',
              icon: Icons.gamepad,
              accentColor: Colors.blue,
              routeName: '/owner',
            ),
          ],
        ),
        throwsFormatException,
      );
      expect(
        () => GameModuleRegistration(
          manifest: _registration('game.owner').manifest,
          homeEntries: const [
            GameModuleHomeEntry(
              moduleId: 'game.owner',
              titleKey: 'Owner',
              descriptionKey: 'Owner',
              tag: 'SOLO',
              icon: Icons.gamepad,
              accentColor: Colors.blue,
              routeName: '/missing',
            ),
          ],
        ),
        throwsFormatException,
      );
    },
  );
}
