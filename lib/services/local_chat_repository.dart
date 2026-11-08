import 'dart:convert';

import 'package:hive_flutter/hive_flutter.dart';

import '../models/legacy_chat_record.dart';
import 'legacy_chat_migration_manifest.dart';
import 'legacy_chat_store.dart';

/// Local Hive storage for DM chat history.
/// Each conversation has its own box named `chat_<low_id>_<high_id>`.
class LocalChatRepository
    implements
        LegacyChatHistoryStore,
        LegacyPendingMessageStore,
        LegacyChatDeliveryStore,
        LegacyChatSnapshotStore {
  static const String _boxPrefix = 'chat_';
  static const String _migrationBoxName = 'chat_event_migration_v1';

  static String _boxName(int userIdA, int userIdB) {
    final low = userIdA < userIdB ? userIdA : userIdB;
    final high = userIdA < userIdB ? userIdB : userIdA;
    return '$_boxPrefix${low}_$high';
  }

  Future<Box<String>> _openBox(int userIdA, int userIdB) {
    return Hive.openBox<String>(_boxName(userIdA, userIdB));
  }

  Future<Box<String>> _openMigrationBox() =>
      Hive.openBox<String>(_migrationBoxName);

  Future<void> _invalidateMigrationManifest(int selfId, int friendId) async {
    final box = await _openMigrationBox();
    await box.delete(_boxName(selfId, friendId));
  }

  /// Persist a message. Uses `createdAt_senderId` as a sortable key to avoid duplicates.
  @override
  Future<void> saveMessage(int selfId, LegacyChatRecord msg) async {
    final box = await _openBox(
      selfId,
      msg.senderId == selfId ? msg.receiverId : msg.senderId,
    );
    final key = msg.messageKey;
    if (!box.containsKey(key)) {
      await box.put(key, jsonEncode(msg.toJson()));
      await _invalidateMigrationManifest(
        selfId,
        msg.senderId == selfId ? msg.receiverId : msg.senderId,
      );
    }
  }

  @override
  Future<LegacyChatHistorySnapshot> getHistorySnapshot(
    int selfId,
    int friendId,
  ) async {
    final box = await _openBox(selfId, friendId);
    final sourceRows = _sourceRows(box);
    final messages = <LegacyChatRecord>[];
    final invalidRowKeys = <String>[];
    for (final entry in sourceRows.entries) {
      try {
        final decoded = jsonDecode(entry.value);
        if (decoded is! Map<String, dynamic>) {
          invalidRowKeys.add(entry.key);
          continue;
        }
        final message = LegacyChatRecord.fromJson(decoded);
        if (message.messageKey != entry.key ||
            DateTime.tryParse(message.createdAt) == null) {
          invalidRowKeys.add(entry.key);
          continue;
        }
        messages.add(message);
      } on FormatException {
        invalidRowKeys.add(entry.key);
      } on TypeError {
        invalidRowKeys.add(entry.key);
      }
    }
    return LegacyChatHistorySnapshot(
      messages: messages,
      sourceRevision: LegacyChatMigrationManifest.sourceRevision(sourceRows),
      invalidRowKeys: invalidRowKeys,
    );
  }

  @override
  Future<Set<String>?> migratedEventMessageIds(int selfId, int friendId) async {
    final manifestBox = await _openMigrationBox();
    final key = _boxName(selfId, friendId);
    final raw = manifestBox.get(key);
    if (raw == null) return null;
    final legacyBox = await _openBox(selfId, friendId);
    final manifest = LegacyChatMigrationManifest.decode(
      raw,
      sourceRows: _sourceRows(legacyBox),
    );
    if (manifest == null) {
      await manifestBox.delete(key);
      return null;
    }
    final upgraded = manifest.upgradedPayload;
    if (upgraded != null) await manifestBox.put(key, upgraded);
    return manifest.messageIds;
  }

  @override
  Future<bool> markEventMessagesMigrated(
    int selfId,
    int friendId,
    Set<String> messageIds, {
    required String expectedSourceRevision,
  }) async {
    final legacyBox = await _openBox(selfId, friendId);
    final manifestBox = await _openMigrationBox();
    final sourceRows = _sourceRows(legacyBox);
    if (LegacyChatMigrationManifest.sourceRevision(sourceRows) !=
        expectedSourceRevision) {
      return false;
    }
    final sourceRowKeys = sourceRows.keys.toList()..sort();
    if (messageIds.isEmpty || messageIds.length != sourceRowKeys.length) {
      throw StateError('Cannot mark an incomplete legacy history migration.');
    }
    final key = _boxName(selfId, friendId);
    await manifestBox.put(
      key,
      LegacyChatMigrationManifest.encode(messageIds, sourceRows: sourceRows),
    );
    return true;
  }

  static List<String> _sortedKeys(Box<String> box) =>
      box.keys.cast<String>().toList()..sort();

  static Map<String, String> _sourceRows(Box<String> box) => {
    for (final key in _sortedKeys(box)) key: box.get(key) ?? '',
  };

  /// Mark a message as recalled in local storage.
  @override
  Future<void> markRecalled(int selfId, int friendId, String messageKey) async {
    final box = await _openBox(selfId, friendId);
    final raw = box.get(messageKey);
    if (raw == null) return;
    final map = jsonDecode(raw) as Map<String, dynamic>;
    map['isRecalled'] = true;
    await box.put(messageKey, jsonEncode(map));
    await _invalidateMigrationManifest(selfId, friendId);
  }

  /// Export all messages for the given conversations as a JSON-serialisable map.
  @override
  /// Format: `{ "chat_<low>_<high>": { "<messageKey>": <rawJson> } }`
  Future<Map<String, Map<String, String>>> exportAll(
    int selfId,
    List<int> friendIds,
  ) async {
    final result = <String, Map<String, String>>{};
    for (final friendId in friendIds) {
      final box = await _openBox(selfId, friendId);
      if (box.isEmpty) continue;
      final name = _boxName(selfId, friendId);
      result[name] = {for (final k in box.keys) k as String: box.get(k)!};
    }
    return result;
  }

  /// Import messages from an exported map, skipping already-existing keys.
  @override
  Future<void> importAll(Map<String, dynamic> data) async {
    for (final entry in data.entries) {
      final boxName = entry.key;
      final messages = entry.value as Map<String, dynamic>;
      final box = await Hive.openBox<String>(boxName);
      for (final msgEntry in messages.entries) {
        if (!box.containsKey(msgEntry.key)) {
          await box.put(msgEntry.key, msgEntry.value as String);
        }
      }
      final migrationBox = await _openMigrationBox();
      await migrationBox.delete(boxName);
    }
  }
}
