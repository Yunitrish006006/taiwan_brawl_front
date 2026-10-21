import 'dart:convert';

import 'package:taiwan_brawl_game_mini_royale/taiwan_brawl_game_mini_royale.dart';

import '../../services/game_resource_content_store.dart';

/// App adapter exposing only the currently activated, verified arena pack.
class GameResourceMiniRoyaleArenaPresentationSource
    implements MiniRoyaleArenaPresentationSource {
  const GameResourceMiniRoyaleArenaPresentationSource({
    required this.contentStore,
  });

  final GameResourceContentStore contentStore;

  @override
  Future<String?> readActivePresentationJson() async {
    final bytes = await contentStore.readActive(
      miniRoyaleModuleId,
      miniRoyaleArenaPresentationResourceId,
    );
    return bytes == null ? null : utf8.decode(bytes);
  }
}
