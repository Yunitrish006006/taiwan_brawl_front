import 'dart:async';
import 'dart:convert';

import 'package:taiwan_brawl_messaging/taiwan_brawl_messaging.dart';

import 'api_client.dart';

/// Adapter for the backend event route plus the legacy pending-message relay.
///
/// New events use `/event` and retain the full envelope. Legacy rows are
/// converted deterministically so old messages remain readable during rollout;
/// they are not treated as proof that the server already supports revisions.
class ServerMessageTransport implements MessageReceiptTransport {
  ServerMessageTransport({
    required ApiClient apiClient,
    required this.selfId,
    required this.friendId,
    this.deviceId,
    this.relayEncryptionReady = false,
    this.conversationEncryptor,
    this.conversationKeyId,
    this.pollInterval = const Duration(seconds: 2),
    this.syncCursorStore,
  }) : _apiClient = apiClient;

  final ApiClient _apiClient;
  final int selfId;
  final int friendId;
  final String? deviceId;
  final bool relayEncryptionReady;
  final ConversationEncryptor? conversationEncryptor;
  final String? conversationKeyId;
  final Duration pollInterval;
  final MessageSyncCursorStore? syncCursorStore;
  final StreamController<MessageEvent> _events =
      StreamController<MessageEvent>.broadcast();
  Timer? _pollTimer;
  Future<void>? _pollInFlight;
  bool _connected = false;
  final Map<String, int> _pendingReceipts = <String, int>{};
  final Set<int> _observedPendingIds = <int>{};
  final Set<int> _acknowledgedPendingIds = <int>{};
  int? _cursorValue;

  @override
  Stream<MessageEvent> get events => _events.stream;

  @override
  Future<void> connect() async {
    if (_connected) return;
    if (deviceId != null) {
      await _apiClient.postJson('/api/chat/dm/device-register', {
        'deviceId': deviceId,
      });
    }
    _connected = true;
    await _poll();
    _pollTimer = Timer.periodic(pollInterval, (_) => _poll());
  }

  @override
  Future<void> send(MessageEvent event) async {
    if (!_connected) {
      throw StateError('Server message transport is not connected');
    }
    if (!relayEncryptionReady) {
      throw StateError(
        'Server relay is disabled until end-to-end message encryption is ready',
      );
    }
    var wireEvent = event;
    final encryptor = conversationEncryptor;
    final keyId = conversationKeyId;
    if ((event.type == MessageEventType.created ||
            event.type == MessageEventType.edited) &&
        event.body != null &&
        (encryptor == null || keyId == null)) {
      throw StateError(
        'Encrypted relay requires a conversation key and encryptor',
      );
    }
    if (encryptor != null && keyId != null && event.body != null) {
      wireEvent = event.withEncryptedBody(
        await encryptor.encrypt(
          conversationId: event.conversationId,
          keyId: keyId,
          plaintext: event.body!,
        ),
      );
    }
    await _apiClient.postJson('/api/chat/dm/$friendId/event', {
      'event': wireEvent.toJson(),
    });
  }

  @override
  Future<void> disconnect() async {
    _connected = false;
    _pollTimer?.cancel();
    _pollTimer = null;
    _pendingReceipts.clear();
    _observedPendingIds.clear();
    _acknowledgedPendingIds.clear();
    _cursorValue = null;
  }

  @override
  Future<void> acknowledgeReceived(
    MessageEvent event, {
    required bool accepted,
  }) async {
    final pendingId = _pendingReceipts[event.eventId];
    if (pendingId == null || !_connected) return;
    await _apiClient.postJson('/api/chat/dm/ack', {
      'ids': [pendingId],
      'deviceId': ?deviceId,
    });
    _pendingReceipts.remove(event.eventId);
    _acknowledgedPendingIds.add(pendingId);
    await _advanceCursor();
  }

  /// Runs one best-effort receive cycle. The application normally relies on
  /// the periodic poll, while tests and recovery coordinators can explicitly
  /// request an immediate cycle.
  Future<void> pollNow() => _poll();

  Future<void> dispose() async {
    await disconnect();
    await _events.close();
  }

  Future<void> _poll() async {
    if (!_connected) return;
    final inFlight = _pollInFlight;
    if (inFlight != null) return inFlight;

    late Future<void> run;
    run = _pollOnce().whenComplete(() {
      if (identical(_pollInFlight, run)) _pollInFlight = null;
    });
    _pollInFlight = run;
    return run;
  }

