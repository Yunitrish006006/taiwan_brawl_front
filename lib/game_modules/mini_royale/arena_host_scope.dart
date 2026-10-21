import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';
import 'package:taiwan_brawl_game_mini_royale/taiwan_brawl_game_mini_royale.dart';

import '../../services/auth_service.dart';
import '../../services/friends_overview_sync_service.dart';
import '../../services/friends_service.dart';
import '../../services/game_resource_library_service.dart';
import '../../services/locale_provider.dart';
import '../../services/royale_service.dart';
import 'arena_localization_adapter.dart';
import 'arena_presentation_source.dart';
import 'arena_social_adapter.dart';
import 'gameplay_rules_source.dart';

/// Composes the game-owned arena contracts with this App's platform services.
Widget miniRoyaleArenaHostScope({
  required BuildContext hostContext,
  required Widget child,
  MiniRoyaleService? service,
}) {
  final contentStore = hostContext
      .read<GameResourceLibraryService>()
      .contentStore;
  final gameService = service ?? hostContext.read<RoyaleService>();

  return MultiProvider(
    providers: [
      Provider<MiniRoyaleService>.value(value: gameService),
      Provider<MiniRoyaleArenaPresentationSource>.value(
        value: GameResourceMiniRoyaleArenaPresentationSource(
          contentStore: contentStore,
        ),
      ),
      Provider<MiniRoyaleGameplayRulesSource>.value(
        value: GameResourceMiniRoyaleGameplayRulesSource(
          contentStore: contentStore,
        ),
      ),
      ChangeNotifierProvider<MiniRoyaleArenaSocialPort>(
        create: (_) => GameMiniRoyaleArenaSocialAdapter(
          friendsService: hostContext.read<FriendsService>(),
          overviewSync: hostContext.read<FriendsOverviewSyncService>(),
          authService: hostContext.read<AuthService>(),
        ),
      ),
      ChangeNotifierProvider<MiniRoyaleLocalizationPort>(
        create: (_) => GameMiniRoyaleLocalizationAdapter(
          hostContext.read<LocaleProvider>(),
        ),
      ),
    ],
    child: child,
  );
}
