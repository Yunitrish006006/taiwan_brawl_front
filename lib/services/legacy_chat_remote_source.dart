import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/message_history_page.dart';
import '../models/legacy_chat_record.dart';
import 'api_client.dart';
import 'service_utils.dart';

/// Legacy history reads used by the conversation migration adapter.
abstract interface class LegacyChatHistoryRemoteSource {
  Future<MessageHistoryPage<LegacyChatRecord>> fetchHistory(
    int friendId, {
    MessageHistoryCursor? before,
  });
}

/// Legacy whole-history snapshot operations used by migration sync.
abstract interface class LegacyChatSnapshotRemoteSource {
  Future<void> uploadSyncData(int friendId, Map<String, dynamic> data);

  Future<LegacyChatSnapshotDownload> downloadSyncData(int friendId);

  Future<void> acknowledgeSyncData(int friendId, String snapshotId);
}

class LegacyChatSnapshotDownload {
  const LegacyChatSnapshotDownload({required this.data, this.snapshotId});

  final Map<String, dynamic> data;
  final String? snapshotId;
}

/// Legacy send and recall operations used during staged event-route migration.
abstract interface class LegacyChatDeliveryRemoteSource {
  Future<Map<String, dynamic>> sendMessage(int friendId, String text);

  Future<void> recallMessage(int friendId, String messageKey);
}

/// HTTP adapter for the existing Cloudflare chat compatibility endpoints.
class ServerLegacyChatRemoteSource
    implements
        LegacyChatHistoryRemoteSource,
        LegacyChatSnapshotRemoteSource,
        LegacyChatDeliveryRemoteSource {
  ServerLegacyChatRemoteSource(
    this._apiClient, {
    this.allowPlaintextCompatibilityWrites = false,
  });

  final ApiClient _apiClient;

  /// Legacy endpoints send readable message bodies or whole chat snapshots.
  /// Production keeps these writes disabled; only explicit migration tests or
  /// a deliberately temporary compatibility build may opt in.
  final bool allowPlaintextCompatibilityWrites;

  void _requirePlaintextCompatibilityWrites() {
    if (!allowPlaintextCompatibilityWrites) {
      throw StateError(
        'Legacy plaintext chat writes are disabled; use the encrypted event transport.',
      );
    }
  }

  @override
  Future<MessageHistoryPage<LegacyChatRecord>> fetchHistory(
    int friendId, {
    MessageHistoryCursor? before,
  }) async {
    final queryParameters = <String, String>{
      if (before != null) ...{
        'before': before.createdAt,
        'beforeId': '${before.rowId}',
      },
    };
    final query = queryParameters.isEmpty
        ? ''
        : '?${Uri(queryParameters: queryParameters).query}';
    final response = await _apiClient.getJson(
      '/api/chat/dm/$friendId/history$query',
    );
    final messages = jsonModelList(
      response,
      'messages',
      LegacyChatRecord.fromLegacyServerJson,
    );
    return MessageHistoryPage(
      messages: messages,
      hasMore: response['hasMore'] == true,
      nextCursor: jsonNullableModel(
        response,
        'nextCursor',
        MessageHistoryCursor.fromJson,
      ),
    );
  }

  @override
  Future<void> uploadSyncData(int friendId, Map<String, dynamic> data) async {
    _requirePlaintextCompatibilityWrites();
    await _apiClient.postRaw(
      '/api/chat/dm/$friendId/sync-upload',
      jsonEncode(data),
    );
  }

  @override
  Future<LegacyChatSnapshotDownload> downloadSyncData(int friendId) async {
    http.Response response;
    try {
      response = await _apiClient.getRawResponse(
        '/api/chat/dm/$friendId/sync-download-v2',
      );
    } on ApiException catch (error) {
      if (error.statusCode != 404) rethrow;
      final raw = await _apiClient.getRaw(
        '/api/chat/dm/$friendId/sync-download',
      );
      return LegacyChatSnapshotDownload(
        data: Map<String, dynamic>.from(jsonDecode(raw) as Map),
      );
    }
    return LegacyChatSnapshotDownload(
      data: Map<String, dynamic>.from(jsonDecode(response.body) as Map),
      snapshotId: response.headers['x-chat-snapshot-id'],
    );
  }

  @override
  Future<void> acknowledgeSyncData(int friendId, String snapshotId) async {
    await _apiClient.postJson('/api/chat/dm/$friendId/sync-ack', {
      'snapshotId': snapshotId,
    });
  }

  @override
  Future<Map<String, dynamic>> sendMessage(int friendId, String text) async {
    _requirePlaintextCompatibilityWrites();
    return _apiClient.postJson('/api/chat/dm/$friendId/send', {'text': text});
  }

  @override
  Future<void> recallMessage(int friendId, String messageKey) async {
    _requirePlaintextCompatibilityWrites();
    await _apiClient.postJson('/api/chat/dm/$friendId/recall', {
      'messageKey': messageKey,
    });
  }
}
