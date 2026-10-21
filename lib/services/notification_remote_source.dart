import 'api_client.dart';

abstract interface class NotificationRemoteSource {
  Future<Map<String, dynamic>> loadConfiguration();

  Future<void> registerDevice(Map<String, dynamic> payload);

  Future<void> unregisterDevice(Map<String, dynamic> payload);
}

class ServerNotificationRemoteSource implements NotificationRemoteSource {
  const ServerNotificationRemoteSource(this._apiClient);

  final ApiClient _apiClient;

  @override
  Future<Map<String, dynamic>> loadConfiguration() {
    return _apiClient.getJson('/api/notifications/config');
  }

  @override
  Future<void> registerDevice(Map<String, dynamic> payload) async {
    await _apiClient.postJson('/api/notifications/register', payload);
  }

  @override
  Future<void> unregisterDevice(Map<String, dynamic> payload) async {
    await _apiClient.postJson('/api/notifications/unregister', payload);
  }
}
