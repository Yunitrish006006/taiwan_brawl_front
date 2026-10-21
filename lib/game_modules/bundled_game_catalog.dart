import 'game_module_manifest.dart';
import 'game_module_registration.dart';
import 'game_module_registrations.dart';

GameModuleCatalog buildBundledGameCatalog(
  Iterable<GameModuleRegistration> registrations,
) => GameModuleCatalog(
  registrations.map((registration) => registration.manifest),
);

final bundledGameCatalog = buildBundledGameCatalog(gameModuleRegistrations);
