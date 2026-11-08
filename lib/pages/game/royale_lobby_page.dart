import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:taiwan_brawl_game_mini_royale/taiwan_brawl_game_mini_royale.dart'
    show MiniRoyaleServiceException;
import 'package:taiwan_brawl_game_mini_royale/royale_lobby_page.dart';

import '../../services/api_client.dart';
import '../../services/auth_service.dart';
import '../../services/locale_provider.dart';
import '../../services/royale_service.dart';
import '../../game_modules/mini_royale/arena_host_scope.dart';
import 'package:taiwan_brawl_game_mini_royale/mini_royale_arena_page.dart'
    deferred as royale_arena_lib;

String miniRoyaleLobbyErrorMessage(
  Object error, {
  String incompatibleMessage =
      'This game version is incompatible with the room. Update the game and try again.',
}) {
  final String? message;
  if (error is MiniRoyaleServiceException) {
    message = error.message;
  } else if (error is ApiException) {
    message = error.message;
  } else {
    return error.toString();
  }
  if (message == 'GAME_VERSION_INCOMPATIBLE') {
    return incompatibleMessage;
  }
  return message;
}

bool miniRoyaleLobbyRequiresGameUpdate(Object error) {
  if (error is MiniRoyaleServiceException) {
    return error.message == 'GAME_VERSION_INCOMPATIBLE';
  }
  return error is ApiException && error.message == 'GAME_VERSION_INCOMPATIBLE';
}

/// Shell adapter: supplies account capability and keeps arena navigation in
/// the App, while the lobby UI and state belong to the Mini Royale package.
class RoyaleLobbyPage extends StatelessWidget {
  const RoyaleLobbyPage({
    super.key,
    this.initialRoomCode,
    this.initialHeroId,
    this.initialHeroName,
    this.service,
  });

  final String? initialRoomCode;
  final String? initialHeroId;
  final String? initialHeroName;
  final RoyaleService? service;

  @override
  Widget build(BuildContext context) {
    final llmBotConfigured =
        context.watch<AuthService>().user?.hasLlmApiKey ?? false;
    return MiniRoyaleLobbyPage(
      initialRoomCode: initialRoomCode,
      initialHeroId: initialHeroId,
      initialHeroName: initialHeroName,
      service: service,
      llmBotConfigured: llmBotConfigured,
      errorMessage: (error) => miniRoyaleLobbyErrorMessage(
        error,
        incompatibleMessage: context.read<LocaleProvider>().translation.text(
          'This game version is incompatible with the room. Update the game and try again.',
        ),
      ),
      requiresGameUpdate: miniRoyaleLobbyRequiresGameUpdate,
      onOpenGameLibrary: () {
        Navigator.of(context).pushNamed('/game-library');
      },
      onOpenRoom: (roomCode) async {
        await royale_arena_lib.loadLibrary();
        if (!context.mounted) return;
        await Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (routeContext) => miniRoyaleArenaHostScope(
              hostContext: routeContext,
              service: service,
              child: royale_arena_lib.MiniRoyaleArenaPage(
                roomCode: roomCode,
                onExitToHome: () => Navigator.of(
                  routeContext,
                ).pushNamedAndRemoveUntil('/home', (_) => false),
              ),
            ),
          ),
        );
      },
    );
  }
}
