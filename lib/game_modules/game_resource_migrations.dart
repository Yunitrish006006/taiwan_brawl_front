import '../services/game_resource_installer.dart';
import 'game_module_registration.dart';
import 'game_module_registrations.dart';

/// Host adapter registry for validations owned by the bundled game packages.
/// A declared owner schema without a registered validator fails closed before
/// the resource active-set pointer can change.
Map<String, GameResourceMigration> buildGameResourceMigrations(
  Iterable<GameModuleRegistration> registrations,
) => Map<String, GameResourceMigration>.unmodifiable({
  for (final registration in registrations) ...registration.resourceMigrations,
});

final gameResourceMigrations = buildGameResourceMigrations(
  gameModuleRegistrations,
);
