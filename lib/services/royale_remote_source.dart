import 'dart:convert';

import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:taiwan_brawl_game_mini_royale/taiwan_brawl_game_mini_royale.dart';

import 'api_client.dart';
import 'room_socket_channel.dart';

typedef RoyaleRoomChannelFactory =
    WebSocketChannel Function(Uri uri, {Map<String, dynamic>? headers});

/// Application-facing room channel. The application service does not need to
/// depend on the WebSocket package or its sink lifecycle.
class RoyaleRoomChannel implements MiniRoyaleRoomConnection {
  RoyaleRoomChannel(this._channel);

  final WebSocketChannel _channel;

  @override
  Stream<Map<String, dynamic>> get messages => _channel.stream
      .map((raw) => jsonDecode(raw as String))
      .where((decoded) => decoded is Map<String, dynamic>)
      .cast<Map<String, dynamic>>();

  @override
  int? get closeCode => _channel.closeCode;
  @override
  String? get closeReason => _channel.closeReason;

  @override
  void send(Map<String, dynamic> message) =>
      _channel.sink.add(jsonEncode(message));

  @override
  Future<void> close([int? code, String? reason]) async {
    await _channel.sink.close(code, reason);
  }
}

abstract interface class RoyaleRemoteSource implements MiniRoyaleRemotePort {
  @override
  Future<RoyaleRoomChannel> connectToRoom(
    String roomCode,
    Map<String, Object> gameContract,
  );
}

class ServerRoyaleRemoteSource implements RoyaleRemoteSource {
  ServerRoyaleRemoteSource(
    this._apiClient, {
    RoyaleRoomChannelFactory? channelFactory,
  }) : _channelFactory = channelFactory ?? connectRoomSocket;

  final ApiClient _apiClient;
  final RoyaleRoomChannelFactory _channelFactory;

  Future<T> _request<T>(Future<T> Function() send) async {
    try {
      return await send();
    } on ApiException catch (error) {
      throw MiniRoyaleServiceException(
        error.message,
        statusCode: error.statusCode,
        responseBody: error.responseBody,
      );
    }
  }

  @override
  Future<Map<String, dynamic>> postRoomAction(
    String roomCode,
    String action,
    Map<String, dynamic> body,
  ) {
    return _request(
      () => _apiClient.postJson(
        '/api/games/mini-royale/v1/rooms/$roomCode/$action',
        body,
      ),
    );
  }

  @override
  Future<Map<String, dynamic>> fetchCards() =>
      _request(() => _apiClient.getJson('/api/games/mini-royale/v1/cards'));

  @override
  Future<Map<String, dynamic>> fetchHeroes() =>
      _request(() => _apiClient.getJson('/api/games/mini-royale/v1/heroes'));

  @override
  Future<Map<String, dynamic>> fetchProgression() => _request(
    () => _apiClient.getJson('/api/games/mini-royale/v1/progression'),
  );

  @override
  Future<Map<String, dynamic>> fetchDecks() =>
      _request(() => _apiClient.getJson('/api/games/mini-royale/v1/decks'));

  @override
  Future<Map<String, dynamic>> fetchDeckSummaries() => _request(
    () => _apiClient.getJson('/api/games/mini-royale/v1/decks?summary=1'),
  );

  @override
  Future<Map<String, dynamic>> saveDeck(Map<String, dynamic> payload) {
    return _request(
      () => _apiClient.postJson('/api/games/mini-royale/v1/decks', payload),
    );
  }

  @override
  Future<Map<String, dynamic>> selectDeckHero(Map<String, dynamic> payload) {
    return _request(
      () =>
          _apiClient.postJson('/api/games/mini-royale/v1/decks/hero', payload),
    );
  }

  @override
  Future<Map<String, dynamic>> createRoom(Map<String, dynamic> payload) {
    return _request(
      () => _apiClient.postJson('/api/games/mini-royale/v1/rooms', payload),
    );
  }

  @override
  Future<Map<String, dynamic>> fetchRoomState(String roomCode) {
    return _request(
      () =>
          _apiClient.getJson('/api/games/mini-royale/v1/rooms/$roomCode/state'),
    );
  }

  @override
  Future<Map<String, dynamic>> decideLlmBotAction(Map<String, dynamic> state) {
    return _request(
      () => _apiClient.postJson('/api/llm-bot/decide', {'state': state}),
    );
  }

  @override
  Future<RoyaleRoomChannel> connectToRoom(
    String roomCode,
    Map<String, Object> gameContract,
  ) async {
    final baseUri = Uri.parse(_apiClient.apiBaseUrl);
    final scheme = baseUri.scheme == 'https' ? 'wss' : 'ws';
    final uri = baseUri.replace(
      scheme: scheme,
      path: '/api/games/mini-royale/v1/rooms/$roomCode/ws',
      queryParameters: {'gameContract': jsonEncode(gameContract)},
    );
    final headers = await _apiClient.loadWebSocketHeaders();
    return RoyaleRoomChannel(_channelFactory(uri, headers: headers));
  }
}
