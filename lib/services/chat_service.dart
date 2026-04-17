import 'dart:async';

import 'package:hive_flutter/hive_flutter.dart';

import '../models/chat_models.dart';
import 'api_client.dart';
import 'local_chat_repository.dart';
import 'p2p_chat_service.dart';
import 'service_utils.dart';
import 'signaling_service.dart';

/// Orchestrates P2P chat (WebRTC DataChannel via SignalingService) with
/// server-relay fallback for offline peers.
///
/// Message history is loaded from local Hive storage first; server history
/// is only consulted on first launch (when Hive is empty).
class ChatService {
  ChatService(this._apiClient) {
    _signalingService = SignalingService(_apiClient);
    _localRepo = LocalChatRepository();
  }

  final ApiClient _apiClient;
  late final SignalingService _signalingService;
  late final LocalChatRepository _localRepo;

  P2PChatService? _p2p;

  final StreamController<ChatMessage> _messageStream =
      StreamController.broadcast();

  Stream<ChatMessage> get messageStream => _messageStream.stream;

  int? _currentSelfId;

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

    // Fallback: fetch from server and cache locally
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

  // ── connect (P2P) ─────────────────────────────────────────────────────────

  /// Connect to friend. Caller side initiates the WebRTC offer.
  Future<void> connectToDm(
    int selfId,
    int friendId, {
    bool isCaller = true,
  }) async {
    _currentSelfId = selfId;

    await _p2p?.dispose();

    _signalingService.connect(friendId);

    _p2p = P2PChatService(
      selfId: selfId,
      friendId: friendId,
      signalingService: _signalingService,
      localRepo: _localRepo,
      onMessage: (msg) {
        if (!_messageStream.isClosed) _messageStream.add(msg);
      },
    );

    if (isCaller) {
      await _p2p!.startAsCaller();
    } else {
      await _p2p!.startAsAnswerer();
    }

    // Fetch and deliver any pending offline messages
    _deliverPending(selfId, friendId);
  }

  // ── send ──────────────────────────────────────────────────────────────────

  /// Send a message. Prefers P2P DataChannel; falls back to server relay.
  Future<void> sendMessage(int receiverId, String text) async {
    if (_p2p != null && _p2p!.sendMessage(text)) return;

    // Offline fallback: store via server relay
    final createdAt = DateTime.now().toIso8601String();
    try {
      await _apiClient.postJson('/api/chat/dm/$receiverId/send', {
        'text': text,
      });
    } catch (_) {}

    // Still store locally so the sender sees the message immediately
    final selfId = _currentSelfId;
    if (selfId != null) {
      final msg = ChatMessage(
        senderId: selfId,
        receiverId: receiverId,
        text: text,
        createdAt: createdAt,
        isPending: true,
      );
      await _localRepo.saveMessage(selfId, msg);
      if (!_messageStream.isClosed) _messageStream.add(msg);
    }
  }

  // ── pending delivery ──────────────────────────────────────────────────────

  Future<void> _deliverPending(int selfId, int friendId) async {
    try {
      final res = await _apiClient.getJson('/api/chat/dm/pending');
      final raw = res['messages'];
      if (raw is! List) return;

      final pendingIds = <int>[];
      for (final item in raw) {
        final msg = ChatMessage.fromJson(item as Map<String, dynamic>);
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
    _p2p?.dispose();
    _p2p = null;
    _signalingService.disconnect();
  }

  void dispose() {
    disconnect();
    _signalingService.dispose();
    _messageStream.close();
  }
}
