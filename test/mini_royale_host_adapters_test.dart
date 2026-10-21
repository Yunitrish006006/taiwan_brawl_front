import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:taiwan_brawl/game_modules/mini_royale_platform_adapters.dart';
import 'package:taiwan_brawl_game_mini_royale/taiwan_brawl_game_mini_royale.dart';

class _Remote implements BattleAnimationRemoteSource {
  @override
  Future<Uint8List?> download(Uri uri) async => Uint8List.fromList([3, 4, 5]);

  @override
  void dispose() {}
}

void main() {
  late Directory directory;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('mini-royale-host-');
    Hive.init(directory.path);
  });

  tearDown(() async {
    await Hive.close();
    await directory.delete(recursive: true);
  });

  test(
    'host Hive adapter preserves existing game-owned animation cache IDs',
    () async {
      final settings = await Hive.openBox<dynamic>(
        'battle_animation_cache_settings',
      );
      final bytes = await Hive.openBox<String>('battle_animation_cache_bytes');
      await settings.put('enabled', true);
      await bytes.put('/asset.png:asset@version-1', 'AQID');

      final service = BattleAnimationCacheService(
        store: HiveBattleAnimationCacheStore(),
        remoteSource: _Remote(),
      );
      await service.initialize();
      final asset = RoyaleCharacterAsset(
        assetId: 'asset',
        animation: 'idle',
        direction: 'front',
        frameIndex: 0,
        durationMs: 100,
        loop: true,
        imageUrl: 'https://example.test/asset.png?v=version-1',
      );

      expect(service.enabled, isTrue);
      expect(service.bytesForAsset(asset), orderedEquals([1, 2, 3]));
      service.dispose();
    },
  );
}
