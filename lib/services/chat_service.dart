import 'dart:async';

import 'package:hive_flutter/hive_flutter.dart';

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
class ChatService {
  ChatService(this._apiClient) {
    _localRepo = LocalChatRepository();
  }

  final ApiClient _apiClient;
  late final LocalChatRepository _localRepo;

  final StreamController<ChatMessage> _messageStream =
      StreamController.broadcast();

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

  // ── connect ───────────────────────────────────────────────────────────────

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

  Future<void> sendMessage(int receiverId, String text) async {
    final createdAt = DateTime.now().toIso8601String();
    final selfId = _currentSelfId;

    // Show immediately as pending in UI
    if (selfId != null) {
      final pending = ChatMessage(
        senderId: selfId,
        receiverId: receiverId,
        text: text,
        createdAt: createdAt,
        isPending: true,
      );
      await _localRepo.saveMessage(selfId, pending);
      if (!_messageStream.isClosed) _messageStream.add(pending);
    }

    try {
      await _apiClient.postJson('/api/chat/dm/$receiverId/send', {
        'text': text,
      });
      // Server accepted — mark delivered
      if (selfId != null) {
        await _localRepo.markDelivered(selfId, receiverId, createdAt, selfId);
        final delivered = ChatMessage(
          senderId: selfId,
          receiverId: receiverId,
          text: text,
          createdAt: createdAt,
          isPending: false,
        );
        if (!_messageStream.isClosed) _messageStream.add(delivered);
      }
    } catch (_) {
      // isPending stays true in UI
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
        final msg = ChatMessage.fromJson(item as Map<String, dynamic>);
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

  void disconnect() {
    _pollTimer?.cancel();
    _pollTimer = null;
  }

  void dispose() {
    disconnect();
    _messageStream.close();
  }
}

