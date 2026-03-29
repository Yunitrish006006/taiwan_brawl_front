import '../models/admin_models.dart';
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
}
