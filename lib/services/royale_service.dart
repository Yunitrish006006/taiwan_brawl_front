import 'package:web_socket_channel/web_socket_channel.dart';

import '../constants/app_constants.dart';
import '../models/royale_models.dart';
import 'api_client.dart';
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

  Future<List<RoyaleDeck>> fetchDecks() async {
    final res = await _apiClient.getJson('/api/decks');
    return jsonModelList(res, 'decks', RoyaleDeck.fromJson);
  }

  Future<RoyaleDeck> saveDeck({
    required String name,
    required int slot,
    required List<String> cardIds,
  }) async {
    final res = await _apiClient.postJson('/api/decks', {
      'name': name,
      'slot': slot,
      'cardIds': cardIds,
    });
    return jsonModel(res, 'deck', RoyaleDeck.fromJson);
  }

  Future<RoyaleRoomSnapshot> createRoom({
    required int deckId,
    bool vsBot = false,
    String simulationMode = 'server',
  }) async {
    final res = await _apiClient.postJson('/api/rooms', {
      'deckId': deckId,
      'vsBot': vsBot,
      'simulationMode': simulationMode,
    });
    return _roomFromResponse(res);
  }

  Future<RoyaleRoomSnapshot> joinRoom({
    required String roomCode,
    required int deckId,
  }) async {
    return _postRoomAction(roomCode, 'join', {'deckId': deckId});
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

  WebSocketChannel connectToRoom(String roomCode) {
    final baseUri = Uri.parse(AppConstants.apiBaseUrl);
    final scheme = baseUri.scheme == 'https' ? 'wss' : 'ws';
    final uri = baseUri.replace(
      scheme: scheme,
      path: '/api/rooms/$roomCode/ws',
      query: '',
    );
    return WebSocketChannel.connect(uri);
  }
}
