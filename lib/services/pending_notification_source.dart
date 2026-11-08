import 'package:taiwan_brawl_messaging/taiwan_brawl_messaging.dart';

import 'api_client.dart';
import 'server_message_transport.dart';

/// Returns the pending-row ids that were durably handled by the consumer.
typedef PendingNotificationHandler =
    Future<Iterable<int>> Function(Map<String, dynamic> item);

/// Application-facing source for background DM notifications.
abstract interface class PendingNotificationSource {
  /// Converts a source-specific pending row into a transport-neutral event.
  ///
  /// Implementations own any wire-format parsing. Sources without event rows
  /// can return null and leave legacy notification handling to the consumer.
  MessageEvent? eventFromPendingRow(
    Map<String, dynamic> row, {
    required int selfId,
    required int friendId,
  });

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
  MessageEvent? eventFromPendingRow(
    Map<String, dynamic> row, {
    required int selfId,
    required int friendId,
  }) => ServerMessageTransport.eventFromPendingRow(
    row,
    selfId: selfId,
    friendId: friendId,
  );

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
