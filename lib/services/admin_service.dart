import '../models/admin_models.dart';
import '../models/royale_models.dart';
import 'api_client.dart';

class AdminService {
  AdminService(this._apiClient);

  final ApiClient _apiClient;

  Future<List<ManageUser>> searchUsers(String query) async {
    final encodedQuery = Uri.encodeQueryComponent(query);
    final res = await _apiClient.getJson(
      '/api/admin/users?query=$encodedQuery',
    );
    return (res['users'] as List<dynamic>? ?? const [])
        .map((item) => ManageUser.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<ManageUser> updateUserRole(int userId, String role) async {
    final res = await _apiClient.putJson('/api/admin/users/$userId/role', {
      'role': role,
    });
    return ManageUser.fromJson(res['user'] as Map<String, dynamic>);
  }

  Future<List<RoyaleCard>> fetchCards() async {
    final res = await _apiClient.getJson('/api/cards');
    return (res['cards'] as List<dynamic>? ?? const [])
        .map((item) => RoyaleCard.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<RoyaleCard> upsertCard(Map<String, dynamic> payload) async {
    final res = await _apiClient.postJson('/api/admin/cards', payload);
    return RoyaleCard.fromJson(res['card'] as Map<String, dynamic>);
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
    return RoyaleCard.fromJson(res['card'] as Map<String, dynamic>);
  }

  Future<RoyaleCard?> deleteCardImage(String cardId) async {
    final res = await _apiClient.deleteJson('/api/admin/cards/$cardId/image');
    final card = res['card'];
    if (card is Map<String, dynamic>) {
      return RoyaleCard.fromJson(card);
    }
    return null;
  }

  Future<void> deleteCard(String cardId) async {
    await _apiClient.deleteJson('/api/admin/cards/$cardId');
  }
}
