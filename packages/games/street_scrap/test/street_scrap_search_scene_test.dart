import 'package:flutter_test/flutter_test.dart';
import 'package:taiwan_brawl_game_street_scrap/taiwan_brawl_game_street_scrap.dart';

void main() {
  const generator = StreetScrapSearchVariantGenerator();

  test('the authored coastal scene has eight zones and ten item specs', () {
    final definition = streetScrapCoastalWarehouseSearchScene;

    definition.validate();

    expect(definition.zones, hasLength(8));
    expect(definition.items, hasLength(10));
    expect(
      definition.backgroundResourceId,
      contains('search-coastal-warehouse'),
    );
  });

  test('same seed produces the same variable-size placement layout', () {
    final first = generator.generate(
      streetScrapCoastalWarehouseSearchScene,
      seed: 183921,
    );
    final second = generator.generate(
      streetScrapCoastalWarehouseSearchScene,
      seed: 183921,
    );

    expect(first.toJson(), equals(second.toJson()));
    expect(first.placements.length, inInclusiveRange(5, 20));
    expect(first.placements.any((placement) => placement.isBuried), isTrue);
    expect(
      first.placements.any(
        (placement) =>
            placement.concealment == StreetScrapSearchConcealment.visible,
      ),
      isTrue,
    );
  });

  test(
    'different seeds can change count or placement without changing scene',
    () {
      final first = generator.generate(
        streetScrapCoastalWarehouseSearchScene,
        seed: 1,
      );
      final second = generator.generate(
        streetScrapCoastalWarehouseSearchScene,
        seed: 2,
      );

      expect(second.sceneId, first.sceneId);
      expect(second.placements, isNot(equals(first.placements)));
    },
  );

  test('generated placements stay inside their zones and do not overlap', () {
    final definition = streetScrapCoastalWarehouseSearchScene;
    final variant = generator.generate(definition, seed: 99123);

    for (final placement in variant.placements) {
      final zone = definition.zone(placement.zoneId);
      expect(placement.x, greaterThanOrEqualTo(zone.x));
      expect(placement.y, greaterThanOrEqualTo(zone.y));
      expect(
        placement.x + placement.width,
        lessThanOrEqualTo(zone.x + zone.width),
      );
      expect(
        placement.y + placement.height,
        lessThanOrEqualTo(zone.y + zone.height),
      );
      if (placement.isBuried) expect(placement.requiresTool, 'shovel');
    }

    for (var i = 0; i < variant.placements.length; i += 1) {
      for (var j = i + 1; j < variant.placements.length; j += 1) {
        final a = variant.placements[i];
        final b = variant.placements[j];
        final overlap =
            a.x < b.x + b.width &&
            a.x + a.width > b.x &&
            a.y < b.y + b.height &&
            a.y + a.height > b.y;
        expect(overlap, isFalse, reason: '${a.id} overlaps ${b.id}');
      }
    }
  });

  test('a range of seeds keeps the authored minimum item count', () {
    final definition = streetScrapCoastalWarehouseSearchScene;

    for (var seed = 0; seed < 100; seed += 1) {
      final variant = generator.generate(definition, seed: seed);
      expect(
        variant.placements.length,
        greaterThanOrEqualTo(definition.minimumItems),
        reason: 'seed $seed generated too few search objects',
      );
    }
  });

  test('generated variants survive JSON round trips', () {
    final variant = generator.generate(
      streetScrapCoastalWarehouseSearchScene,
      seed: 22,
    );
    final restored = StreetScrapSearchVariant.fromJson(variant.toJson());

    expect(restored.toJson(), equals(variant.toJson()));
  });
}
