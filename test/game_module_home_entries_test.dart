import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taiwan_brawl/game_modules/game_module_home_entries.dart';

void main() {
  test(
    'Home launch and collection descriptors filter by enabled module IDs',
    () {
      final launchEntries = homeEntriesForEnabledModules(
        entries: gameModuleHomeEntries,
        enabledModuleIds: {'game.archery'},
        moduleIdOf: (entry) => entry.moduleId,
      );
      final collections = homeEntriesForEnabledModules(
        entries: gameModuleHomeCollections,
        enabledModuleIds: {'game.archery'},
        moduleIdOf: (entry) => entry.moduleId,
      );

      expect(launchEntries.map((entry) => entry.moduleId), ['game.archery']);
      expect(collections, isEmpty);
    },
  );

  test('a new module can register an entry without changing Home layout', () {
    const futureGame = GameModuleHomeEntry(
      moduleId: 'game.future',
      titleKey: 'Future Game',
      descriptionKey: 'Future game description',
      tag: 'SOLO',
      icon: Icons.gamepad,
      accentColor: Colors.purple,
      routeName: '/future-game',
    );
    final visible = homeEntriesForEnabledModules(
      entries: [...gameModuleHomeEntries, futureGame],
      enabledModuleIds: {'game.future'},
      moduleIdOf: (entry) => entry.moduleId,
    );

    expect(visible, [futureGame]);
  });
}
