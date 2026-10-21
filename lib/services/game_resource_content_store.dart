import 'dart:convert';
import 'dart:typed_data';

import 'package:hive_flutter/hive_flutter.dart';

abstract interface class GameResourceContentStore {
  Future<void> writeStaged(
    String moduleId,
    String resourceId,
    String version,
    Uint8List bytes,
  );
  Future<List<Uint8List>> readStagedChunks(
    String moduleId,
    String resourceId,
    String version,
  );
  Future<void> writeStagedChunk(
    String moduleId,
    String resourceId,
    String version,
    int index,
    Uint8List bytes,
  );

  Future<void> activate(String moduleId, String resourceId, String version);
  Future<void> activateSet(String moduleId, Map<String, String> versions);

  Future<Uint8List?> readActive(String moduleId, String resourceId);
  Future<String?> readActiveVersion(String moduleId, String resourceId);
  Future<Map<String, String>> readActiveSet(String moduleId);
  Future<void> restoreActiveVersion(
    String moduleId,
    String resourceId,
    String? version,
  );
  Future<void> restoreActiveSet(String moduleId, Map<String, String> versions);
  Future<void> discardStaged(
    String moduleId,
    String resourceId,
    String version,
  );
  Future<void> remove(String moduleId, String resourceId);
  Future<void> removeSet(String moduleId, List<String> resourceIds);
}

/// Hive-backed, platform-neutral content cache. Versioned payloads are written
/// before the active-version pointer changes, preserving the old version if an
/// update is interrupted.
class HiveGameResourceContentStore implements GameResourceContentStore {
  HiveGameResourceContentStore({
    this.contentBoxName = 'game_resource_content_v1',
    this.pointerBoxName = 'game_resource_pointers_v1',
  });

  final String contentBoxName;
  final String pointerBoxName;

  Future<Box<Uint8List>> _contentBox() =>
      Hive.openBox<Uint8List>(contentBoxName);

  Future<Box<String>> _pointerBox() => Hive.openBox<String>(pointerBoxName);

  @override
  Future<void> writeStaged(
    String moduleId,
    String resourceId,
    String version,
    Uint8List bytes,
  ) async {
    final box = await _contentBox();
    await box.put(_completeStagedKey(moduleId, resourceId, version), bytes);
  }

  @override
  Future<List<Uint8List>> readStagedChunks(
    String moduleId,
    String resourceId,
    String version,
  ) async {
    final box = await _contentBox();
    final prefix = _chunkPrefix(moduleId, resourceId, version);
    final entries = <(int, Uint8List)>[];
    for (final key in box.keys.whereType<String>()) {
      if (!key.startsWith(prefix)) continue;
      final index = int.tryParse(key.substring(prefix.length));
      final bytes = box.get(key);
      if (index == null || bytes == null) continue;
      entries.add((index, Uint8List.fromList(bytes)));
    }
    entries.sort((a, b) => a.$1.compareTo(b.$1));
    for (var index = 0; index < entries.length; index++) {
      if (entries[index].$1 != index) {
        throw StateError('Staged resource chunks are not contiguous.');
      }
    }
    return entries.map((entry) => entry.$2).toList(growable: false);
  }

  @override
  Future<void> writeStagedChunk(
    String moduleId,
    String resourceId,
    String version,
    int index,
    Uint8List bytes,
  ) async {
    if (index < 0) throw ArgumentError.value(index, 'index');
    final box = await _contentBox();
    await box.put(
      '${_chunkPrefix(moduleId, resourceId, version)}$index',
      bytes,
    );
  }

  @override
  Future<void> activate(
    String moduleId,
    String resourceId,
    String version,
  ) async {
    final versions = await readActiveSet(moduleId);
    versions[resourceId] = version;
    await activateSet(moduleId, versions);
  }

  @override
  Future<void> activateSet(
    String moduleId,
    Map<String, String> versions,
  ) async {
    final contents = await _contentBox();
    for (final entry in versions.entries) {
      final stagedKey = _completeStagedKey(moduleId, entry.key, entry.value);
      final staged = contents.get(stagedKey);
      if (staged != null) {
        await contents.put(
          _versionKey(moduleId, entry.key, entry.value),
          staged,
        );
      } else if (!contents.containsKey(
        _versionKey(moduleId, entry.key, entry.value),
      )) {
        throw StateError(
          'No staged or cached resource payload exists for ${entry.key}@${entry.value}.',
        );
      }
    }
    // One pointer value is the commit record for the entire content set.
    final pointers = await _pointerBox();
    await pointers.put(_activeSetKey(moduleId), jsonEncode(versions));
    for (final entry in versions.entries) {
      await discardStaged(moduleId, entry.key, entry.value);
    }
  }

