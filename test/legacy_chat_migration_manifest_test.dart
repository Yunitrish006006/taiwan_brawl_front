import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:taiwan_brawl/services/legacy_chat_migration_manifest.dart';

void main() {
  const rows = <String, String>{
    '2026-10-28T00:00:00.000Z_1': '{"text":"row one"}',
    '2026-10-28T00:01:00.000Z_2': '{"text":"row two"}',
  };

  test('writes and validates deterministic version-two fingerprints', () {
    final encoded = LegacyChatMigrationManifest.encode({
      'event-b',
      'event-a',
    }, sourceRows: rows);
    final decodedJson = jsonDecode(encoded) as Map<String, dynamic>;
    final manifest = LegacyChatMigrationManifest.decode(
      encoded,
      sourceRows: rows,
    );

    expect(decodedJson['schemaVersion'], 2);
    expect(decodedJson['messageIds'], ['event-a', 'event-b']);
    expect(decodedJson['sourceRowKeys'], rows.keys.toList()..sort());
    expect(decodedJson['sourceRowDigests'], hasLength(rows.length));
    expect(manifest?.messageIds, {'event-a', 'event-b'});
    expect(manifest?.upgradedPayload, isNull);
  });

  test('upgrades a valid list-only manifest to version two', () {
    final manifest = LegacyChatMigrationManifest.decode(
      jsonEncode(['event-a', 'event-b']),
      sourceRows: rows,
    );

    expect(manifest?.messageIds, {'event-a', 'event-b'});
    expect(jsonDecode(manifest!.upgradedPayload!)['schemaVersion'], 2);
  });

  test('upgrades a version-one key manifest with row fingerprints', () {
    final manifest = LegacyChatMigrationManifest.decode(
      jsonEncode({
        'schemaVersion': 1,
        'messageIds': ['event-a', 'event-b'],
        'sourceRowKeys': rows.keys.toList()..sort(),
      }),
      sourceRows: rows,
    );

    final upgraded = jsonDecode(manifest!.upgradedPayload!);
    expect(manifest.messageIds, {'event-a', 'event-b'});
    expect(upgraded['schemaVersion'], 2);
    expect(upgraded['sourceRowDigests'], hasLength(rows.length));
  });

  test('invalidates changes to either legacy row keys or contents', () {
    final encoded = LegacyChatMigrationManifest.encode({
      'event-a',
      'event-b',
    }, sourceRows: rows);

    expect(
      LegacyChatMigrationManifest.decode(
        encoded,
        sourceRows: {...rows, '2026-10-28T00:02:00.000Z_3': 'new row'},
      ),
      isNull,
    );
    expect(
      LegacyChatMigrationManifest.decode(
        encoded,
        sourceRows: {
          ...rows,
          '2026-10-28T00:00:00.000Z_1': '{"text":"changed"}',
        },
      ),
      isNull,
    );
  });

  test('rejects malformed and incomplete manifests', () {
    expect(
      LegacyChatMigrationManifest.decode('{bad json', sourceRows: rows),
      isNull,
    );
    expect(
      () => LegacyChatMigrationManifest.encode({
        'only-one-event',
      }, sourceRows: rows),
      throwsStateError,
    );
  });
}
