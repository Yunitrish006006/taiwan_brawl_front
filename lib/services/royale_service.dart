import 'package:web_socket_channel/web_socket_channel.dart';

import '../constants/app_constants.dart';
import '../models/royale_models.dart';
import 'api_client.dart';

class RoyaleService {
  RoyaleService(this._apiClient);

  final ApiClient _apiClient;

  Future<List<RoyaleCard>> fetchCards() async {
    final res = await _apiClient.getJson('/api/cards');
    return (res['cards'] as List<dynamic>)
        .map((card) => RoyaleCard.fromJson(card as Map<String, dynamic>))
        .toList();
  }

  Future<List<RoyaleDeck>> fetchDecks() async {
    final res = await _apiClient.getJson('/api/decks');
    return (res['decks'] as List<dynamic>)
        .map((deck) => RoyaleDeck.fromJson(deck as Map<String, dynamic>))
        .toList();
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
    return RoyaleDeck.fromJson(res['deck'] as Map<String, dynamic>);
  }

  Future<RoyaleRoomSnapshot> createRoom({
    required int deckId,
    bool vsBot = false,
  }) async {
    final res = await _apiClient.postJson('/api/rooms', {
      'deckId': deckId,
      'vsBot': vsBot,
    });
    return RoyaleRoomSnapshot.fromJson(res['room'] as Map<String, dynamic>);
  }

  Future<RoyaleRoomSnapshot> joinRoom({
    required String roomCode,
    required int deckId,
  }) async {
    final res = await _apiClient.postJson('/api/rooms/$roomCode/join', {
      'deckId': deckId,
    });
    return RoyaleRoomSnapshot.fromJson(res['room'] as Map<String, dynamic>);
  }

  Future<RoyaleRoomSnapshot> readyRoom(String roomCode) async {
    final res = await _apiClient.postJson('/api/rooms/$roomCode/ready', {});
    return RoyaleRoomSnapshot.fromJson(res['room'] as Map<String, dynamic>);
  }

  Future<RoyaleRoomSnapshot> rematchRoom(String roomCode) async {
    final res = await _apiClient.postJson('/api/rooms/$roomCode/rematch', {});
    return RoyaleRoomSnapshot.fromJson(res['room'] as Map<String, dynamic>);
  }

  Future<RoyaleRoomSnapshot> fetchRoomState(String roomCode) async {
    final res = await _apiClient.getJson('/api/rooms/$roomCode/state');
    return RoyaleRoomSnapshot.fromJson(res['room'] as Map<String, dynamic>);
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
