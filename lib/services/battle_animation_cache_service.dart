import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:http/http.dart' as http;

import '../models/royale_models.dart';
import 'http_client_factory.dart';

class BattleAnimationCacheService extends ChangeNotifier {
  BattleAnimationCacheService({http.Client? client})
    : _client = client ?? createHttpClient();

  static const String _settingsBoxName = 'battle_animation_cache_settings';
  static const String _metaBoxName = 'battle_animation_cache_meta';
  static const String _bytesBoxName = 'battle_animation_cache_bytes';
  static const String _enabledKey = 'enabled';

  final http.Client _client;
  final Set<String> _inFlight = <String>{};
  final Map<String, Uint8List> _memoryBytes = <String, Uint8List>{};

  late final Box<dynamic> _settingsBox;
  late final Box<String> _metaBox;
  late final Box<String> _bytesBox;
  bool _initialized = false;
  bool _enabled = false;

  bool get enabled => _enabled;

  Future<void> initialize() async {
    if (_initialized) {
      return;
    }
    _settingsBox = await Hive.openBox<dynamic>(_settingsBoxName);
    _metaBox = await Hive.openBox<String>(_metaBoxName);
    _bytesBox = await Hive.openBox<String>(_bytesBoxName);
    _enabled = _settingsBox.get(_enabledKey) == true;
    _initialized = true;
  }

  Future<void> setEnabled(bool value) async {
    await initialize();
    if (_enabled == value) {
      return;
    }
    _enabled = value;
    await _settingsBox.put(_enabledKey, value);
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
    final raw = _bytesBox.get(cacheKey);
    if (raw == null || raw.isEmpty) {
      return null;
    }
    try {
      final bytes = base64Decode(raw);
      _memoryBytes[cacheKey] = bytes;
      return bytes;
    } catch (_) {
      unawaited(_bytesBox.delete(cacheKey));
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
    if (_bytesBox.containsKey(cacheKey) || _inFlight.contains(cacheKey)) {
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

      final response = await _client
          .get(uri)
          .timeout(const Duration(seconds: 20));
      if (response.statusCode < 200 ||
          response.statusCode >= 300 ||
          response.bodyBytes.isEmpty) {
        return;
      }

      final oldMeta = _readMeta(asset.cacheIdentity);
      await _bytesBox.put(cacheKey, base64Encode(response.bodyBytes));
      _memoryBytes[cacheKey] = Uint8List.fromList(response.bodyBytes);
      await _metaBox.put(
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
        await _bytesBox.delete(oldCacheKey);
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
    final raw = _metaBox.get(identity);
    if (raw == null || raw.isEmpty) {
      return null;
    }
    try {
      return jsonDecode(raw) as Map<String, dynamic>;
    } catch (_) {
      unawaited(_metaBox.delete(identity));
      return null;
    }
  }

  @override
  void dispose() {
    _client.close();
    super.dispose();
  }
}
