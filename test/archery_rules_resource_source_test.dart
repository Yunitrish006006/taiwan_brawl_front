import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:taiwan_brawl/game_modules/archery_rules_resource_source.dart';
import 'package:taiwan_brawl/services/game_resource_content_store.dart';
import 'package:taiwan_brawl_game_archery/archery_game_module.dart';

class _ActiveContentStore implements GameResourceContentStore {
  String? moduleId;
  String? resourceId;

  @override
  Future<Uint8List?> readActive(String moduleId, String resourceId) async {
    this.moduleId = moduleId;
    this.resourceId = resourceId;
    return Uint8List.fromList(utf8.encode('{"version":"test-pack"}'));
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  test(
    'Archery adapter reads the active package-scoped rules resource',
    () async {
      final store = _ActiveContentStore();
      final source = GameResourceArcheryRulesSource(contentStore: store);

      expect(await source.readActiveRulesJson(), '{"version":"test-pack"}');
      expect(store.moduleId, archeryGameModuleId);
      expect(store.resourceId, archeryRulesResourceId);
    },
  );
}
