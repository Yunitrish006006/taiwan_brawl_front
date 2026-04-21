import 'dart:async';
import 'dart:convert';

import 'package:hive_flutter/hive_flutter.dart';

import 'package:user_basic_system/user_basic_system.dart' show DmService;

import '../models/chat_models.dart';
import 'api_client.dart';
import 'local_chat_repository.dart';
import 'service_utils.dart';

/// Chat service using periodic polling for real-time message delivery.
///
/// - Send: POST /api/chat/dm/:friendId/send → stored in D1 pending_messages
/// - Receive: Timer.periodic polls /api/chat/dm/pending every 2 seconds,
///   acks received messages, saves to Hive, pushes to UI stream.
/// - History: local Hive first, falls back to server /history on first open.
class ChatService implements DmService {
  ChatService(this._apiClient) {
    _localRepo = LocalChatRepository();
  }

  final ApiClient _apiClient;
  late final LocalChatRepository _localRepo;

  final StreamController<ChatMessage> _messageStream =
      StreamController.broadcast();

  @override
  Stream<ChatMessage> get messageStream => _messageStream.stream;

  int? _currentSelfId;
  int? _currentFriendId;
  Timer? _pollTimer;

  static const Duration _pollInterval = Duration(seconds: 2);

  // ── Hive init ─────────────────────────────────────────────────────────────

  static Future<void> initHive() async {
    await Hive.initFlutter();
  }

  // ── history ───────────────────────────────────────────────────────────────

  /// Returns locally stored messages. If empty, falls back to server history.
  @override
  Future<List<ChatMessage>> fetchHistory(
    int selfId,
    int friendId, {
    String? before,
  }) async {
    final local = await _localRepo.getMessages(selfId, friendId);
    if (local.isNotEmpty) return local;

    final query = before != null
        ? '?before=${Uri.encodeQueryComponent(before)}'
        : '';
    final res = await _apiClient.getJson(
      '/api/chat/dm/$friendId/history$query',
    );
    final serverMessages = jsonModelList(res, 'messages', ChatMessage.fromJson);
    for (final msg in serverMessages) {
      await _localRepo.saveMessage(selfId, msg);
    }
    return serverMessages;
  }

  /// Force-fetch history from server and merge into local cache (no data loss).
  @override
  Future<List<ChatMessage>> syncFromServer(int selfId, int friendId) async {
    final res = await _apiClient.getJson('/api/chat/dm/$friendId/history');
    final serverMessages = jsonModelList(res, 'messages', ChatMessage.fromJson);
    for (final msg in serverMessages) {
      await _localRepo.saveMessage(selfId, msg);
    }
    // Return merged result (local + server)
    return _localRepo.getMessages(selfId, friendId);
  }

  /// Export local chat history for one conversation and upload to server.
  /// Valid for 1 hour, one-time download. Both participants share the same key.
  @override
  Future<void> uploadSyncData(int selfId, int friendId) async {
    final exported = await _localRepo.exportAll(selfId, [friendId]);
    if (exported.isEmpty) return;
    final body = jsonEncode(exported);
    await _apiClient.postRaw('/api/chat/dm/$friendId/sync-upload', body);
  }

  /// Download sync data for one conversation and merge into local cache.
  @override
  Future<void> downloadAndMergeSyncData(int friendId) async {
    final raw = await _apiClient.getRaw('/api/chat/dm/$friendId/sync-download');
    final data = jsonDecode(raw) as Map<String, dynamic>;
    await _localRepo.importAll(data);
  }

  // ── connect ───────────────────────────────────────────────────────────────

  @override
  Future<void> connectToDm(
    int selfId,
    int friendId, {
    bool isCaller = true,
  }) async {
    _currentSelfId = selfId;
    _currentFriendId = friendId;
    disconnect();

    // Deliver any already-pending messages immediately on connect
    await _pollPending();

    // Then keep polling
    _pollTimer = Timer.periodic(_pollInterval, (_) => _pollPending());
  }

  // ── send ──────────────────────────────────────────────────────────────────

