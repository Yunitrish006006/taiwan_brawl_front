import 'dart:convert';

import 'package:hive_flutter/hive_flutter.dart';

import '../models/chat_models.dart';

/// Local Hive storage for DM chat history.
/// Each conversation has its own box named `chat_<low_id>_<high_id>`.
class LocalChatRepository {
  static const String _boxPrefix = 'chat_';

  static String _boxName(int userIdA, int userIdB) {
    final low = userIdA < userIdB ? userIdA : userIdB;
    final high = userIdA < userIdB ? userIdB : userIdA;
    return '$_boxPrefix${low}_$high';
  }

  Future<Box<String>> _openBox(int userIdA, int userIdB) {
    return Hive.openBox<String>(_boxName(userIdA, userIdB));
  }

  /// Persist a message. Uses `createdAt_senderId` as a sortable key to avoid duplicates.
  Future<void> saveMessage(int selfId, ChatMessage msg) async {
    final box = await _openBox(selfId, msg.senderId == selfId ? msg.receiverId : msg.senderId);
    final key = msg.messageKey;
    if (!box.containsKey(key)) {
      await box.put(key, jsonEncode({
        'senderId': msg.senderId,
        'receiverId': msg.receiverId,
        'text': msg.text,
        'createdAt': msg.createdAt,
        'isPending': msg.isPending,
          'isRecalled': msg.isRecalled,
        'pendingId': msg.pendingId,
      }));
    }
  }

  /// Delete a message by its original createdAt + senderId key.
  Future<void> deleteMessage(
    int selfId,
    int friendId,
    String createdAt,
    int senderId,
  ) async {
    final box = await _openBox(selfId, friendId);
    final key = '${createdAt}_$senderId';
    await box.delete(key);
  }

  /// Load messages for a conversation, newest-last.
  Future<List<ChatMessage>> getMessages(int selfId, int friendId) async {
    final box = await _openBox(selfId, friendId);
    final keys = box.keys.toList()..sort();
    return keys.map((k) {
      final raw = box.get(k) ?? '{}';
      final map = jsonDecode(raw) as Map<String, dynamic>;
      return ChatMessage(
        senderId: (map['senderId'] as num).toInt(),
        receiverId: (map['receiverId'] as num).toInt(),
        text: map['text'] as String? ?? '',
        createdAt: map['createdAt'] as String? ?? '',
        isPending: map['isPending'] as bool? ?? false,
        isRecalled: map['isRecalled'] as bool? ?? false,
        pendingId: map['pendingId'] != null ? (map['pendingId'] as num).toInt() : null,
      );
    }).toList();
  }

  /// Remove pending flag once message is ack'd (update in-place).
  Future<void> markDelivered(int selfId, int friendId, String createdAt, int senderId) async {
    final box = await _openBox(selfId, friendId);
    final key = '${createdAt}_$senderId';
    final raw = box.get(key);
    if (raw == null) return;
    final map = jsonDecode(raw) as Map<String, dynamic>;
    map['isPending'] = false;
    map['pendingId'] = null;
    await box.put(key, jsonEncode(map));
  }

  /// Mark a message as recalled in local storage.
  Future<void> markRecalled(int selfId, int friendId, String messageKey) async {
    final box = await _openBox(selfId, friendId);
    final raw = box.get(messageKey);
    if (raw == null) return;
    final map = jsonDecode(raw) as Map<String, dynamic>;
    map['isRecalled'] = true;
    await box.put(messageKey, jsonEncode(map));
  }

  /// Read a single message by its messageKey. Returns null if not found.
  Future<ChatMessage?> getMessage(
    int selfId,
    int friendId,
    String messageKey,
  ) async {
    final box = await _openBox(selfId, friendId);
    final raw = box.get(messageKey);
    if (raw == null) return null;
    final map = jsonDecode(raw) as Map<String, dynamic>;
    return ChatMessage(
      senderId: (map['senderId'] as num).toInt(),
      receiverId: (map['receiverId'] as num).toInt(),
      text: map['text'] as String? ?? '',
      createdAt: map['createdAt'] as String? ?? '',
      isPending: map['isPending'] as bool? ?? false,
      isRecalled: map['isRecalled'] as bool? ?? false,
      pendingId: map['pendingId'] != null
          ? (map['pendingId'] as num).toInt()
          : null,
    );
  }

  Future<void> closeAll() async {
    await Hive.close();
  }
}
