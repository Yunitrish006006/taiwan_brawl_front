import 'package:taiwan_brawl_game_mini_royale/taiwan_brawl_game_mini_royale.dart';

import '../../services/game_resource_content_store.dart';

/// App adapter exposing the verified local content store through Mini Royale's
/// platform-neutral rules-source port.
class GameResourceMiniRoyaleGameplayRulesSource
    implements MiniRoyaleGameplayRulesSource {
  const GameResourceMiniRoyaleGameplayRulesSource({required this.contentStore});

  final GameResourceContentStore contentStore;

  @override
  Future<String?> readActiveVersion(String resourceId) =>
      contentStore.readActiveVersion(miniRoyaleModuleId, resourceId);

  @override
  Future<List<int>?> readActiveBytes(String resourceId) async =>
      contentStore.readActive(miniRoyaleModuleId, resourceId);
}