  @override
  Future<void> sendMessage(int receiverId, String text) async {
    final createdAt = DateTime.now().toIso8601String();
    final selfId = _currentSelfId;
    // Use client epoch ms as a stable id to correlate pending → delivered in UI
    final clientEpoch = DateTime.now().millisecondsSinceEpoch;

    // Show immediately as pending in UI
    if (selfId != null) {
      final pending = ChatMessage(
        senderId: selfId,
        receiverId: receiverId,
        text: text,
        createdAt: createdAt,
        isPending: true,
        pendingId: clientEpoch,
      );
      await _localRepo.saveMessage(selfId, pending);
      if (!_messageStream.isClosed) _messageStream.add(pending);
    }

    try {
      final res = await _apiClient.postJson('/api/chat/dm/$receiverId/send', {
        'text': text,
      });
      // Server accepted — use server's createdAt so messageKey matches receiver
      final serverCreatedAt = res['createdAt'] as String? ?? createdAt;
      if (selfId != null) {
        // Remove the client-side pending entry and re-save with server createdAt
        await _localRepo.deleteMessage(selfId, receiverId, createdAt, selfId);
        final delivered = ChatMessage(
          senderId: selfId,
          receiverId: receiverId,
          text: text,
          createdAt: serverCreatedAt,
          isPending: false,
          pendingId:
              clientEpoch, // carry the same id so DmPage can find the old pending
        );
        await _localRepo.saveMessage(selfId, delivered);
        if (!_messageStream.isClosed) _messageStream.add(delivered);
      }
    } catch (_) {
      // isPending stays true in UI
    }
  }

  // ── recall ────────────────────────────────────────────────────────────────

  /// Recalls a message. Marks it locally and notifies the receiver via server.
  @override
  Future<void> recallMessage(ChatMessage msg) async {
    final selfId = _currentSelfId;
    final friendId = _currentFriendId;
    if (selfId == null || friendId == null) return;

    // Mark locally immediately
    await _localRepo.markRecalled(selfId, friendId, msg.messageKey);
    if (!_messageStream.isClosed) {
      _messageStream.add(msg.copyWith(isRecalled: true));
    }

    try {
      await _apiClient.postJson('/api/chat/dm/$friendId/recall', {
        'messageKey': msg.messageKey,
      });
    } catch (_) {
      // Best-effort; local state already updated
    }
  }

  // ── polling ───────────────────────────────────────────────────────────────

  Future<void> _pollPending() async {
    final selfId = _currentSelfId;
    if (selfId == null) return;
    try {
      final res = await _apiClient.getJson('/api/chat/dm/pending');
      final raw = res['messages'];
      if (raw is! List || raw.isEmpty) return;

      final pendingIds = <int>[];
      for (final item in raw) {
        final type =
            (item as Map<String, dynamic>)['type'] as String? ?? 'message';
        final rawId = item['id'] != null ? (item['id'] as num).toInt() : null;

        if (type == 'recall') {
          // Recall event: text == messageKey of the original message
          final messageKey = item['text'] as String? ?? '';
          final senderId = (item['sender_id'] as num).toInt();
          if (_currentFriendId != null && senderId == _currentFriendId) {
            await _localRepo.markRecalled(selfId, senderId, messageKey);
            // Read back the updated message from Hive so createdAt is exact
            final updated = await _localRepo.getMessage(
              selfId,
              senderId,
              messageKey,
            );
            if (updated != null && !_messageStream.isClosed) {
              _messageStream.add(updated);
            }
          }
          if (rawId != null) pendingIds.add(rawId);
          continue;
        }

        final msg = ChatMessage.fromJson(item);
        // Only surface messages from the current conversation
        final friendId = _currentFriendId;
        if (friendId != null && msg.senderId != friendId) continue;

        await _localRepo.saveMessage(selfId, msg);
        if (!_messageStream.isClosed) _messageStream.add(msg);
        if (msg.pendingId != null) pendingIds.add(msg.pendingId!);
      }

      if (pendingIds.isNotEmpty) {
        await _apiClient.postJson('/api/chat/dm/ack', {'ids': pendingIds});
      }
    } catch (_) {}
  }

  // ── disconnect / dispose ──────────────────────────────────────────────────

  @override
  void disconnect() {
    _pollTimer?.cancel();
    _pollTimer = null;
  }

  void dispose() {
    disconnect();
    _messageStream.close();
  }
}
