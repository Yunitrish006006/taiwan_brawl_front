import 'package:taiwan_brawl_game_mini_royale/taiwan_brawl_game_mini_royale.dart';

import '../services/game_library_controller.dart';
import 'game_module_manifest.dart';

/// Bind multiplayer compatibility to the verified gameplay packs currently
/// active in the local game library. Cosmetic and merely downloaded packs do
/// not participate in compatibility.
Map<String, Object> miniRoyaleGameContractFor(GameLibraryController library) {
  final base = miniRoyaleGameContract;
  final manifest = library.catalog[miniRoyaleModuleId];
  final resources =
      (manifest?.resources ?? const <GameResourceManifest>[]).where((resource) {
          if (!resource.affectsGameplay) return false;
          final installed = library.resourceRecord(
            miniRoyaleModuleId,
            resource.resourceId,
          );
          return installed?.status == GameResourceInstallStatus.installed &&
              installed?.version == resource.version &&
              installed?.sha256.toLowerCase() == resource.sha256.toLowerCase();
        }).toList()
        ..sort((left, right) => left.resourceId.compareTo(right.resourceId));
  final resourceContracts = resources
      .map(
        (resource) => <String, Object>{
          'resourceId': resource.resourceId,
          'version': resource.version,
          'sha256': resource.sha256.toLowerCase(),
        },
      )
      .toList(growable: false);
  return {
    ...base,
    'gameplayContentDigest': miniRoyaleGameplayContentDigestForResources(
      resources.map(
        (resource) => (
          resourceId: resource.resourceId,
          version: resource.version,
          sha256: resource.sha256,
        ),
      ),
    ),
    'gameplayResources': resourceContracts,
  };
}
