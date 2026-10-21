import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:taiwan_brawl_game_mini_royale/taiwan_brawl_game_mini_royale.dart'
    show MiniRoyaleServiceException;
import 'package:taiwan_brawl_game_mini_royale/royale_lobby_page.dart';

import '../../services/api_client.dart';
import '../../services/auth_service.dart';
import '../../services/royale_service.dart';
import '../../game_modules/mini_royale/arena_host_scope.dart';
import 'package:taiwan_brawl_game_mini_royale/mini_royale_arena_page.dart'
    deferred as royale_arena_lib;

String miniRoyaleLobbyErrorMessage(Object error) {
  final String? message;
  final Map<String, dynamic>? responseBody;
  if (error is MiniRoyaleServiceException) {
    message = error.message;
    responseBody = error.responseBody;
  } else if (error is ApiException) {
    message = error.message;
    responseBody = error.responseBody;
  } else {
    return error.toString();
  }
  if (message == 'GAME_VERSION_INCOMPATIBLE') {
    final detail = responseBody?['detail'];
    if (detail is String && detail.isNotEmpty) return detail;
  }
  return message;
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
      errorMessage: miniRoyaleLobbyErrorMessage,
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
