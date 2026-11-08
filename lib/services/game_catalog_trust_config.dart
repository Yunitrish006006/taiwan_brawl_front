import 'dart:convert';

import 'game_resource_catalog_source.dart';

const defaultGameCatalogTrustKeysJson =
    '{"catalog-prod-2026-10":{"publisher":"taiwan-brawl","publicKey":"4WyFxNR343aaKu1ccZNpBGg4OQ2D3qH7ekYMAJzFQ1c"}}';

/// Parses publisher trust roots. Invalid configuration always fails closed.
Map<String, GameCatalogTrustKey> parseGameCatalogTrustKeys(String encoded) {
  try {
    final decoded = jsonDecode(encoded);
    if (decoded is! Map<String, dynamic>) return const {};
    final keys = <String, GameCatalogTrustKey>{};
    for (final entry in decoded.entries) {
      if (entry.key.trim().isEmpty || entry.value is! Map) continue;
      final value = Map<String, dynamic>.from(entry.value as Map);
      final publisher = value['publisher'];
      final publicKey = value['publicKey'];
      if (publisher is! String ||
          publisher.trim().isEmpty ||
          publicKey is! String) {
        continue;
      }
      final bytes = base64Url.decode(base64Url.normalize(publicKey));
      if (bytes.length != 32) continue;
      keys[entry.key] = GameCatalogTrustKey(
        publisher: publisher,
        publicKey: bytes,
      );
    }
    return Map.unmodifiable(keys);
  } on Object {
    return const {};
  }
}

Map<String, GameCatalogTrustKey> configuredGameCatalogTrustKeys() {
  const encoded = String.fromEnvironment(
    'GAME_CATALOG_TRUST_KEYS',
    defaultValue: defaultGameCatalogTrustKeysJson,
  );
  return parseGameCatalogTrustKeys(encoded);
}
