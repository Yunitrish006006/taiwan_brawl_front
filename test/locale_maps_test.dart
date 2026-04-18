import 'package:flutter_test/flutter_test.dart';

import 'package:taiwan_brawl/constants/locale_catalog.dart';

void main() {
  test('all locale maps expose the same translation keys', () {
    final entries = localeCatalog.entries.toList();
    final baselineKeys = entries.first.value.keys.toSet();

    for (final entry in entries.skip(1)) {
      expect(
        entry.value.keys.toSet(),
        baselineKeys,
        reason: 'Locale ${entry.key} is missing or adding translation keys.',
      );
    }
  });

  test('unknown locale falls back to default locale map', () {
    expect(
      identical(
        translationForLocale('missing-locale'),
        localeCatalog[defaultLocaleCode],
      ),
      isTrue,
    );
  });
}
