@TestOn('vm')
library;

import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:taiwan_brawl/services/couples_cache.dart';

void main() {
  test('Hive closes and reopens account-scoped snapshots', () async {
    final directory = await Directory.systemTemp.createTemp(
      'couples-cache-test-',
    );
    try {
      Hive.init(directory.path);
      final cache = HiveCouplesCache(boxName: 'couples_test');
      await cache.write(1, {
        'ok': true,
        'data': {'partner': 2},
      });
      await cache.write(2, {
        'ok': true,
        'data': {'partner': 3},
      });
      await Hive.close();
      Hive.init(directory.path);
      final restored = HiveCouplesCache(boxName: 'couples_test');
      expect((await restored.read(1))!['data']['partner'], 2);
      expect((await restored.read(2))!['data']['partner'], 3);
      await restored.remove(1);
      expect(await restored.read(1), isNull);
      expect((await restored.read(2))!['data']['partner'], 3);
    } finally {
      await Hive.close();
      await directory.delete(recursive: true);
    }
  });
}