  @override
  Future<Uint8List?> readActive(String moduleId, String resourceId) async {
    final version = await readActiveVersion(moduleId, resourceId);
    if (version == null) return null;
    final contents = await _contentBox();
    final bytes = contents.get(_versionKey(moduleId, resourceId, version));
    return bytes == null ? null : Uint8List.fromList(bytes);
  }

  @override
  Future<String?> readActiveVersion(String moduleId, String resourceId) async {
    return (await readActiveSet(moduleId))[resourceId];
  }

  @override
  Future<Map<String, String>> readActiveSet(String moduleId) async {
    final pointers = await _pointerBox();
    final encodedSet = pointers.get(_activeSetKey(moduleId));
    if (encodedSet != null) {
      final decoded = jsonDecode(encodedSet);
      if (decoded is! Map) {
        throw const FormatException('Invalid active resource set.');
      }
      return {
        for (final entry in decoded.entries)
          if (entry.key is String && entry.value is String)
            entry.key as String: entry.value as String,
      };
    }
    // Read the legacy per-resource pointer keys during the local schema
    // transition; the next activation writes the consolidated set key.
    final prefix = 'active:$moduleId:';
    return {
      for (final key in pointers.keys.whereType<String>())
        if (key.startsWith(prefix) && pointers.get(key) != null)
          key.substring(prefix.length): pointers.get(key)!,
    };
  }

  @override
  Future<void> restoreActiveVersion(
    String moduleId,
    String resourceId,
    String? version,
  ) async {
    final versions = await readActiveSet(moduleId);
    if (version == null) {
      versions.remove(resourceId);
      await restoreActiveSet(moduleId, versions);
    } else {
      versions[resourceId] = version;
      await restoreActiveSet(moduleId, versions);
    }
  }

  @override
  Future<void> restoreActiveSet(
    String moduleId,
    Map<String, String> versions,
  ) async {
    final contents = await _contentBox();
    for (final entry in versions.entries) {
      if (!contents.containsKey(
        _versionKey(moduleId, entry.key, entry.value),
      )) {
        throw StateError(
          'Cannot restore uncached resource ${entry.key}@${entry.value}.',
        );
      }
    }
    final pointers = await _pointerBox();
    await pointers.put(_activeSetKey(moduleId), jsonEncode(versions));
  }

  @override
  Future<void> discardStaged(
    String moduleId,
    String resourceId,
    String version,
  ) async {
    final contents = await _contentBox();
    final prefix = _stagePrefix(moduleId, resourceId, version);
    for (final key in contents.keys.whereType<String>().toList()) {
      if (key.startsWith(prefix)) await contents.delete(key);
    }
  }

  @override
  Future<void> remove(String moduleId, String resourceId) async {
    await removeSet(moduleId, [resourceId]);
  }

  @override
  Future<void> removeSet(String moduleId, List<String> resourceIds) async {
    if (resourceIds.toSet().length != resourceIds.length) {
      throw ArgumentError('Resource removal set contains duplicate IDs.');
    }
    final active = await readActiveSet(moduleId)
      ..removeWhere((resourceId, _) => resourceIds.contains(resourceId));
    await restoreActiveSet(moduleId, active);
    final contents = await _contentBox();
    for (final resourceId in resourceIds) {
      final prefix = 'pack:$moduleId:$resourceId:';
      for (final key in contents.keys.whereType<String>().toList()) {
        if (key.startsWith(prefix) ||
            key.startsWith('stage:$moduleId:$resourceId:')) {
          await contents.delete(key);
        }
      }
    }
  }

  String _activeSetKey(String moduleId) => 'active-set:$moduleId';

  String _stagePrefix(String moduleId, String resourceId, String version) =>
      'stage:$moduleId:$resourceId:$version:';

  String _completeStagedKey(
    String moduleId,
    String resourceId,
    String version,
  ) => '${_stagePrefix(moduleId, resourceId, version)}complete';

  String _chunkPrefix(String moduleId, String resourceId, String version) =>
      '${_stagePrefix(moduleId, resourceId, version)}chunk:';

  String _versionKey(String moduleId, String resourceId, String version) =>
      'pack:$moduleId:$resourceId:$version';
}
