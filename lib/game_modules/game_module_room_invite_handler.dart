import 'package:flutter/widgets.dart';

import '../models/friends_models.dart';

abstract interface class GameModuleRoomInviteHandler {
  String get gameId;

  Future<void> accept(BuildContext context, RoomInviteItem invite);
}
