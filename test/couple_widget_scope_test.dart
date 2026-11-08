@TestOn('vm')
library;

import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:taiwan_brawl/services/couple_widget_controller.dart';

void main() {
  test(
    'opaque scopes remain stable across storage reopen and differ by account',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'couple-widget-scope-',
      );
      Hive.init(directory.path);
      try {
        final first = await persistentCoupleWidgetScope(123);
        final second = await persistentCoupleWidgetScope(456);
        expect(first, matches(RegExp(r'^[a-f0-9]{64}$')));
        expect(first, isNot(second));
        await Hive.close();
        expect(await persistentCoupleWidgetScope(123), first);
      } finally {
        await Hive.close();
        await directory.delete(recursive: true);
      }
    },
  );
}
