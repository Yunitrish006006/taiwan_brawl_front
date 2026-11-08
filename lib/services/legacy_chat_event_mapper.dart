import 'dart:convert';

import 'package:taiwan_brawl_messaging/taiwan_brawl_messaging.dart';

import '../models/legacy_chat_record.dart';

/// Converts retained legacy chat rows into deterministic shared events.
///
/// This mapper owns compatibility conversion only. It does not read Hive,
/// perform synchronization, or mutate the shared event repository.
class LegacyChatEventMapper {
  const LegacyChatEventMapper._();

  /// Converts a legacy whole-history snapshot into shared message events.
  static List<MessageEvent> fromSnapshot(
    Map<String, dynamic> data,
    int selfId,
    int friendId,
  ) {
    return fromValidatedSnapshot(validateSnapshot(data), selfId, friendId);
  }

  /// Validates and normalizes every row before a snapshot is applied anywhere.
  ///
  /// The remote snapshot is later imported into Hive as raw JSON, so silently
  /// skipping a row here would allow the event projection and compatibility
  /// store to disagree. Reject the complete payload before either is mutated.
  static Map<String, dynamic> validateSnapshot(Map<String, dynamic> data) {
    final normalized = <String, Map<String, String>>{};
    final boxPattern = RegExp(r'^chat_(\d+)_(\d+)$');
    for (final boxEntry in data.entries) {
      final match = boxPattern.firstMatch(boxEntry.key);
      if (match == null) {
        throw FormatException('Invalid legacy chat box name: ${boxEntry.key}');
      }
      final low = int.tryParse(match.group(1)!);
      final high = int.tryParse(match.group(2)!);
      if (low == null || high == null || low >= high) {
        throw FormatException('Invalid legacy chat box name: ${boxEntry.key}');
      }
      final rawRows = boxEntry.value;
      if (rawRows is! Map) {
        throw FormatException('Invalid legacy chat box: ${boxEntry.key}');
      }

      final rows = <String, String>{};
      for (final rowEntry in rawRows.entries) {
        if (rowEntry.key is! String || rowEntry.value is! String) {
          throw FormatException(
            'Invalid legacy chat row in ${boxEntry.key}: row keys and values must be strings.',
          );
        }
        final messageKey = rowEntry.key as String;
        final rawValue = rowEntry.value as String;
        late final Object? decoded;
        try {
          decoded = jsonDecode(rawValue);
        } on FormatException catch (error) {
          throw FormatException(
            'Invalid JSON in ${boxEntry.key}/$messageKey: ${error.message}',
          );
        }
        if (decoded is! Map<String, dynamic>) {
          throw FormatException(
            'Invalid legacy chat record in ${boxEntry.key}/$messageKey.',
          );
        }

        late final LegacyChatRecord record;
        try {
          record = LegacyChatRecord.fromJson(decoded);
        } on FormatException catch (error) {
          throw FormatException(
            'Invalid legacy chat record in ${boxEntry.key}/$messageKey: ${error.message}',
          );
        } on TypeError {
          throw FormatException(
            'Invalid field type in ${boxEntry.key}/$messageKey.',
          );
        }
        final timestamp = DateTime.tryParse(record.createdAt);
        final participants = {record.senderId, record.receiverId};
        if (record.messageKey != messageKey ||
            timestamp == null ||
            participants.length != 2 ||
            !participants.contains(low) ||
            !participants.contains(high)) {
          throw FormatException(
            'Legacy chat row identity does not match ${boxEntry.key}/$messageKey.',
          );
        }
        rows[messageKey] = rawValue;
      }
      normalized[boxEntry.key] = rows;
    }
    return normalized;
  }

  /// Maps a snapshot already validated by [validateSnapshot].
  static List<MessageEvent> fromValidatedSnapshot(
    Map<String, dynamic> data,
    int selfId,
    int friendId,
  ) {
    final low = selfId < friendId ? selfId : friendId;
    final high = selfId < friendId ? friendId : selfId;
    final box = data['chat_${low}_$high'];
    if (box == null) return const [];
    final conversationId = '$low:$high';
    final events = <MessageEvent>[];
    for (final entry in box.entries) {
      final raw = jsonDecode(entry.value as String) as Map<String, dynamic>;
      final record = LegacyChatRecord.fromJson(raw);
      final messageKey = entry.key.toString();
      final createdAt = DateTime.parse(record.createdAt).toUtc();
      events.add(
        MessageEvent(
          eventId: 'sync-created:$messageKey',
          messageId: messageKey,
          conversationId: conversationId,
          actorId: record.senderId.toString(),
          type: MessageEventType.created,
          revision: 0,
          createdAt: createdAt,
          body: record.text,
        ),
      );
      if (record.isRecalled) {
        events.add(
          MessageEvent(
            eventId: 'sync-recalled:$messageKey',
            messageId: messageKey,
            conversationId: conversationId,
            actorId: record.senderId.toString(),
            type: MessageEventType.recalled,
            revision: 1,
            createdAt: createdAt.toUtc(),
          ),
        );
      }
    }
    return events;
  }

  /// Converts stored legacy records into deterministic migration events.
  static List<MessageEvent> fromRecords(
    Iterable<LegacyChatRecord> messages,
    int selfId,
    int friendId,
  ) {
    final low = selfId < friendId ? selfId : friendId;
    final high = selfId < friendId ? friendId : selfId;
    final conversationId = '$low:$high';
    final events = <MessageEvent>[];
    for (final message in messages) {
      final createdAt = DateTime.tryParse(message.createdAt);
      if (createdAt == null || message.messageKey.isEmpty) continue;
      events.add(
        MessageEvent(
          eventId: 'legacy-created:${message.messageKey}',
          messageId: message.messageKey,
          conversationId: conversationId,
          actorId: message.senderId.toString(),
          type: MessageEventType.created,
          revision: 0,
          createdAt: createdAt,
          body: message.text,
        ),
      );
      if (message.isRecalled) {
        events.add(
          MessageEvent(
            eventId: 'legacy-recalled:${message.messageKey}',
            messageId: message.messageKey,
            conversationId: conversationId,
            actorId: message.senderId.toString(),
            type: MessageEventType.recalled,
            revision: 1,
            createdAt: createdAt.toUtc(),
          ),
        );
      }
    }
    return events;
  }
}
