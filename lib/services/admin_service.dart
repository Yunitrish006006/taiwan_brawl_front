import '../models/admin_models.dart';
import 'package:taiwan_brawl_game_mini_royale/taiwan_brawl_game_mini_royale.dart';
import 'api_client.dart';
import 'admin_remote_source.dart';
import 'service_utils.dart';

class AdminService {
  AdminService(ApiClient apiClient, {AdminRemoteSource? remoteSource})
    : _remoteSource = remoteSource ?? ServerAdminRemoteSource(apiClient);

  final AdminRemoteSource _remoteSource;

  Future<List<ManageUser>> searchUsers(String query) async {
    final res = await _remoteSource.searchUsers(query);
    return jsonModelList(res, 'users', ManageUser.fromJson);
  }

  Future<ManageUser> updateUserRole(int userId, String role) async {
    final res = await _remoteSource.updateUserRole(userId, role);
    return jsonModel(res, 'user', ManageUser.fromJson);
  }

  Future<List<RoyaleCard>> fetchCards() async {
    final res = await _remoteSource.fetchCards();
    return jsonModelList(res, 'cards', RoyaleCard.fromJson);
  }

  Future<RoyaleCard> upsertCard(Map<String, dynamic> payload) async {
    final res = await _remoteSource.upsertCard(payload);
    return jsonModel(res, 'card', RoyaleCard.fromJson);
  }

  Future<RoyaleCard> uploadCardImage({
    required String cardId,
    required String bytesBase64,
    required String contentType,
    String? fileName,
  }) async {
    final res = await _remoteSource.uploadCardImage(cardId, {
      'bytesBase64': bytesBase64,
      'contentType': contentType,
      'fileName': fileName,
    });
    return jsonModel(res, 'card', RoyaleCard.fromJson);
  }

  Future<RoyaleCard> uploadCardCharacterImage({
    required String cardId,
    required String direction,
    required String bytesBase64,
    required String contentType,
    String? fileName,
  }) async {
    final res = await _remoteSource.uploadCardCharacterImage(
      cardId,
      direction,
      {
        'bytesBase64': bytesBase64,
        'contentType': contentType,
        'fileName': fileName,
      },
    );
    return jsonModel(res, 'card', RoyaleCard.fromJson);
  }

  Future<RoyaleCard?> deleteCardCharacterImage(
    String cardId, {
    required String direction,
  }) async {
    final res = await _remoteSource.deleteCardCharacterImage(cardId, direction);
    return jsonNullableModel(res, 'card', RoyaleCard.fromJson);
  }

  Future<RoyaleCard> uploadCardCharacterAsset({
    required String cardId,
    required String assetId,
    required String animation,
    required String direction,
    required int frameIndex,
    required int durationMs,
    required bool loop,
    required String bytesBase64,
    required String contentType,
    String? fileName,
  }) async {
    final res = await _remoteSource.uploadCardCharacterAsset(cardId, assetId, {
      'animation': animation,
      'direction': direction,
      'frameIndex': frameIndex,
      'durationMs': durationMs,
      'loop': loop,
      'bytesBase64': bytesBase64,
      'contentType': contentType,
      'fileName': fileName,
    });
    return jsonModel(res, 'card', RoyaleCard.fromJson);
  }

  Future<RoyaleCard?> deleteCardCharacterAsset({
    required String cardId,
    required String assetId,
  }) async {
    final res = await _remoteSource.deleteCardCharacterAsset(cardId, assetId);
    return jsonNullableModel(res, 'card', RoyaleCard.fromJson);
  }

  Future<RoyaleCard> uploadCardBgImage({
    required String cardId,
    required String bytesBase64,
    required String contentType,
    String? fileName,
  }) async {
    final res = await _remoteSource.uploadCardBgImage(cardId, {
      'bytesBase64': bytesBase64,
      'contentType': contentType,
      'fileName': fileName,
    });
    return jsonModel(res, 'card', RoyaleCard.fromJson);
  }

  Future<RoyaleCard?> deleteCardBgImage(String cardId) async {
    final res = await _remoteSource.deleteCardBgImage(cardId);
    return jsonNullableModel(res, 'card', RoyaleCard.fromJson);
  }

  Future<RoyaleCard?> deleteCardImage(String cardId) async {
    final res = await _remoteSource.deleteCardImage(cardId);
    return jsonNullableModel(res, 'card', RoyaleCard.fromJson);
  }

  Future<void> deleteCard(String cardId) async {
    await _remoteSource.deleteCard(cardId);
  }
}
