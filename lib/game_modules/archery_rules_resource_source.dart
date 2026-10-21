import 'dart:convert';

import 'package:taiwan_brawl_game_archery/archery_game_module.dart';

import '../services/game_resource_content_store.dart';

/// App adapter that exposes the verified active Archery rules pack to its game.
class GameResourceArcheryRulesSource implements ArcheryRulesContentSource {
  const GameResourceArcheryRulesSource({required this.contentStore});

  final GameResourceContentStore contentStore;

  @override
  Future<String?> readActiveRulesJson() async {
    final bytes = await contentStore.readActive(
      archeryGameModuleId,
      archeryRulesResourceId,
    );
    return bytes == null ? null : utf8.decode(bytes);
  }
}
