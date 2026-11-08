import 'api_client.dart';

class ChatDeviceInfo {
  const ChatDeviceInfo({
    required this.deviceId,
    required this.createdAt,
    required this.lastSeenAt,
  });

  final String deviceId;
  final DateTime? createdAt;
  final DateTime? lastSeenAt;

  factory ChatDeviceInfo.fromJson(Map<String, dynamic> json) {
    final deviceId = json['device_id']?.toString().trim() ?? '';
    if (deviceId.isEmpty) throw const FormatException('Missing device_id');
    return ChatDeviceInfo(
      deviceId: deviceId,
      createdAt: DateTime.tryParse(json['created_at']?.toString() ?? ''),
      lastSeenAt: DateTime.tryParse(json['last_seen_at']?.toString() ?? ''),
    );
  }
}

abstract interface class ChatDeviceManagementService {
  Future<void> registerCurrentDevice(String deviceId);
  Future<List<ChatDeviceInfo>> loadActiveDevices();
  Future<void> revokeDevice(String deviceId);
}

class ServerChatDeviceManagementService implements ChatDeviceManagementService {
  const ServerChatDeviceManagementService(this._apiClient);

  final ApiClient _apiClient;

  @override
  Future<void> registerCurrentDevice(String deviceId) async {
    await _apiClient.postJson('/api/chat/dm/device-register', {
      'deviceId': deviceId,
    });
  }

  @override
  Future<List<ChatDeviceInfo>> loadActiveDevices() async {
    final response = await _apiClient.getJson('/api/chat/dm/devices');
    final rows = response['devices'];
    if (rows is! List) throw const FormatException('Invalid device list');
    return rows
        .whereType<Map>()
        .map((row) => ChatDeviceInfo.fromJson(Map<String, dynamic>.from(row)))
        .toList(growable: false);
  }

  @override
  Future<void> revokeDevice(String deviceId) async {
    await _apiClient.postJson('/api/chat/dm/device-revoke', {
      'deviceId': deviceId,
    });
  }
}
