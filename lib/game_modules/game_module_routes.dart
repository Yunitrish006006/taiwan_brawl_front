import 'package:flutter/widgets.dart';

import 'game_module_registration.dart';
import 'game_module_registrations.dart';

/// Combines route contributions from peer game modules.
///
/// A route collision is a registration error, not an override mechanism: a
/// silent last-writer-wins merge can launch the wrong game's screen.
Map<String, WidgetBuilder> buildGameModuleRoutes(
  Iterable<Map<String, WidgetBuilder>> registrations,
) {
  final routes = <String, WidgetBuilder>{};
  for (final registration in registrations) {
    for (final entry in registration.entries) {
      if (routes.containsKey(entry.key)) {
        throw StateError('Duplicate game module route: ${entry.key}');
      }
      routes[entry.key] = entry.value;
    }
  }
  return Map.unmodifiable(routes);
}

/// Host route registry composed from independently maintained game adapters.
/// The shell mounts these routes without owning any individual game's code.
final Map<String, WidgetBuilder> gameModuleRoutes = buildGameModuleRoutes(
  gameModuleRegistrations.map((registration) => registration.routes),
);

Map<String, WidgetBuilder> buildGameModuleRoutesFromRegistrations(
  Iterable<GameModuleRegistration> registrations,
) => buildGameModuleRoutes(
  registrations.map((registration) => registration.routes),
);
