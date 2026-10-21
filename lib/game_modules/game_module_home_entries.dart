import 'game_module_home_entry.dart';
import 'game_module_registration.dart';
import 'game_module_registrations.dart';

export 'game_module_home_entry.dart';

List<GameModuleHomeEntry> buildGameModuleHomeEntries(
  Iterable<GameModuleRegistration> registrations,
) => List.unmodifiable(
  registrations.expand((registration) => registration.homeEntries),
);

List<GameModuleHomeCollectionEntry> buildGameModuleHomeCollections(
  Iterable<GameModuleRegistration> registrations,
) => List.unmodifiable(
  registrations.expand((registration) => registration.homeCollections),
);

final List<GameModuleHomeEntry> gameModuleHomeEntries =
    buildGameModuleHomeEntries(gameModuleRegistrations);

final List<GameModuleHomeCollectionEntry> gameModuleHomeCollections =
    buildGameModuleHomeCollections(gameModuleRegistrations);

List<T> homeEntriesForEnabledModules<T extends Object>({
  required Iterable<T> entries,
  required Set<String> enabledModuleIds,
  required String Function(T entry) moduleIdOf,
}) => entries
    .where((entry) => enabledModuleIds.contains(moduleIdOf(entry)))
    .toList(growable: false);
