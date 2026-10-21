import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:taiwan_brawl_game_mini_royale/taiwan_brawl_game_mini_royale.dart';

import '../../services/friends_service.dart';
import '../../services/game_library_controller.dart';
import '../../services/locale_provider.dart';
import '../../services/royale_service.dart';
import '../../services/api_client.dart';
import 'package:taiwan_brawl_game_mini_royale/mini_royale_arena_page.dart'
    deferred as royale_arena_lib;
import '../../models/friends_models.dart';
import 'arena_host_scope.dart';
import '../game_module_room_invite_handler.dart';

/// App-side adapter for the current Mini Royale room-invite contract.
/// Social UI calls this without knowing Royale decks, room APIs, or arena routes.
class MiniRoyaleRoomInviteHandler implements GameModuleRoomInviteHandler {
  const MiniRoyaleRoomInviteHandler();

  static const moduleId = miniRoyaleModuleId;

  @override
  String get gameId => moduleId;

  @override
  Future<void> accept(BuildContext context, RoomInviteItem invite) async {
    if (!context.read<GameLibraryController>().isModuleEnabled(moduleId)) {
      final navigator = Navigator.of(context);
      navigator.pop();
      navigator.pushNamed('/game-library');
      return;
    }

    final deck = await _pickDeck(context);
    if (deck == null || !context.mounted) return;

    final friends = context.read<FriendsService>();
    final royale = context.read<RoyaleService>();
    final accepted = await friends.acceptRoomInvite(invite.id);
    if (!context.mounted) return;
    if (accepted.gameId != gameId || invite.gameId != gameId) {
      throw ApiException('The invitation game does not match its room.');
    }
    final room = await royale.joinRoom(
      roomCode: accepted.roomCode,
      deckId: deck.id,
    );
    if (!context.mounted) return;

    await royale_arena_lib.loadLibrary();
    if (!context.mounted) return;
    final navigator = Navigator.of(context);
    navigator.pop();
    navigator.push(
      MaterialPageRoute(
        builder: (routeContext) => miniRoyaleArenaHostScope(
          hostContext: routeContext,
          child: royale_arena_lib.MiniRoyaleArenaPage(
            roomCode: room.code,
            onExitToHome: () => Navigator.of(
              routeContext,
            ).pushNamedAndRemoveUntil('/home', (_) => false),
          ),
        ),
      ),
    );
  }

  Future<RoyaleDeck?> _pickDeck(BuildContext context) async {
    final royale = context.read<RoyaleService>();
    final decks = await royale.fetchDeckSummaries();
    if (decks.isEmpty) {
      if (!context.mounted) return null;
      final message = context.read<LocaleProvider>().translation.text(
        'Please create a deck first',
      );
      throw ApiException(message);
    }
    if (decks.length == 1) return decks.first;

    var selected = decks.first;
    if (!context.mounted) return null;
    return showDialog<RoyaleDeck>(
      context: context,
      builder: (dialogContext) {
        final t = dialogContext.watch<LocaleProvider>().translation;
        final theme = Theme.of(dialogContext);
        final scheme = theme.colorScheme;
        return AlertDialog(
          title: Text(t.text('Choose a deck to battle with')),
          content: StatefulBuilder(
            builder: (context, setState) => DropdownButtonFormField<RoyaleDeck>(
              initialValue: selected,
              items: decks
                  .map(
                    (deck) =>
                        DropdownMenuItem(value: deck, child: Text(deck.name)),
                  )
                  .toList(),
              onChanged: (value) {
                if (value != null) setState(() => selected = value);
              },
              dropdownColor: scheme.surface,
              style: theme.textTheme.titleMedium?.copyWith(
                color: scheme.onSurface,
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text(t.text('Cancel')),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(selected),
              child: Text(t.text('Confirm')),
            ),
          ],
        );
      },
    );
  }
}
