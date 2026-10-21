import 'game_module_room_invite_handler.dart';
import 'game_module_registration.dart';
import 'game_module_registrations.dart';

Map<String, GameModuleRoomInviteHandler> buildGameModuleRoomInviteHandlers(
  Iterable<GameModuleRegistration> registrations,
) {
  final handlers = <String, GameModuleRoomInviteHandler>{};
  for (final registration in registrations) {
    final handler = registration.roomInviteHandler;
    if (handler == null) continue;
    if (handlers.containsKey(handler.gameId)) {
      throw FormatException('Duplicate room invite handler: ${handler.gameId}');
    }
    handlers[handler.gameId] = handler;
  }
  return Map.unmodifiable(handlers);
}

final Map<String, GameModuleRoomInviteHandler> gameModuleRoomInviteHandlers =
    buildGameModuleRoomInviteHandlers(gameModuleRegistrations);
