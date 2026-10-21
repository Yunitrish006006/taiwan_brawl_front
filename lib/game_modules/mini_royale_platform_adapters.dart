import 'dart:typed_data';

import 'package:hive_flutter/hive_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:taiwan_brawl_game_mini_royale/taiwan_brawl_game_mini_royale.dart'
    as mini_royale;

/// Host-owned Hive adapter for game-owned, versioned player data.
class HiveMiniRoyalePlayerDataBackend
    implements mini_royale.MiniRoyalePlayerDataBackend {
  HiveMiniRoyalePlayerDataBackend({
    this.boxName = 'mini_royale_player_data_v1',
  });

  final String boxName;
  Future<Box<dynamic>>? _boxFuture;

  Future<Box<dynamic>> get _box =>
      _boxFuture ??= Hive.openBox<dynamic>(boxName);

  @override
  Future<Object?> read(String key) async => (await _box).get(key);

  @override
  Future<void> write(String key, Object value) async {
    await (await _box).put(key, value);
  }

  @override
  Future<void> delete(String key) async {
    await (await _box).delete(key);
  }
}

/// Host-owned persistent adapter; box IDs preserve existing user caches.
class HiveBattleAnimationCacheStore
    implements mini_royale.BattleAnimationCacheStore {
  static const _enabledKey = 'enabled';

  late final Box<dynamic> _settingsBox;
  late final Box<String> _metaBox;
  late final Box<String> _bytesBox;

  @override
  Future<void> initialize() async {
    _settingsBox = await Hive.openBox<dynamic>(
      'battle_animation_cache_settings',
    );
    _metaBox = await Hive.openBox<String>('battle_animation_cache_meta');
    _bytesBox = await Hive.openBox<String>('battle_animation_cache_bytes');
  }

  @override
  Future<bool> readEnabled() async => _settingsBox.get(_enabledKey) == true;

  @override
  Future<void> writeEnabled(bool value) async {
    await _settingsBox.put(_enabledKey, value);
  }

  @override
  bool containsBytes(String cacheKey) => _bytesBox.containsKey(cacheKey);

  @override
  String? readBytes(String cacheKey) => _bytesBox.get(cacheKey);

  @override
  Future<void> writeBytes(String cacheKey, String encodedBytes) async {
    await _bytesBox.put(cacheKey, encodedBytes);
  }

  @override
  Future<void> deleteBytes(String cacheKey) async {
    await _bytesBox.delete(cacheKey);
  }

  @override
  String? readMeta(String identity) => _metaBox.get(identity);

  @override
  Future<void> writeMeta(String identity, String encodedMeta) async {
    await _metaBox.put(identity, encodedMeta);
  }

  @override
  Future<void> deleteMeta(String identity) async {
    await _metaBox.delete(identity);
  }
}

/// HTTP adapter for the game's transport-neutral asset download port.
class HttpBattleAnimationRemoteSource
    implements mini_royale.BattleAnimationRemoteSource {
  HttpBattleAnimationRemoteSource({http.Client? client})
    : _client = client ?? http.Client();

  final http.Client _client;

  @override
  Future<Uint8List?> download(Uri uri) async {
    final response = await _client
        .get(uri)
        .timeout(const Duration(seconds: 20));
    if (response.statusCode < 200 ||
        response.statusCode >= 300 ||
        response.bodyBytes.isEmpty) {
      return null;
    }
    return Uint8List.fromList(response.bodyBytes);
  }

  @override
  void dispose() => _client.close();
}
