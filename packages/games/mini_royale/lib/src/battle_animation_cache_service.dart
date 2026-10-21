import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';

import 'battle_animation_cache_store.dart';
import 'battle_animation_remote_source.dart';
import 'royale_models.dart';

class BattleAnimationCacheService extends ChangeNotifier {
  BattleAnimationCacheService({
    required BattleAnimationCacheStore store,
    required BattleAnimationRemoteSource remoteSource,
  }) : _remoteSource = remoteSource,
       _store = store;

  final BattleAnimationRemoteSource _remoteSource;
  final BattleAnimationCacheStore _store;
  final Set<String> _inFlight = <String>{};
  final Map<String, Uint8List> _memoryBytes = <String, Uint8List>{};

  bool _initialized = false;
  bool _enabled = false;
  bool _disposed = false;
  Future<void>? _initialization;

  bool get enabled => _enabled;

  Future<void> initialize() => _initialization ??= _initialize();

  Future<void> _initialize() async {
    if (_initialized) {
      return;
    }
    await _store.initialize();
    _enabled = await _store.readEnabled();
    _initialized = true;
    if (!_disposed) notifyListeners();
  }

  Future<void> setEnabled(bool value) async {
    await initialize();
    if (_enabled == value) {
      return;
    }
    _enabled = value;
    await _store.writeEnabled(value);
    notifyListeners();
  }

  Uint8List? bytesForAsset(RoyaleCharacterAsset? asset) {
    if (!_enabled || !_initialized || asset == null) {
      return null;
    }
    final cacheKey = _cacheKey(asset);
    final memoryBytes = _memoryBytes[cacheKey];
    if (memoryBytes != null) {
      return memoryBytes;
    }
    final raw = _store.readBytes(cacheKey);
    if (raw == null || raw.isEmpty) {
      return null;
    }
    try {
      final bytes = base64Decode(raw);
      _memoryBytes[cacheKey] = bytes;
      return bytes;
    } catch (_) {
      unawaited(_store.deleteBytes(cacheKey));
      return null;
    }
  }

  Future<void> prefetchForRoom(RoyaleRoomSnapshot? room) async {
    await initialize();
    if (!_enabled || room == null) {
      return;
    }
    await prefetchAssets(_collectRoomAssets(room));
  }

  Future<void> prefetchAssets(Iterable<RoyaleCharacterAsset> assets) async {
    await initialize();
    if (!_enabled) {
      return;
    }

    final uniqueAssets = <String, RoyaleCharacterAsset>{};
    for (final asset in assets) {
      if (!_isCacheable(asset)) {
        continue;
      }
      uniqueAssets[_cacheKey(asset)] = asset;
    }

    for (final asset in uniqueAssets.values) {
      await _prefetchAsset(asset);
    }
  }

  Iterable<RoyaleCharacterAsset> _collectRoomAssets(
    RoyaleRoomSnapshot room,
  ) sync* {
    final viewerSide = room.viewerSide;
    for (final player in room.players) {
      if (player.side != viewerSide && room.simulationMode != 'host') {
        continue;
      }
      for (final card in player.deckCards) {
        yield* card.characterAssets;
      }
    }

    final battle = room.battle;
    if (battle == null) {
      return;
    }
    for (final card in battle.yourHand) {
      yield* card.characterAssets;
    }
    for (final unit in battle.units) {
      yield* unit.characterAssets;
    }
  }

  bool _isCacheable(RoyaleCharacterAsset asset) {
    return asset.assetId.trim().isNotEmpty &&
        asset.cacheIdentity.trim().isNotEmpty &&
        asset.cacheVersion.trim().isNotEmpty &&
        (asset.imageUrl ?? '').trim().isNotEmpty;
  }

  String _cacheKey(RoyaleCharacterAsset asset) {
    return '${asset.cacheIdentity}@${asset.cacheVersion}';
  }

  Future<void> _prefetchAsset(RoyaleCharacterAsset asset) async {
    final cacheKey = _cacheKey(asset);
    if (_store.containsBytes(cacheKey) || _inFlight.contains(cacheKey)) {
      return;
    }

    final url = asset.imageUrl?.trim();
    if (url == null || url.isEmpty) {
      return;
    }

    _inFlight.add(cacheKey);
    try {
      final uri = Uri.tryParse(url);
      if (uri == null) {
        return;
      }

      final downloaded = await _remoteSource.download(uri);
      if (downloaded == null || downloaded.isEmpty) {
        return;
      }

      final oldMeta = _readMeta(asset.cacheIdentity);
      await _store.writeBytes(cacheKey, base64Encode(downloaded));
      _memoryBytes[cacheKey] = downloaded;
      await _store.writeMeta(
        asset.cacheIdentity,
        jsonEncode({
          'cacheKey': cacheKey,
          'version': asset.cacheVersion,
          'assetId': asset.assetId,
          'cardId': asset.cardId,
          'url': url,
          'updatedAt': DateTime.now().toUtc().toIso8601String(),
        }),
      );

      final oldCacheKey = oldMeta?['cacheKey'] as String?;
      if (oldCacheKey != null && oldCacheKey != cacheKey) {
        await _store.deleteBytes(oldCacheKey);
        _memoryBytes.remove(oldCacheKey);
      }
      notifyListeners();
    } catch (error, stackTrace) {
      debugPrint('Battle animation cache preload failed: $error');
      debugPrintStack(stackTrace: stackTrace);
    } finally {
      _inFlight.remove(cacheKey);
    }
  }

  Map<String, dynamic>? _readMeta(String identity) {
    final raw = _store.readMeta(identity);
    if (raw == null || raw.isEmpty) {
      return null;
    }
    try {
      return jsonDecode(raw) as Map<String, dynamic>;
    } catch (_) {
      unawaited(_store.deleteMeta(identity));
      return null;
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _remoteSource.dispose();
    super.dispose();
  }
}
