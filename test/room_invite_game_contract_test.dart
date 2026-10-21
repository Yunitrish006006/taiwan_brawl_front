import 'package:flutter_test/flutter_test.dart';
import 'package:taiwan_brawl/game_modules/game_module_room_invite_registry.dart';
import 'package:taiwan_brawl/models/friends_models.dart';

void main() {
  test(
    'room invite model preserves game identity and supports old Royale payloads',
    () {
      final archeryInvite = RoomInviteItem.fromJson({
        'id': 7,
        'gameId': 'game.archery',
        'roomCode': 'ARCH7',
        'createdAt': '2026-10-20T00:00:00Z',
        'inviter': {'userId': 2, 'name': 'Friend'},
      });
      final legacyInvite = RoomInviteItem.fromJson({
        'id': 8,
        'roomCode': 'ROY8',
        'inviter': {'userId': 3, 'name': 'Legacy Friend'},
      });

      expect(archeryInvite.gameId, 'game.archery');
      expect(legacyInvite.gameId, 'game.mini-royale');
      expect(gameModuleRoomInviteHandlers[archeryInvite.gameId], isNull);
      expect(gameModuleRoomInviteHandlers[legacyInvite.gameId], isNotNull);
    },
  );

  test(
    'accept response carries game identity for room/invite mismatch checks',
    () {
      final result = RoomInviteActionResult.fromJson({
        'status': 'accepted',
        'gameId': 'game.archery',
        'roomCode': 'ARCH7',
      });
      expect(result.gameId, 'game.archery');
    },
  );
}
