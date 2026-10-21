import 'mini_royale_module.dart';
import 'mini_royale_remote_port.dart';
import 'royale_models.dart';

class MiniRoyaleService {
  MiniRoyaleService({
    required this.remotePort,
    required this.apiBaseUrl,
    Map<String, Object> Function()? gameContractProvider,
  }) : _gameContractProvider = gameContractProvider;

  final MiniRoyaleRemotePort remotePort;
  final String apiBaseUrl;
  final Map<String, Object> Function()? _gameContractProvider;

  Map<String, Object> get _gameContract =>
      Map.unmodifiable(_gameContractProvider?.call() ?? miniRoyaleGameContract);

  Map<String, Object> get gameContract => _gameContract;

  Map<String, dynamic> _requiredMap(Map<String, dynamic> json, String key) =>
      json[key] as Map<String, dynamic>;

  List<T> _modelList<T>(
    Map<String, dynamic> json,
    String key,
    T Function(Map<String, dynamic>) fromJson,
  ) => (json[key] as List<dynamic>? ?? const <dynamic>[])
      .map((item) => fromJson(item as Map<String, dynamic>))
      .toList();

  T _model<T>(
    Map<String, dynamic> json,
    String key,
    T Function(Map<String, dynamic>) fromJson,
  ) => fromJson(_requiredMap(json, key));

  RoyaleRoomSnapshot _roomFromResponse(Map<String, dynamic> response) => _model(
    response,
    'room',
    (json) => RoyaleRoomSnapshot.fromJson(json, apiBaseUrl: apiBaseUrl),
  );

  Future<RoyaleRoomSnapshot> _postRoomAction(
    String roomCode,
    String action,
    Map<String, dynamic> body,
  ) async => _roomFromResponse(
    await remotePort.postRoomAction(roomCode, action, body),
  );

  Future<List<RoyaleCard>> fetchCards() async => _modelList(
    await remotePort.fetchCards(),
    'cards',
    (json) => RoyaleCard.fromJson(json, apiBaseUrl: apiBaseUrl),
  );

  Future<List<RoyaleHero>> fetchHeroes() async =>
      _modelList(await remotePort.fetchHeroes(), 'heroes', RoyaleHero.fromJson);

  Future<RoyaleProgressionOverview> fetchProgression() async =>
      RoyaleProgressionOverview.fromJson(await remotePort.fetchProgression());

  Future<List<RoyaleDeck>> fetchDecks() async => _modelList(
    await remotePort.fetchDecks(),
    'decks',
    (json) => RoyaleDeck.fromJson(json, apiBaseUrl: apiBaseUrl),
  );

  Future<List<RoyaleDeck>> fetchDeckSummaries() async => _modelList(
    await remotePort.fetchDeckSummaries(),
    'decks',
    (json) => RoyaleDeck.fromJson(json, apiBaseUrl: apiBaseUrl),
  );

  Future<RoyaleDeck> saveDeck({
    required String name,
    required int slot,
    required List<String> cardIds,
    String? heroId,
  }) async => _model(
    await remotePort.saveDeck({
      'name': name,
      'slot': slot,
      'cardIds': cardIds,
      'heroId': ?heroId,
    }),
    'deck',
    (json) => RoyaleDeck.fromJson(json, apiBaseUrl: apiBaseUrl),
  );

  Future<RoyaleDeckProgression> selectDeckHero({
    required int deckId,
    required String heroId,
  }) async => _model(
    await remotePort.selectDeckHero({'deckId': deckId, 'heroId': heroId}),
    'progression',
    RoyaleDeckProgression.fromJson,
  );

  Future<RoyaleRoomSnapshot> createRoom({
    required int deckId,
    String heroId = 'ordinary_person',
    bool vsBot = false,
    String botController = 'heuristic',
    String simulationMode = 'server',
  }) async {
    final response = await remotePort.createRoom({
      'deckId': deckId,
      'heroId': heroId,
      'vsBot': vsBot,
      'botController': vsBot ? botController : null,
      'simulationMode': vsBot ? 'host' : simulationMode,
      'gameContract': _gameContract,
    });
    return _roomFromResponse(response);
  }

  Future<RoyaleRoomSnapshot> joinRoom({
    required String roomCode,
    required int deckId,
    String heroId = 'ordinary_person',
  }) => _postRoomAction(roomCode, 'join', {
    'deckId': deckId,
    'heroId': heroId,
    'gameContract': _gameContract,
  });

  Future<RoyaleRoomSnapshot> readyRoom(String roomCode) =>
      _postRoomAction(roomCode, 'ready', {});

  Future<RoyaleRoomSnapshot> rematchRoom(String roomCode) =>
      _postRoomAction(roomCode, 'rematch', {});

  Future<RoyaleRoomSnapshot> hostFinishRoom({
    required String roomCode,
    required String? winnerSide,
    required String reason,
    required int leftTowerHp,
    required int rightTowerHp,
  }) => _postRoomAction(roomCode, 'host-finish', {
    'winnerSide': winnerSide,
    'reason': reason,
    'leftTowerHp': leftTowerHp,
    'rightTowerHp': rightTowerHp,
  });

  Future<RoyaleRoomSnapshot> fetchRoomState(String roomCode) async =>
      _roomFromResponse(await remotePort.fetchRoomState(roomCode));

  Future<RoyaleLlmBotAction> decideLlmBotAction(
    Map<String, dynamic> state,
  ) async =>
      RoyaleLlmBotAction.fromJson(await remotePort.decideLlmBotAction(state));

  Future<MiniRoyaleRoomConnection> connectToRoom(String roomCode) =>
      remotePort.connectToRoom(roomCode, _gameContract);
}
