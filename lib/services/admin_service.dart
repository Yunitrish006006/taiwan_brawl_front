import '../models/admin_models.dart';
import '../models/royale_models.dart';
import 'api_client.dart';
import 'service_utils.dart';

class AdminService {
  AdminService(this._apiClient);

  final ApiClient _apiClient;

  Future<List<ManageUser>> searchUsers(String query) async {
    final res = await _apiClient.getJson(
      buildApiPath('/api/admin/users', queryParameters: {'query': query}),
    );
    return jsonModelList(res, 'users', ManageUser.fromJson);
  }

  Future<ManageUser> updateUserRole(int userId, String role) async {
    final res = await _apiClient.putJson('/api/admin/users/$userId/role', {
      'role': role,
    });
    return jsonModel(res, 'user', ManageUser.fromJson);
  }

  Future<List<RoyaleCard>> fetchCards() async {
    final res = await _apiClient.getJson('/api/cards');
    return jsonModelList(res, 'cards', RoyaleCard.fromJson);
  }

  Future<RoyaleCard> upsertCard(Map<String, dynamic> payload) async {
    final res = await _apiClient.postJson('/api/admin/cards', payload);
    return jsonModel(res, 'card', RoyaleCard.fromJson);
  }

  Future<RoyaleCard> uploadCardImage({
    required String cardId,
    required String bytesBase64,
    required String contentType,
    String? fileName,
  }) async {
    final res = await _apiClient.postJson('/api/admin/cards/$cardId/image', {
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
    final res = await _apiClient.postJson(
      '/api/admin/cards/$cardId/character-images/$direction',
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
    final res = await _apiClient.deleteJson(
      '/api/admin/cards/$cardId/character-images/$direction',
    );
    return jsonNullableModel(res, 'card', RoyaleCard.fromJson);
  }

  Future<RoyaleCard> uploadCardBgImage({
    required String cardId,
    required String bytesBase64,
    required String contentType,
    String? fileName,
  }) async {
    final res = await _apiClient.postJson('/api/admin/cards/$cardId/bg-image', {
      'bytesBase64': bytesBase64,
      'contentType': contentType,
      'fileName': fileName,
    });
    return jsonModel(res, 'card', RoyaleCard.fromJson);
  }

  Future<RoyaleCard?> deleteCardBgImage(String cardId) async {
    final res = await _apiClient.deleteJson(
      '/api/admin/cards/$cardId/bg-image',
    );
    return jsonNullableModel(res, 'card', RoyaleCard.fromJson);
  }

  Future<RoyaleCard?> deleteCardImage(String cardId) async {
    final res = await _apiClient.deleteJson('/api/admin/cards/$cardId/image');
    return jsonNullableModel(res, 'card', RoyaleCard.fromJson);
  }

  Future<void> deleteCard(String cardId) async {
    await _apiClient.deleteJson('/api/admin/cards/$cardId');
  }
}