  Future<void> _pollOnce() async {
    if (!_connected) return;
    try {
      final cursor = await syncCursorStore?.loadSyncCursor(_cursorScope);
      _cursorValue ??= _parseCursor(cursor) ?? 0;
      final query = <String, String>{
        'friendId': '$friendId',
        'deviceId': ?deviceId,
      };
      final parsedCursor = _cursorValue;
      if (parsedCursor != null) query['afterId'] = '$parsedCursor';
      final response = await _apiClient.getJson(
        '/api/chat/dm/pending?${Uri(queryParameters: query).query}',
      );
      final raw = response['messages'];
      if (raw is! List) return;
      for (final item in raw.whereType<Map>()) {
        final senderId = _readInt(item['sender_id']);
        final pendingId = _readInt(item['id']);
        if (senderId != friendId || pendingId == null) {
          continue;
        }
        _observedPendingIds.add(pendingId);
        var event = eventFromPendingRow(
          Map<String, dynamic>.from(item),
          selfId: selfId,
          friendId: friendId,
        );
        if (event == null) {
          await _apiClient.postJson('/api/chat/dm/ack', {
            'ids': [pendingId],
            'deviceId': ?deviceId,
          });
          _acknowledgedPendingIds.add(pendingId);
          await _advanceCursor();
          continue;
        }
        final encryptedBody = event.encryptedBody;
        final encryptor = conversationEncryptor;
        if (encryptedBody != null && encryptor != null) {
          try {
            event = event.withBody(
              await encryptor.decrypt(
                conversationId: event.conversationId,
                body: encryptedBody,
              ),
            );
          } catch (_) {
            // Do not ACK an event that cannot be decrypted. It remains
            // retryable on the next polling cycle.
            continue;
          }
        }
        _pendingReceipts[event.eventId] = pendingId;
        _events.add(event);
      }
    } catch (_) {
      // Polling is best-effort; local repository/outbox remains authoritative.
    }
  }

  String get _cursorScope => deviceId == null
      ? 'dm:$selfId:$friendId'
      : 'dm:$selfId:$deviceId:$friendId';

  static int? _parseCursor(String? cursor) => int.tryParse(cursor ?? '');

  Future<void> _advanceCursor() async {
    var next = _cursorValue ?? 0;
    final candidates = _observedPendingIds.toList()..sort();
    for (final id in candidates) {
      if (id <= next) {
        _observedPendingIds.remove(id);
        _acknowledgedPendingIds.remove(id);
        continue;
      }
      if (!_acknowledgedPendingIds.contains(id)) break;
      next = id;
      _observedPendingIds.remove(id);
      _acknowledgedPendingIds.remove(id);
    }
    if (next == _cursorValue) return;
    _cursorValue = next;
    await syncCursorStore?.saveSyncCursor(_cursorScope, '$next');
  }

  /// Converts both new event rows and old pending rows without hiding the
  /// legacy boundary from tests or future migration code.
  static MessageEvent? eventFromPendingRow(
    Map<String, dynamic> row, {
    required int selfId,
    required int friendId,
  }) {
    final eventId = row['event_id']?.toString();
    final messageId = row['message_id']?.toString();
    final eventType = row['event_type']?.toString();
    final senderId = _readInt(row['sender_id']);
    final createdAt = DateTime.tryParse(row['created_at']?.toString() ?? '');
    if (senderId == null || createdAt == null) return null;
    final low = selfId < friendId ? selfId : friendId;
    final high = selfId < friendId ? friendId : selfId;

    if (eventId != null && messageId != null && eventType != null) {
      final type = MessageEventType.values
          .where((candidate) => candidate.name == eventType)
          .firstOrNull;
      if (type == null) return null;
      final rawText = row['text']?.toString();
      EncryptedMessageBody? encryptedBody;
      String? body = rawText;
      if (rawText != null) {
        try {
          final decoded = jsonDecode(rawText);
          if (decoded is Map && decoded['encryptedBody'] is Map) {
            encryptedBody = EncryptedMessageBody.fromJson(
              Map<String, Object?>.from(decoded['encryptedBody'] as Map),
            );
            body = null;
          }
        } catch (_) {
          // Legacy text remains a cleartext body.
        }
      }
      return MessageEvent(
        eventId: eventId,
        messageId: messageId,
        conversationId: '$low:$high',
        actorId: senderId.toString(),
        deviceId: row['device_id']?.toString(),
        type: type,
        revision: _readInt(row['revision']) ?? 0,
        createdAt: createdAt,
        body: body,
        encryptedBody: encryptedBody,
        signature: row['signature']?.toString(),
      );
    }

    final legacyType = row['type']?.toString() ?? 'message';
    final legacyMessageId = legacyType == 'recall'
        ? row['text']?.toString()
        : '${createdAt.toIso8601String()}_$senderId';
    if (legacyMessageId == null || legacyMessageId.isEmpty) return null;
    return MessageEvent(
      eventId: 'legacy:${row['id'] ?? legacyMessageId}',
      messageId: legacyMessageId,
      conversationId: '$low:$high',
      actorId: senderId.toString(),
      type: legacyType == 'recall'
          ? MessageEventType.recalled
          : MessageEventType.created,
      revision: legacyType == 'recall' ? 1 : 0,
      createdAt: createdAt,
      body: legacyType == 'recall' ? null : row['text']?.toString(),
    );
  }

  static int? _readInt(Object? value) =>
      value is num ? value.toInt() : int.tryParse('$value');
}
