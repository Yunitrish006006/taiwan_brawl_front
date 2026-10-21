import 'api_client.dart';
import 'service_utils.dart';

abstract interface class AdminRemoteSource {
  Future<Map<String, dynamic>> searchUsers(String query);
  Future<Map<String, dynamic>> updateUserRole(int userId, String role);
  Future<Map<String, dynamic>> fetchCards();
  Future<Map<String, dynamic>> upsertCard(Map<String, dynamic> payload);
  Future<Map<String, dynamic>> uploadCardImage(
    String cardId,
    Map<String, dynamic> payload,
  );
  Future<Map<String, dynamic>> uploadCardCharacterImage(
    String cardId,
    String direction,
    Map<String, dynamic> payload,
  );
  Future<Map<String, dynamic>> deleteCardCharacterImage(
    String cardId,
    String direction,
  );
  Future<Map<String, dynamic>> uploadCardCharacterAsset(
    String cardId,
    String assetId,
    Map<String, dynamic> payload,
  );
  Future<Map<String, dynamic>> deleteCardCharacterAsset(
    String cardId,
    String assetId,
  );
  Future<Map<String, dynamic>> uploadCardBgImage(
    String cardId,
    Map<String, dynamic> payload,
  );
  Future<Map<String, dynamic>> deleteCardBgImage(String cardId);
  Future<Map<String, dynamic>> deleteCardImage(String cardId);
  Future<void> deleteCard(String cardId);
}

class ServerAdminRemoteSource implements AdminRemoteSource {
  const ServerAdminRemoteSource(this._apiClient);

  final ApiClient _apiClient;

  @override
  Future<Map<String, dynamic>> searchUsers(String query) {
    return _apiClient.getJson(
      buildApiPath('/api/admin/users', queryParameters: {'query': query}),
    );
  }

  @override
  Future<Map<String, dynamic>> updateUserRole(int userId, String role) {
    return _apiClient.putJson('/api/admin/users/$userId/role', {'role': role});
  }

  @override
  Future<Map<String, dynamic>> fetchCards() => _apiClient.getJson('/api/cards');

  @override
  Future<Map<String, dynamic>> upsertCard(Map<String, dynamic> payload) {
    return _apiClient.postJson('/api/admin/cards', payload);
  }

  @override
  Future<Map<String, dynamic>> uploadCardImage(
    String cardId,
    Map<String, dynamic> payload,
  ) {
    return _apiClient.postJson('/api/admin/cards/$cardId/image', payload);
  }

  @override
  Future<Map<String, dynamic>> uploadCardCharacterImage(
    String cardId,
    String direction,
    Map<String, dynamic> payload,
  ) {
    return _apiClient.postJson(
      '/api/admin/cards/$cardId/character-images/$direction',
      payload,
    );
  }

  @override
  Future<Map<String, dynamic>> deleteCardCharacterImage(
    String cardId,
    String direction,
  ) {
    return _apiClient.deleteJson(
      '/api/admin/cards/$cardId/character-images/$direction',
    );
  }

  @override
  Future<Map<String, dynamic>> uploadCardCharacterAsset(
    String cardId,
    String assetId,
    Map<String, dynamic> payload,
  ) {
    return _apiClient.postJson(
      '/api/admin/cards/$cardId/character-assets/$assetId',
      payload,
    );
  }

  @override
  Future<Map<String, dynamic>> deleteCardCharacterAsset(
    String cardId,
    String assetId,
  ) {
    return _apiClient.deleteJson(
      '/api/admin/cards/$cardId/character-assets/$assetId',
    );
  }

  @override
  Future<Map<String, dynamic>> uploadCardBgImage(
    String cardId,
    Map<String, dynamic> payload,
  ) {
    return _apiClient.postJson('/api/admin/cards/$cardId/bg-image', payload);
  }

  @override
  Future<Map<String, dynamic>> deleteCardBgImage(String cardId) {
    return _apiClient.deleteJson('/api/admin/cards/$cardId/bg-image');
  }

  @override
  Future<Map<String, dynamic>> deleteCardImage(String cardId) {
    return _apiClient.deleteJson('/api/admin/cards/$cardId/image');
  }

  @override
  Future<void> deleteCard(String cardId) async {
    await _apiClient.deleteJson('/api/admin/cards/$cardId');
  }
}
