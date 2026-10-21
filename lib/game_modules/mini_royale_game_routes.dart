import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:taiwan_brawl_game_mini_royale/royale_deck_page.dart'
    deferred as royale_deck_page;
import 'package:taiwan_brawl_game_mini_royale/taiwan_brawl_game_mini_royale.dart'
    as mini_royale;

import '../pages/game/game_library_page.dart';
import '../pages/game/royale_lobby_page.dart' deferred as royale_lobby_page;
import '../services/auth_service.dart';
import '../services/game_library_controller.dart';
import 'mini_royale_platform_adapters.dart';
import 'deferred_game_module_page.dart';

const miniRoyaleGameModuleRouteBuilders = <String, WidgetBuilder>{
  '/royale-deck': _royaleDeckRoute,
  '/royale-lobby': _royaleLobbyRoute,
};

Widget _royaleDeckRoute(BuildContext context) {
  if (!context.read<GameLibraryController>().isModuleEnabled(
    'game.mini-royale',
  )) {
    return const GameLibraryPage();
  }
  return Provider<mini_royale.MiniRoyalePlayerDataRepository>(
    create: (_) => mini_royale.MiniRoyalePlayerDataRepository(
      backend: HiveMiniRoyalePlayerDataBackend(),
    ),
    child: DeferredGameModulePage(
      loadLibrary: royale_deck_page.loadLibrary,
      builder: (pageContext) => royale_deck_page.RoyaleDeckPage(
        profileId: pageContext.read<AuthService>().user?.id.toString(),
      ),
    ),
  );
}

Widget _royaleLobbyRoute(BuildContext context) {
  if (!context.read<GameLibraryController>().isModuleEnabled(
    'game.mini-royale',
  )) {
    return const GameLibraryPage();
  }
  return DeferredGameModulePage(
    loadLibrary: royale_lobby_page.loadLibrary,
    builder: (pageContext) {
      final args =
          ModalRoute.of(pageContext)?.settings.arguments
              as Map<String, dynamic>?;
      return royale_lobby_page.RoyaleLobbyPage(
        initialHeroId: args?['heroId'] as String?,
        initialHeroName: args?['heroName'] as String?,
      );
    },
  );
}
