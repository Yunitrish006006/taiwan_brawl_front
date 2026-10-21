import 'api_client.dart';

/// Returns the pending-row ids that were durably handled by the consumer.
typedef PendingNotificationHandler =
    Future<Iterable<int>> Function(Map<String, dynamic> item);

/// Application-facing source for background DM notifications.
abstract interface class PendingNotificationSource {
  Future<void> poll({
    required int selfId,
    required int? activeConversationUserId,
    required PendingNotificationHandler onItem,
  });

  void dispose();
}

/// Server adapter for the legacy pending relay.
///
/// HTTP, row parsing, and remote acknowledgement stay here. The notification
/// service only decides how an already fetched row affects local state.
class ServerPendingNotificationSource implements PendingNotificationSource {
  ServerPendingNotificationSource(this._apiClient);

  final ApiClient _apiClient;
  bool _disposed = false;

  @override
  Future<void> poll({
    required int selfId,
    required int? activeConversationUserId,
    required PendingNotificationHandler onItem,
  }) async {
    if (_disposed) return;
    final response = await _apiClient.getJson('/api/chat/dm/pending');
    final rawMessages = response['messages'];
    if (rawMessages is! List || rawMessages.isEmpty) return;

    final ackIds = <int>[];
    for (final rawItem in rawMessages) {
      if (rawItem is! Map) continue;
      final item = Map<String, dynamic>.from(rawItem);
      final senderId = _readInt(item['senderId'] ?? item['sender_id']);
      if (senderId == null || senderId == activeConversationUserId) continue;
      ackIds.addAll(await onItem(item));
    }

    if (ackIds.isNotEmpty && !_disposed) {
      await _apiClient.postJson('/api/chat/dm/ack', {
        'ids': ackIds.toSet().toList(),
      });
    }
  }

  @override
  void dispose() {
    _disposed = true;
  }

  static int? _readInt(Object? value) {
    if (value is num) return value.toInt();
    return int.tryParse('$value');
  }
}
