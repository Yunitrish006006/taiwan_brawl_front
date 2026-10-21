import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:taiwan_brawl_game_mini_royale/taiwan_brawl_game_mini_royale.dart';
import 'package:taiwan_brawl/pages/game/royale_lobby_page.dart';
import 'package:taiwan_brawl/services/api_client.dart';
import 'package:taiwan_brawl/services/auth_service.dart';
import 'package:taiwan_brawl/services/locale_provider.dart';
import 'package:taiwan_brawl/services/royale_service.dart';

class _CaptureCreateRoomService extends RoyaleService {
  _CaptureCreateRoomService() : super(ApiClient());

  bool? capturedVsBot;
  String? capturedBotController;
  String? capturedSimulationMode;
  int? capturedDeckId;
  String? capturedHeroId;

  @override
  Future<List<RoyaleDeck>> fetchDeckSummaries() async {
    return [
      RoyaleDeck(
        id: 1,
        slot: 1,
        name: 'Test Deck',
        updatedAt: '2026-04-22T00:00:00Z',
        cardCount: 1,
        cards: const [
          RoyaleCard(
            id: 'card_1',
            name: 'Card 1',
            nameZhHant: '卡片 1',
            nameEn: 'Card 1',
            nameJa: 'カード 1',
            imageUrl: null,
            bgImageUrl: null,
            characterImageUrl: null,
            type: 'melee',
            imageVersion: 0,
            energyCost: 1,
            energyCostType: 'physical',
            hp: 100,
            damage: 10,
            attackRange: 60,
            bodyRadius: 20,
            moveSpeed: 100,
            attackSpeed: 1,
            spawnCount: 1,
            spellRadius: 0,
            spellDamage: 0,
            targetRule: 'ground',
            effectKind: 'none',
            effectValue: 0,
            characterFrontImageUrl: null,
            characterBackImageUrl: null,
            characterLeftImageUrl: null,
            characterRightImageUrl: null,
            characterAssets: [],
          ),
        ],
      ),
    ];
  }

  @override
  Future<RoyaleRoomSnapshot> createRoom({
    required int deckId,
    String heroId = 'ordinary_person',
    bool vsBot = false,
    String botController = 'heuristic',
    String simulationMode = 'server',
  }) async {
    capturedDeckId = deckId;
    capturedHeroId = heroId;
    capturedVsBot = vsBot;
    capturedBotController = botController;
    capturedSimulationMode = simulationMode;
    throw ApiException('test stop');
  }
}

void main() {
  test('shows the server remedy for unsupported gameplay content', () {
    final error = ApiException(
      'GAME_VERSION_INCOMPATIBLE',
      statusCode: 409,
      responseBody: {
        'error': 'GAME_VERSION_INCOMPATIBLE',
        'detail': 'Remove gameplay packs or update the server.',
      },
    );

    expect(
      miniRoyaleLobbyErrorMessage(error),
      'Remove gameplay packs or update the server.',
    );
  });

  test('shows a package-owned compatibility error from the host adapter', () {
    const error = MiniRoyaleServiceException(
      'GAME_VERSION_INCOMPATIBLE',
      statusCode: 409,
      responseBody: {
        'error': 'GAME_VERSION_INCOMPATIBLE',
        'detail': 'Install the room-required gameplay version.',
      },
    );

    expect(
      miniRoyaleLobbyErrorMessage(error),
      'Install the room-required gameplay version.',
    );
  });

  testWidgets('Create Bot Match sends vsBot=true', (tester) async {
    final localeProvider = LocaleProvider(
      defaultLocale: 'zh-Hant',
      translationResolver: (_) => <String, String>{},
    );
    final authService = AuthService(ApiClient());
    final service = _CaptureCreateRoomService();

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<LocaleProvider>.value(value: localeProvider),
          ChangeNotifierProvider<AuthService>.value(value: authService),
        ],
        child: MaterialApp(home: RoyaleLobbyPage(service: service)),
      ),
    );

    await tester.pumpAndSettle();

    final createBotButton = find.widgetWithText(
      FilledButton,
      'Create Bot Match',
    );
    await tester.ensureVisible(createBotButton);
    await tester.pumpAndSettle();
    await tester.tap(createBotButton);
    await tester.pump();

    expect(service.capturedVsBot, isTrue);
    expect(service.capturedDeckId, 1);
    expect(service.capturedBotController, 'heuristic');
    expect(service.capturedSimulationMode, 'host');
  });
}
