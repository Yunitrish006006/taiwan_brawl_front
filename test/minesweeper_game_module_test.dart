import 'package:flutter_test/flutter_test.dart';
import 'package:taiwan_brawl/game_modules/bundled_game_catalog.dart';
import 'package:taiwan_brawl/game_modules/game_module_home_entries.dart';
import 'package:taiwan_brawl/game_modules/game_module_routes.dart';
import 'package:taiwan_brawl/game_modules/minesweeper_game_registration.dart';

void main() {
  test('minesweeper is present in the host catalog and Home registry', () {
    final manifest = bundledGameCatalog[minesweeperGameModuleId];
    expect(manifest, isNotNull);
    expect(manifest!.displayName, '踩地雷');
    expect(manifest.packageVersion, '0.1.0');
    final entry = gameModuleHomeEntries.firstWhere(
      (item) => item.moduleId == minesweeperGameModuleId,
    );
    expect(entry.titleResolver?.call('en'), 'Minesweeper');
    expect(
      entry.descriptionResolver?.call('en'),
      'Choose a board size and find all the mines.',
    );
    expect(gameModuleRoutes.containsKey('/minesweeper'), isTrue);
  });
}
