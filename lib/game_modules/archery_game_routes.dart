import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';
import 'package:taiwan_brawl_game_archery/archery_game_module.dart'
    as archery_module;
import 'package:taiwan_brawl_game_archery/archery_game_page.dart'
    deferred as archery_page;

import '../services/auth_service.dart';
import '../services/game_library_controller.dart';
import '../services/game_resource_library_service.dart';
import '../pages/game/game_library_page.dart';
import 'archery_hive_progress_backend.dart';
import 'archery_rules_resource_source.dart';
import 'deferred_game_module_page.dart';

const archeryGameModuleRouteBuilders = <String, WidgetBuilder>{
  '/archery': _archeryRoute,
};

Widget _archeryRoute(BuildContext context) {
  if (!context.read<GameLibraryController>().isModuleEnabled('game.archery')) {
    return const GameLibraryPage();
  }
  return DeferredGameModulePage(
    loadLibrary: archery_page.loadLibrary,
    builder: (pageContext) => archery_page.ArcheryGamePage(
      profileId: pageContext.read<AuthService>().user?.id.toString(),
      rulesContentSource: GameResourceArcheryRulesSource(
        contentStore: pageContext
            .read<GameResourceLibraryService>()
            .contentStore,
      ),
      progressRepository: archery_module.ArcheryPlayerDataRepository(
        backend: HiveArcheryPlayerDataBackend(),
      ),
    ),
  );
}
