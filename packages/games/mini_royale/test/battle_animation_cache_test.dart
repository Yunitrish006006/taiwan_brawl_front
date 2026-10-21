import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:taiwan_brawl_game_mini_royale/taiwan_brawl_game_mini_royale.dart';

class _Remote implements BattleAnimationRemoteSource {
  @override
  Future<Uint8List?> download(Uri uri) async => Uint8List.fromList([3, 4, 5]);

  @override
  void dispose() {}
}

void main() {
  test(
    'concurrent initialization restores settings once and notifies views',
    () async {
      final store = _MemoryStore()..enabled = true;
      final service = BattleAnimationCacheService(
        store: store,
        remoteSource: _Remote(),
      );
      var notifications = 0;
      service.addListener(() => notifications++);

      await Future.wait([service.initialize(), service.initialize()]);

      expect(store.initializeCount, 1);
      expect(service.enabled, isTrue);
      expect(notifications, 1);
      service.dispose();
    },
  );

  test('package cache stores a prefetched game asset', () async {
    final store = _MemoryStore();
    final service = BattleAnimationCacheService(
      store: store,
      remoteSource: _Remote(),
    );
    await service.setEnabled(true);
    final asset = RoyaleCharacterAsset(
      assetId: 'asset',
      animation: 'idle',
      direction: 'front',
      frameIndex: 0,
      durationMs: 100,
      loop: true,
      imageUrl: 'https://example.test/asset.png',
      assetVersion: 'version-2',
    );

    await service.prefetchAssets([asset]);

    expect(service.bytesForAsset(asset), orderedEquals([3, 4, 5]));
    service.dispose();
  });
}

class _MemoryStore implements BattleAnimationCacheStore {
  bool enabled = false;
  int initializeCount = 0;
  final Map<String, String> bytes = {};
  final Map<String, String> meta = {};

  @override
  Future<void> initialize() async {
    initializeCount++;
  }

  @override
  Future<bool> readEnabled() async => enabled;
  @override
  Future<void> writeEnabled(bool value) async => enabled = value;
  @override
  bool containsBytes(String cacheKey) => bytes.containsKey(cacheKey);
  @override
  String? readBytes(String cacheKey) => bytes[cacheKey];
  @override
  Future<void> writeBytes(String cacheKey, String encodedBytes) async {
    bytes[cacheKey] = encodedBytes;
  }

  @override
  Future<void> deleteBytes(String cacheKey) async => bytes.remove(cacheKey);
  @override
  String? readMeta(String identity) => meta[identity];
  @override
  Future<void> writeMeta(String identity, String encodedMeta) async {
    meta[identity] = encodedMeta;
  }

  @override
  Future<void> deleteMeta(String identity) async => meta.remove(identity);
}
