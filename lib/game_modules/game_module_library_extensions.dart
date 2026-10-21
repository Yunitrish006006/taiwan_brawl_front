import 'package:flutter/widgets.dart';
import 'game_module_registration.dart';
import 'game_module_registrations.dart';

/// Optional package-owned sections contributed to a game library card.
/// Register additional game UI here without coupling the generic library page
/// to that game's package or stable ID.
Map<String, WidgetBuilder> buildGameModuleLibraryExtensions(
  Iterable<GameModuleRegistration> registrations,
) => Map.unmodifiable({
  for (final registration in registrations)
    if (registration.libraryExtension != null)
      registration.moduleId: registration.libraryExtension!,
});

final Map<String, WidgetBuilder> gameModuleLibraryExtensions =
    buildGameModuleLibraryExtensions(gameModuleRegistrations);
