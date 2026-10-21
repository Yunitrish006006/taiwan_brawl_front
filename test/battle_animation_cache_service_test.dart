import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'package:taiwan_brawl_game_mini_royale/taiwan_brawl_game_mini_royale.dart';

void main() {
  test('uses the replaceable cache store for settings and bytes', () async {
    final store = MemoryBattleAnimationCacheStore();
    final service = BattleAnimationCacheService(
      store: store,
      remoteSource: _Remote(),
    );

    await service.initialize();
    expect(service.enabled, isFalse);

    await service.setEnabled(true);
    expect(store.enabled, isTrue);

    final asset = RoyaleCharacterAsset(
      assetId: 'knight-idle',
      animation: 'idle',
      direction: 'front',
      frameIndex: 0,
      durationMs: 120,
      loop: true,
      imageUrl: 'https://example.com/knight.png?v=1',
    );
    store.bytes['${asset.cacheIdentity}@${asset.cacheVersion}'] = 'AAE=';

    expect(service.bytesForAsset(asset), orderedEquals(<int>[0, 1]));
    service.dispose();
  });
}

class _Remote implements BattleAnimationRemoteSource {
  @override
  Future<Uint8List?> download(Uri uri) async => null;
  @override
  void dispose() {}
}

class MemoryBattleAnimationCacheStore implements BattleAnimationCacheStore {
  bool enabled = false;
  final Map<String, String> bytes = <String, String>{};
  final Map<String, String> meta = <String, String>{};

  @override
  Future<void> initialize() async {}

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
