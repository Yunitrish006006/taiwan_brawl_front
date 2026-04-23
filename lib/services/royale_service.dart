import 'package:web_socket_channel/web_socket_channel.dart';

import '../constants/app_constants.dart';
import '../models/royale_models.dart';
import 'api_client.dart';
import 'room_socket_channel.dart';
import 'service_utils.dart';

class RoyaleService {
  RoyaleService(this._apiClient);

  final ApiClient _apiClient;

  RoyaleRoomSnapshot _roomFromResponse(Map<String, dynamic> response) {
    return jsonModel(response, 'room', RoyaleRoomSnapshot.fromJson);
  }

  Future<RoyaleRoomSnapshot> _postRoomAction(
    String roomCode,
    String action,
    Map<String, dynamic> body,
  ) async {
    final res = await _apiClient.postJson('/api/rooms/$roomCode/$action', body);
    return _roomFromResponse(res);
  }

  Future<List<RoyaleCard>> fetchCards() async {
    final res = await _apiClient.getJson('/api/cards');
    return jsonModelList(res, 'cards', RoyaleCard.fromJson);
  }

  Future<List<RoyaleHero>> fetchHeroes() async {
    final res = await _apiClient.getJson('/api/heroes');
    return jsonModelList(res, 'heroes', RoyaleHero.fromJson);
  }

  Future<RoyaleProgressionOverview> fetchProgression() async {
    final res = await _apiClient.getJson('/api/progression');
    return RoyaleProgressionOverview.fromJson(res);
  }

  Future<List<RoyaleDeck>> fetchDecks() async {
    final res = await _apiClient.getJson('/api/decks');
    return jsonModelList(res, 'decks', RoyaleDeck.fromJson);
  }

  Future<RoyaleDeck> saveDeck({
    required String name,
    required int slot,
    required List<String> cardIds,
    String? heroId,
  }) async {
    final res = await _apiClient.postJson('/api/decks', {
      'name': name,
      'slot': slot,
      'cardIds': cardIds,
      'heroId': ?heroId,
    });
    return jsonModel(res, 'deck', RoyaleDeck.fromJson);
  }

  Future<RoyaleDeckProgression> selectDeckHero({
    required int deckId,
    required String heroId,
  }) async {
    final res = await _apiClient.postJson('/api/decks/hero', {
      'deckId': deckId,
      'heroId': heroId,
    });
    return jsonModel(res, 'progression', RoyaleDeckProgression.fromJson);
  }

  Future<RoyaleRoomSnapshot> createRoom({
    required int deckId,
    String heroId = 'ordinary_person',
    bool vsBot = false,
    String botController = 'heuristic',
    String simulationMode = 'server',
  }) async {
    final effectiveSimulationMode = vsBot ? 'host' : simulationMode;
    final res = await _apiClient.postJson('/api/rooms', {
      'deckId': deckId,
      'heroId': heroId,
      'vsBot': vsBot,
      'botController': vsBot ? botController : null,
      'simulationMode': effectiveSimulationMode,
    });
    return _roomFromResponse(res);
  }

  Future<RoyaleRoomSnapshot> joinRoom({
    required String roomCode,
    required int deckId,
    String heroId = 'ordinary_person',
  }) async {
    return _postRoomAction(roomCode, 'join', {
      'deckId': deckId,
      'heroId': heroId,
    });
  }

  Future<RoyaleRoomSnapshot> readyRoom(String roomCode) async {
    return _postRoomAction(roomCode, 'ready', {});
  }

  Future<RoyaleRoomSnapshot> rematchRoom(String roomCode) async {
    return _postRoomAction(roomCode, 'rematch', {});
  }

  Future<RoyaleRoomSnapshot> hostFinishRoom({
    required String roomCode,
    required String? winnerSide,
    required String reason,
    required int leftTowerHp,
    required int rightTowerHp,
  }) async {
    return _postRoomAction(roomCode, 'host-finish', {
      'winnerSide': winnerSide,
      'reason': reason,
      'leftTowerHp': leftTowerHp,
      'rightTowerHp': rightTowerHp,
    });
  }

  Future<RoyaleRoomSnapshot> fetchRoomState(String roomCode) async {
    final res = await _apiClient.getJson('/api/rooms/$roomCode/state');
    return _roomFromResponse(res);
  }

  Future<RoyaleLlmBotAction> decideLlmBotAction(
    Map<String, dynamic> state,
  ) async {
    final res = await _apiClient.postJson('/api/llm-bot/decide', {
      'state': state,
    });
    return RoyaleLlmBotAction.fromJson(res);
  }

  WebSocketChannel connectToRoom(String roomCode) {
    final baseUri = Uri.parse(AppConstants.apiBaseUrl);
    final scheme = baseUri.scheme == 'https' ? 'wss' : 'ws';
    final uri = baseUri.replace(
      scheme: scheme,
      path: '/api/rooms/$roomCode/ws',
      query: '',
    );
    return connectRoomSocket(uri, headers: _apiClient.webSocketHeaders());
  }
}
