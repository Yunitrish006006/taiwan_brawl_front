@TestOn('browser')
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:taiwan_brawl/services/device_time_zone.dart';

void main() {
  test('browser returns its resolved timezone without a platform channel', () async {
    final zone = await deviceTimeZone();
    expect(zone, isNotEmpty);
    expect(zone, isNot(contains(' ')));
  });
}
