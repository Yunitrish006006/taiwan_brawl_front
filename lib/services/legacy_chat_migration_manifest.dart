import 'dart:convert';

import 'package:crypto/crypto.dart';

/// Validates the durable record of which legacy Hive rows were promoted.
///
/// The codec is independent of Hive so its compatibility rules can be checked
/// without opening or changing a user's stored conversations.
class LegacyChatMigrationManifest {
  const LegacyChatMigrationManifest._({
    required this.messageIds,
    this.upgradedPayload,
  });

  static const int currentVersion = 2;

  final Set<String> messageIds;

  /// Non-null when an older supported format must be rewritten as version 2.
  final String? upgradedPayload;

  static LegacyChatMigrationManifest? decode(
    String? source, {
    required Map<String, String> sourceRows,
  }) {
    if (source == null) return null;
    try {
      final rowKeys = sourceRows.keys.toList()..sort();
      final rowDigests = _digests(sourceRows, rowKeys);
      final decoded = jsonDecode(source);
      if (decoded is List) {
        if (decoded.isEmpty ||
            decoded.any((value) => value is! String) ||
            decoded.length != rowKeys.length) {
          throw const FormatException('Invalid legacy migration manifest.');
        }
        final ids = decoded.cast<String>();
        if (ids.toSet().length != ids.length) {
          throw const FormatException('Invalid legacy migration manifest.');
        }
        return LegacyChatMigrationManifest._(
          messageIds: Set.unmodifiable(ids),
          upgradedPayload: _encode(ids.toSet(), rowKeys, rowDigests),
        );
      }
      if (decoded is! Map ||
          decoded['schemaVersion'] is! int ||
          ![1, currentVersion].contains(decoded['schemaVersion']) ||
          decoded['messageIds'] is! List ||
          decoded['sourceRowKeys'] is! List) {
        throw const FormatException('Invalid legacy migration manifest.');
      }
      final rawIds = decoded['messageIds'] as List;
      final rawKeys = decoded['sourceRowKeys'] as List;
      if (rawIds.isEmpty ||
          rawIds.any((value) => value is! String) ||
          rawKeys.any((value) => value is! String)) {
        throw const FormatException('Invalid legacy migration manifest.');
      }
      final ids = rawIds.cast<String>();
      final sourceKeys = rawKeys.cast<String>();
      final recordedKeys = sourceKeys.toSet();
      final schemaVersion = decoded['schemaVersion'] as int;
      if (ids.toSet().length != ids.length ||
          recordedKeys.length != sourceKeys.length ||
          ids.length != rowKeys.length ||
          !_sameKeys(recordedKeys, rowKeys)) {
        throw const FormatException('Legacy migration manifest is stale.');
      }
      if (schemaVersion == 1) {
        return LegacyChatMigrationManifest._(
          messageIds: Set.unmodifiable(ids),
          upgradedPayload: _encode(ids.toSet(), rowKeys, rowDigests),
        );
      }

      final rawDigests = decoded['sourceRowDigests'];
      if (rawDigests is! Map ||
          rawDigests.keys.any((value) => value is! String) ||
          rawDigests.values.any(
            (value) =>
                value is! String || !RegExp(r'^[a-f0-9]{64}$').hasMatch(value),
          )) {
        throw const FormatException('Invalid legacy row fingerprints.');
      }
      final recordedDigests = rawDigests.cast<String, String>();
      if (!_sameDigestMap(recordedDigests, rowDigests)) {
        throw const FormatException('Legacy migration manifest is stale.');
      }
      return LegacyChatMigrationManifest._(messageIds: Set.unmodifiable(ids));
    } on FormatException {
      return null;
    }
  }

  static String encode(
    Set<String> messageIds, {
    required Map<String, String> sourceRows,
  }) {
    final rowKeys = sourceRows.keys.toList()..sort();
    if (messageIds.isEmpty || messageIds.length != rowKeys.length) {
      throw StateError('Cannot mark an incomplete legacy history migration.');
    }
    return _encode(messageIds, rowKeys, _digests(sourceRows, rowKeys));
  }

  /// Produces an opaque revision token for comparing a read with a later
  /// migration-manifest write without exposing legacy row contents.
  static String sourceRevision(Map<String, String> sourceRows) {
    final rowKeys = sourceRows.keys.toList()..sort();
    final rowDigests = _digests(sourceRows, rowKeys);
    return sha256
        .convert(
          utf8.encode(jsonEncode({'keys': rowKeys, 'digests': rowDigests})),
        )
        .toString();
  }

  static String _encode(
    Set<String> messageIds,
    List<String> sourceRowKeys,
    Map<String, String> sourceRowDigests,
  ) => jsonEncode({
    'schemaVersion': currentVersion,
    'messageIds': messageIds.toList()..sort(),
    'sourceRowKeys': sourceRowKeys,
    'sourceRowDigests': sourceRowDigests,
  });

  static Map<String, String> _digests(
    Map<String, String> sourceRows,
    List<String> rowKeys,
  ) => {
    for (final key in rowKeys)
      key: sha256.convert(utf8.encode(sourceRows[key]!)).toString(),
  };

  static bool _sameKeys(Set<String> left, List<String> right) =>
      left.length == right.length && left.containsAll(right);

  static bool _sameDigestMap(
    Map<String, String> left,
    Map<String, String> right,
  ) =>
      left.length == right.length &&
      left.entries.every((entry) => right[entry.key] == entry.value);
}
