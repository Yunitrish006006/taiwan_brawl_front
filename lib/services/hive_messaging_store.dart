import 'dart:convert';

import 'package:hive_flutter/hive_flutter.dart';
import 'package:taiwan_brawl_messaging/taiwan_brawl_messaging.dart';

/// Encrypted Hive adapter for shared message events and the local outbox.
///
/// The encryption key is injected by the platform credential/identity layer;
/// this adapter never creates or persists the key itself.
class HiveMessageEventStore
    implements
        MessageEventStore,
        MessageConflictStore,
        MessageInboxStore,
        MessageSyncCursorStore {
  HiveMessageEventStore({
    required this.encryptionKey,
    this.boxName = 'taiwan_brawl_message_events',
  });

  final List<int> encryptionKey;
  final String boxName;

  static const _eventPrefix = 'event:';
  static const _outboxPrefix = 'outbox:';
  static const _conflictPrefix = 'conflict:';
  static const _inboxPrefix = 'inbox:';
  static const _cursorPrefix = 'cursor:';

  Future<Box<String>> _open() => Hive.openBox<String>(
    boxName,
    encryptionCipher: HiveAesCipher(encryptionKey),
  );

  @override
  Future<List<MessageEvent>> loadAll() async {
    final box = await _open();
    final events = <MessageEvent>[];
    for (final key in box.keys.whereType<String>()) {
      if (!key.startsWith(_eventPrefix)) continue;
      final event = await _decodeEvent(box, key);
      if (event != null) events.add(event);
    }
    return events;
  }

  @override
  Future<List<MessageEvent>> loadPendingOutbox() async {
    final box = await _open();
    final events = <MessageEvent>[];
    for (final key in box.keys.whereType<String>()) {
      if (!key.startsWith(_outboxPrefix)) continue;
      final event = await _decodeEvent(box, key);
      if (event != null) events.add(event);
    }
    return events;
  }

  @override
  Future<void> append(MessageEvent event, {required bool pendingOutbox}) async {
    final box = await _open();
    final encoded = jsonEncode(event.toJson());
    await box.put('$_eventPrefix${event.eventId}', encoded);
    if (pendingOutbox) {
      await box.put('$_outboxPrefix${event.eventId}', encoded);
    }
  }

  @override
  Future<void> acknowledgeOutbox(String eventId) async {
    final box = await _open();
    await box.delete('$_outboxPrefix$eventId');
  }

  @override
  Future<String?> loadSyncCursor(String scope) async {
    final box = await _open();
    return box.get('$_cursorPrefix$scope');
  }

  @override
  Future<void> saveSyncCursor(String scope, String cursor) async {
    final box = await _open();
    await box.put('$_cursorPrefix$scope', cursor);
  }

  @override
  Future<List<MessageEvent>> loadInbox() async {
    final box = await _open();
    final events = <MessageEvent>[];
    for (final key in box.keys.whereType<String>()) {
      if (!key.startsWith(_inboxPrefix)) continue;
      final event = await _decodeEvent(box, key, removeCorrupt: true);
      if (event != null) events.add(event);
    }
    return events;
  }

  @override
  Future<void> appendInbox(MessageEvent event) async {
    final box = await _open();
    await box.put('$_inboxPrefix${event.eventId}', jsonEncode(event.toJson()));
  }

  @override
  Future<void> removeInbox(String eventId) async {
    final box = await _open();
    await box.delete('$_inboxPrefix$eventId');
  }

  @override
  Future<List<MessageConflict>> loadConflicts() async {
    final box = await _open();
    return [
      for (final key in box.keys.whereType<String>())
        if (key.startsWith(_conflictPrefix))
          MessageConflict.fromJson(
            Map<String, Object?>.from(jsonDecode(box.get(key)!) as Map),
          ),
    ];
  }

  @override
  Future<void> appendConflict(MessageConflict conflict) async {
    final box = await _open();
    await box.put(
      '$_conflictPrefix${conflict.eventId}',
      jsonEncode(conflict.toJson()),
    );
  }

  Future<MessageEvent?> _decodeEvent(
    Box<String> box,
    String key, {
    bool removeCorrupt = false,
  }) async {
    try {
      final encoded = box.get(key);
      if (encoded == null) throw const FormatException('Event record is empty');
      final decoded = jsonDecode(encoded);
      if (decoded is! Map) {
        throw const FormatException('Event record must be an object');
      }
      return MessageEvent.fromJson(Map<String, Object?>.from(decoded));
    } catch (error) {
      final conflict = MessageConflict(
        eventId: 'corrupt:$key',
        messageId: 'unknown',
        reason: 'Corrupt local event record: $error',
      );
      await appendConflict(conflict);
      if (removeCorrupt) await box.delete(key);
      return null;
    }
  }
}
