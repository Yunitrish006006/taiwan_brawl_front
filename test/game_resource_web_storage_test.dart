import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:taiwan_brawl/game_modules/game_module_manifest.dart';
import 'package:taiwan_brawl/services/game_library_store.dart';
import 'package:taiwan_brawl/services/game_resource_content_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final suffix = DateTime.now().microsecondsSinceEpoch.toString();
  final libraryBox = 'game_library_web_$suffix';
  final contentBox = 'game_resource_web_content_$suffix';
  final pointerBox = 'game_resource_web_pointer_$suffix';

  if (kIsWeb) setUpAll(Hive.initFlutter);
  if (kIsWeb) tearDownAll(Hive.close);

  test(
    'Web IndexedDB persists game catalog and versioned resource bytes',
    () async {
      final manifest = GameModuleManifest(
        moduleId: 'game.archery',
        displayName: 'Archery',
        description: 'Browser storage test',
        packageVersion: '0.1.0',
        minimumShellVersion: '0.132.0',
        dataSchemaVersion: 1,
        resources: const [
          GameResourceManifest(
            resourceId: 'game.archery.rules',
            version: '1.0.0',
            kind: GameResourceKind.gameplayData,
            sha256:
                'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
            affectsGameplay: true,
          ),
        ],
      );
      final library = HiveGameLibraryStore(boxName: libraryBox);
      await library.writeEnabledModuleIds({'game.archery'});
      await library.writeCachedResourceCatalog(
        CachedGameResourceCatalog(manifests: [manifest]),
      );

      final bytes = Uint8List.fromList([0, 1, 2, 128, 255]);
      final content = HiveGameResourceContentStore(
        contentBoxName: contentBox,
        pointerBoxName: pointerBox,
      );
      await content.writeStaged(
        'game.archery',
        'game.archery.rules',
        '1.0.0',
        bytes,
      );
      await content.activate('game.archery', 'game.archery.rules', '1.0.0');

      // Force a fresh IndexedDB connection instead of reading through Hive's
      // already-open boxes, which would not prove persistence across reload.
      await Hive.close();
      await Hive.initFlutter();

      final restoredLibrary = HiveGameLibraryStore(boxName: libraryBox);
      final restoredContent = HiveGameResourceContentStore(
        contentBoxName: contentBox,
        pointerBoxName: pointerBox,
      );
      expect(await restoredLibrary.readEnabledModuleIds(), {'game.archery'});
      expect(
        (await restoredLibrary.readCachedResourceCatalog())!.manifests.single
            .toJson(),
        manifest.toJson(),
      );
      expect(
        await restoredContent.readActiveVersion(
          'game.archery',
          'game.archery.rules',
        ),
        '1.0.0',
      );
      expect(
        await restoredContent.readActive('game.archery', 'game.archery.rules'),
        bytes,
      );
    },
    skip: !kIsWeb,
  );
}
