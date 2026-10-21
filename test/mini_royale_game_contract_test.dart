import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taiwan_brawl/game_modules/game_module_manifest.dart';
import 'package:taiwan_brawl/game_modules/mini_royale_game_contract.dart';
import 'package:taiwan_brawl/services/game_library_controller.dart';
import 'package:taiwan_brawl/services/game_library_store.dart';
import 'package:taiwan_brawl_game_mini_royale/taiwan_brawl_game_mini_royale.dart';

class _Store implements GameLibraryStore {
  _Store(this.records);
  final Map<String, GameResourceInstallRecord> records;

  @override
  Future<Set<String>> readEnabledModuleIds() async => {};
  @override
  Future<Map<String, GameResourceInstallRecord>> readResourceRecords() async =>
      records;
  @override
  Future<void> removeResourceRecord(String moduleId, String resourceId) async {
    records.remove('$moduleId:$resourceId');
  }

  @override
  Future<void> writeEnabledModuleIds(Set<String> moduleIds) async {}
  @override
  Future<void> writeResourceRecord(GameResourceInstallRecord record) async {
    records['${record.moduleId}:${record.resourceId}'] = record;
  }
}

void main() {
  const installedHash =
      'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
  const pendingHash =
      'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';
  const gameplay = GameResourceManifest(
    resourceId: miniRoyaleGameplayRulesResourceId,
    version: '1.2.0',
    kind: GameResourceKind.gameplayData,
    sha256: installedHash,
    affectsGameplay: true,
  );
  const presentation = GameResourceManifest(
    resourceId: 'game.mini-royale.art',
    version: '2.0.0',
    kind: GameResourceKind.presentation,
    sha256: pendingHash,
    affectsGameplay: false,
  );

  GameModuleManifest manifest(List<GameResourceManifest> resources) =>
      GameModuleManifest(
        moduleId: miniRoyaleModuleId,
        displayName: 'Mini Royale',
        description: 'test',
        packageVersion: miniRoyalePackageVersion,
        minimumShellVersion: '0.132.0',
        dataSchemaVersion: miniRoyaleDataSchemaVersion,
        resources: resources,
      );

  test('uses built-in digest when no gameplay packs are installed', () async {
    final controller = GameLibraryController(
      catalog: GameModuleCatalog([
        manifest([gameplay, presentation]),
      ]),
      store: _Store({}),
    );
    await controller.initialize();

    expect(miniRoyaleGameContractFor(controller), miniRoyaleGameContract);
  });

  test(
    'hashes only installed, gameplay-affecting resources in stable order',
    () async {
      final key = '$miniRoyaleModuleId:${gameplay.resourceId}';
      final record = GameResourceInstallRecord(
        moduleId: miniRoyaleModuleId,
        resourceId: gameplay.resourceId,
        version: gameplay.version,
        sha256: installedHash,
        status: GameResourceInstallStatus.installed,
      );
      final records = {key: record};
      final controller = GameLibraryController(
        catalog: GameModuleCatalog([
          manifest([presentation, gameplay]),
        ]),
        store: _Store(records),
      );
      await controller.initialize();

      final contract = miniRoyaleGameContractFor(controller);
      final expected = sha256
          .convert(
            utf8.encode(
              '${miniRoyaleGameContract['gameplayContentDigest']}\n'
              '${gameplay.resourceId}@${gameplay.version}:$installedHash',
            ),
          )
          .toString();
      expect(contract['gameplayContentDigest'], expected);
      expect(
        contract['gameplayResources'],
        [
          {
            'resourceId': miniRoyaleGameplayRulesResourceId,
            'version': gameplay.version,
            'sha256': installedHash,
          },
        ],
      );
      expect(
        contract['protocolVersion'],
        miniRoyaleGameContract['protocolVersion'],
      );

      await controller.recordResourceState(
        GameResourceInstallRecord(
          moduleId: miniRoyaleModuleId,
          resourceId: gameplay.resourceId,
          version: gameplay.version,
          sha256: gameplay.sha256,
          status: GameResourceInstallStatus.removing,
        ),
      );
      expect(miniRoyaleGameContractFor(controller), miniRoyaleGameContract);
    },
  );
}
