import 'package:flutter/widgets.dart';

import '../services/game_resource_installer.dart';
import 'game_module_home_entry.dart';
import 'game_module_manifest.dart';
import 'game_module_room_invite_handler.dart';

/// One bundled game's contributions to the host shell.
///
/// The game package owns its domain and manifest. This host adapter binds the
/// package to routes, optional shell UI, and payload validators without adding
/// game-specific branches to generic consumers.
class GameModuleRegistration {
  GameModuleRegistration({
    required this.manifest,
    Map<String, WidgetBuilder> routes = const {},
    List<GameModuleHomeEntry> homeEntries = const [],
    List<GameModuleHomeCollectionEntry> homeCollections = const [],
    this.libraryExtension,
    this.roomInviteHandler,
    Map<String, GameResourceMigration> resourceMigrations = const {},
  }) : routes = Map.unmodifiable(routes),
       homeEntries = List.unmodifiable(homeEntries),
       homeCollections = List.unmodifiable(homeCollections),
       resourceMigrations = Map.unmodifiable(resourceMigrations) {
    manifest.validate();
    if (manifest.moduleId.trim().isEmpty) {
      throw const FormatException('A game registration needs a module ID.');
    }
    if (roomInviteHandler != null &&
        roomInviteHandler!.gameId != manifest.moduleId) {
      throw FormatException(
        'Room invite handler ${roomInviteHandler!.gameId} does not match ${manifest.moduleId}.',
      );
    }
    void validateHomeEntry(String moduleId, String routeName) {
      if (moduleId != manifest.moduleId) {
        throw FormatException(
          'Home entry $routeName belongs to $moduleId, not ${manifest.moduleId}.',
        );
      }
    }

    for (final entry in this.homeEntries) {
      validateHomeEntry(entry.moduleId, entry.routeName);
    }
    for (final entry in this.homeCollections) {
      validateHomeEntry(entry.moduleId, entry.routeName);
    }
    for (final routeName in [
      ...this.homeEntries.map((entry) => entry.routeName),
      ...this.homeCollections.map((entry) => entry.routeName),
    ]) {
      if (!this.routes.containsKey(routeName)) {
        throw FormatException(
          'Home entry $routeName has no route in ${manifest.moduleId}.',
        );
      }
    }
    if (this.routes.keys.any((route) => route.trim().isEmpty)) {
      throw const FormatException('Game routes cannot be empty.');
    }
    for (final key in this.resourceMigrations.keys) {
      if (!key.startsWith('${manifest.moduleId}:')) {
        throw FormatException(
          'Resource validator $key is outside ${manifest.moduleId}.',
        );
      }
      if (key.length == manifest.moduleId.length + 1) {
        throw FormatException(
          'Resource validator $key has an empty resource ID.',
        );
      }
    }
  }

  final GameModuleManifest manifest;
  final Map<String, WidgetBuilder> routes;
  final List<GameModuleHomeEntry> homeEntries;
  final List<GameModuleHomeCollectionEntry> homeCollections;
  final WidgetBuilder? libraryExtension;
  final GameModuleRoomInviteHandler? roomInviteHandler;
  final Map<String, GameResourceMigration> resourceMigrations;

  String get moduleId => manifest.moduleId;
}
