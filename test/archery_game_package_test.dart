import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taiwan_brawl/game_modules/bundled_game_catalog.dart';
import 'package:taiwan_brawl_game_archery/taiwan_brawl_game_archery.dart';
import 'package:taiwan_brawl/game_modules/archery_hive_progress_backend.dart';
import 'package:user_ui_settings/user_ui_settings.dart';

void main() {
  test('host catalog consumes the manifest owned by the Archery package', () {
    final archery = bundledGameCatalog[archeryGameModuleId]!;
    expect(archery.moduleId, archeryGameManifest.moduleId);
    expect(archery.packageVersion, archeryGameManifest.packageVersion);
    expect(
      archery.minimumShellVersion,
      archeryGameManifest.minimumShellVersion,
    );
    expect(archery.dataSchemaVersion, archeryGameManifest.dataSchemaVersion);
    expect(archery.multiplayer, isNull);
  });

  test('App provides an isolated persistence backend to Archery data', () {
    final backend = HiveArcheryPlayerDataBackend();
    expect(backend.boxName, 'archery_player_data_v1');
    expect(archeryGameManifest.dataSchemaVersion, 1);
  });

  testWidgets('the separately packaged Archery module opens its game UI', (
    tester,
  ) async {
    final settings = GameUiSettings(
      locale: 'en',
      themeId: 'test-light',
      themeMode: ThemeMode.light,
      activeTheme: ThemeData.light(useMaterial3: true),
      fontScale: 1,
      disableAnimations: true,
      accessibleNavigation: true,
    );

    await tester.pumpWidget(
      GameUiSettingsScope(
        settings: settings,
        child: const MaterialApp(home: ArcheryGamePage()),
      ),
    );

    expect(find.text('Archery Game'), findsOneWidget);
    expect(find.text('Long press to draw'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
  });
}
