abstract interface class MiniRoyaleRoomConnection {
  Stream<Map<String, dynamic>> get messages;
  int? get closeCode;
  String? get closeReason;
  void send(Map<String, dynamic> message);
  Future<void> close([int? code, String? reason]);
}

/// Transport-neutral API contract consumed by Mini Royale application logic.
abstract interface class MiniRoyaleRemotePort {
  Future<Map<String, dynamic>> postRoomAction(
    String roomCode,
    String action,
    Map<String, dynamic> body,
  );
  Future<Map<String, dynamic>> fetchCards();
  Future<Map<String, dynamic>> fetchHeroes();
  Future<Map<String, dynamic>> fetchProgression();
  Future<Map<String, dynamic>> fetchDecks();
  Future<Map<String, dynamic>> fetchDeckSummaries();
  Future<Map<String, dynamic>> saveDeck(Map<String, dynamic> payload);
  Future<Map<String, dynamic>> selectDeckHero(Map<String, dynamic> payload);
  Future<Map<String, dynamic>> createRoom(Map<String, dynamic> payload);
  Future<Map<String, dynamic>> fetchRoomState(String roomCode);
  Future<Map<String, dynamic>> decideLlmBotAction(Map<String, dynamic> state);
  Future<MiniRoyaleRoomConnection> connectToRoom(
    String roomCode,
    Map<String, Object> gameContract,
  );
}

/// Host-neutral error contract returned by the Mini Royale application API.
class MiniRoyaleServiceException implements Exception {
  const MiniRoyaleServiceException(
    this.message, {
    this.statusCode,
    this.responseBody,
  });

  final String message;
  final int? statusCode;
  final Map<String, dynamic>? responseBody;

  @override
  String toString() => message;
}
