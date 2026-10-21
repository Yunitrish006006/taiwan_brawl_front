import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:integration_test/integration_test.dart';
import 'package:taiwan_brawl/config/app_configuration.dart';
import 'package:taiwan_brawl/game_modules/game_module_manifest.dart';
import 'package:taiwan_brawl/services/api_client.dart';
import 'package:taiwan_brawl/services/game_library_controller.dart';
import 'package:taiwan_brawl/services/game_library_store.dart';
import 'package:taiwan_brawl/services/game_resource_catalog_source.dart';
import 'package:taiwan_brawl/services/game_resource_content_store.dart';
import 'package:taiwan_brawl/services/game_resource_installer.dart';
import 'package:taiwan_brawl/services/game_resource_library_service.dart';

class _IntegrationSignatureVerifier implements GameResourceSignatureVerifier {
  @override
  Future<bool> verify({
    required String keyId,
    required String signature,
    required String moduleId,
    required String resourceId,
    required String version,
    required String sha256,
    required Uint8List payload,
  }) async =>
      keyId == 'integration-test-key' &&
      signature == 'integration-test-signature';
}

GameModuleManifest _manifest(Uint8List payload, String version) {
  const moduleId = 'game.archery';
  const resourceId = 'game.archery.rules';
  return GameModuleManifest(
    moduleId: moduleId,
    displayName: 'Archery',
    description: 'Native install/update/rollback integration fixture.',
    packageVersion: '0.1.0',
    minimumShellVersion: '0.132.0',
    dataSchemaVersion: 1,
    resources: [
      GameResourceManifest(
        resourceId: resourceId,
        version: version,
        kind: GameResourceKind.gameplayData,
        sha256: sha256.convert(payload).toString(),
        affectsGameplay: true,
        downloadUrl: 'https://assets.example.test/archery/$version.json',
        byteLength: payload.length,
        signature: 'integration-test-signature',
        signingKeyId: 'integration-test-key',
      ),
    ],
  );
}

GameResourceInstaller _installer({
  required GameLibraryController controller,
  required GameResourceContentStore content,
  required Uint8List responsePayload,
}) => GameResourceInstaller(
  controller: controller,
  contentStore: content,
  signatureVerifier: _IntegrationSignatureVerifier(),
  client: MockClient((_) async => http.Response.bytes(responsePayload, 200)),
);

GameResourceLibraryService _libraryService({
  required GameLibraryController controller,
  required GameResourceContentStore content,
  required Uint8List responsePayload,
  Map<String, GameResourceMigration> resourceMigrations = const {},
}) {
  final api = ApiClient(
    client: MockClient((_) async => http.Response('{}', 200)),
    configuration: const AppConfiguration(
      apiBaseUrl: 'https://example.test',
      googleWebClientId: '',
      googleServerClientId: '',
      p2pChatEnabled: false,
      previewMode: true,
      peerVerificationEnabled: false,
    ),
  );
  return GameResourceLibraryService(
    controller: controller,
    catalogSource: GameResourceCatalogSource(api),
    installer: _installer(
      controller: controller,
      content: content,
      responsePayload: responsePayload,
    ),
    contentStore: content,
    resourceMigrations: resourceMigrations,
  );
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'native resource install, rollback, update, restart restore and removal',
    (tester) async {
      await Hive.initFlutter();
      final suffix = DateTime.now().microsecondsSinceEpoch;
      final libraryBox = 'native_integration_library_$suffix';
      final contentBox = 'native_integration_content_$suffix';
      final pointerBox = 'native_integration_pointers_$suffix';
      const moduleId = 'game.archery';
      const resourceId = 'game.archery.rules';
      final versionOne = Uint8List.fromList([0, 10, 127, 128, 255]);
      final versionTwo = Uint8List.fromList([9, 8, 7, 6, 5, 4]);
      final manifestOne = _manifest(versionOne, '1.0.0');
      final manifestTwo = _manifest(versionTwo, '2.0.0');
      final library = HiveGameLibraryStore(boxName: libraryBox);
      final content = HiveGameResourceContentStore(
        contentBoxName: contentBox,
        pointerBoxName: pointerBox,
      );
      final controller = GameLibraryController(
        catalog: GameModuleCatalog([manifestOne]),
        store: library,
      );
      await controller.initialize();
      await controller.setModuleEnabled(moduleId, true);
      final installerV1 = _libraryService(
        controller: controller,
        content: content,
        responsePayload: versionOne,
      );
      await installerV1.install(moduleId, resourceId);

      expect(await content.readActiveVersion(moduleId, resourceId), '1.0.0');
      expect(await content.readActive(moduleId, resourceId), versionOne);
      expect(
        controller.resourceRecord(moduleId, resourceId)?.status,
        GameResourceInstallStatus.installed,
      );

      controller.mergeRemoteManifests([manifestTwo]);
      final failedUpdate = _libraryService(
        controller: controller,
        content: content,
        responsePayload: versionTwo,
        resourceMigrations: {
          '$moduleId:$resourceId': (_) async =>
              throw StateError('fixture migration failure'),
        },
      );
      await expectLater(
        failedUpdate.install(moduleId, resourceId),
        throwsStateError,
      );
      expect(await content.readActiveVersion(moduleId, resourceId), '1.0.0');
      expect(await content.readActive(moduleId, resourceId), versionOne);
      expect(controller.resourceRecord(moduleId, resourceId)?.version, '1.0.0');

      final successfulUpdate = _libraryService(
        controller: controller,
        content: content,
        responsePayload: versionTwo,
      );
      await successfulUpdate.install(moduleId, resourceId);
      expect(await content.readActiveVersion(moduleId, resourceId), '2.0.0');
      expect(await content.readActive(moduleId, resourceId), versionTwo);
      expect(
        controller.resourceRecord(moduleId, resourceId)?.sha256,
        sha256.convert(versionTwo).toString(),
      );
      await library.writeCachedResourceCatalog(
        CachedGameResourceCatalog(manifests: [manifestTwo]),
      );

      // Close and reopen platform-backed Hive before asserting durable state.
      await Hive.close();
      await Hive.initFlutter();
      final restoredLibrary = HiveGameLibraryStore(boxName: libraryBox);
      final restoredContent = HiveGameResourceContentStore(
        contentBoxName: contentBox,
        pointerBoxName: pointerBox,
      );
      final restoredController = GameLibraryController(
        catalog: GameModuleCatalog([manifestTwo]),
        store: restoredLibrary,
      );
      await restoredController.initialize();
      expect(restoredController.enabledModuleIds, {moduleId});
      expect(
        restoredController.resourceRecord(moduleId, resourceId)?.version,
        '2.0.0',
      );
      expect(
        await restoredContent.readActiveVersion(moduleId, resourceId),
        '2.0.0',
      );
      expect(
        await restoredContent.readActive(moduleId, resourceId),
        versionTwo,
      );

      await _libraryService(
        controller: restoredController,
        content: restoredContent,
        responsePayload: versionTwo,
      ).remove(moduleId, resourceId);
      expect(
        await restoredContent.readActiveVersion(moduleId, resourceId),
        isNull,
      );
      expect(await restoredContent.readActive(moduleId, resourceId), isNull);
      expect(restoredController.resourceRecord(moduleId, resourceId), isNull);
      expect(restoredController.isModuleEnabled(moduleId), isTrue);
      restoredController.dispose();
      controller.dispose();
      await Hive.close();
      await Hive.deleteBoxFromDisk(libraryBox);
      await Hive.deleteBoxFromDisk(contentBox);
      await Hive.deleteBoxFromDisk(pointerBox);
    },
  );
}
