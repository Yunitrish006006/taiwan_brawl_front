import 'package:flutter_test/flutter_test.dart';
import 'package:taiwan_brawl/services/game_catalog_trust_config.dart';

void main() {
  test(
    'bundled catalog trust root has the expected publisher and key shape',
    () {
      final keys = parseGameCatalogTrustKeys(defaultGameCatalogTrustKeysJson);

      expect(keys.keys, {'catalog-prod-2026-10'});
      expect(keys['catalog-prod-2026-10']!.publisher, 'taiwan-brawl');
      expect(keys['catalog-prod-2026-10']!.publicKey, hasLength(32));
    },
  );

  test('malformed and wrong-sized keys fail closed', () {
    expect(parseGameCatalogTrustKeys('{broken'), isEmpty);
    expect(
      parseGameCatalogTrustKeys(
        '{"bad":{"publisher":"taiwan-brawl","publicKey":"AQ"}}',
      ),
      isEmpty,
    );
    expect(
      parseGameCatalogTrustKeys(
        '{"bad":{"publisher":" ","publicKey":"AQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQE"}}',
      ),
      isEmpty,
    );
  });
}
