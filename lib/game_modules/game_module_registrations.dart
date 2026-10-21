import 'archery_game_registration.dart';
import 'game_module_registration.dart';
import 'mini_royale_game_registration.dart';

/// The only host-level registration point for bundled game adapters.
/// Generic catalog, routing, Home, Library, and resource systems derive their
/// contributions from this registry.
final List<GameModuleRegistration> gameModuleRegistrations =
    buildGameModuleRegistrations([
      archeryGameRegistration,
      miniRoyaleGameRegistration,
    ]);

List<GameModuleRegistration> buildGameModuleRegistrations(
  Iterable<GameModuleRegistration> registrations,
) {
  final entries = List<GameModuleRegistration>.of(registrations);
  final modules = <String>{};
  final routes = <String>{};
  for (final registration in entries) {
    if (!modules.add(registration.moduleId)) {
      throw FormatException(
        'Duplicate game module registration: ${registration.moduleId}',
      );
    }
    for (final route in registration.routes.keys) {
      if (!routes.add(route)) {
        throw FormatException('Duplicate game module route: $route');
      }
    }
  }
  return List.unmodifiable(entries);
}
