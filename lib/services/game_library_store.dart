import 'dart:convert';

import 'package:hive_flutter/hive_flutter.dart';

import '../game_modules/game_module_manifest.dart';

abstract interface class GameLibraryStore {
  Future<Set<String>> readEnabledModuleIds();
  Future<void> writeEnabledModuleIds(Set<String> moduleIds);
  Future<Map<String, GameResourceInstallRecord>> readResourceRecords();
  Future<void> writeResourceRecord(GameResourceInstallRecord record);
  Future<void> removeResourceRecord(String moduleId, String resourceId);
}

/// Optional capability for stores that persist offline resource-catalog state.
/// Download metadata comes from a publisher-verified snapshot; installed
/// resources withdrawn from that snapshot are retained as non-downloadable
/// local entries for offline inspection and removal.
abstract interface class CachedGameResourceCatalogStore {
  Future<CachedGameResourceCatalog?> readCachedResourceCatalog();
  Future<void> writeCachedResourceCatalog(CachedGameResourceCatalog catalog);
}

class CachedGameResourceCatalog {
  const CachedGameResourceCatalog({
    required this.manifests,
    this.issuedAt,
    this.expiresAt,
    this.signedEnvelope,
  });
  final List<GameModuleManifest> manifests;
  final DateTime? issuedAt;
  final DateTime? expiresAt;
  final Map<String, dynamic>? signedEnvelope;
}

class HiveGameLibraryStore
    implements GameLibraryStore, CachedGameResourceCatalogStore {
  HiveGameLibraryStore({this.boxName = 'game_library_v1'});

  final String boxName;
  Future<Box<String>> _open() => Hive.openBox<String>(boxName);

  @override
  Future<Set<String>> readEnabledModuleIds() async {
    final box = await _open();
    final encoded = box.get('enabled_modules');
    if (encoded == null) return <String>{};
    final values = (jsonDecode(encoded) as List).cast<String>();
    return values.toSet();
  }

  @override
  Future<void> writeEnabledModuleIds(Set<String> moduleIds) async {
    final box = await _open();
    await box.put('enabled_modules', jsonEncode(moduleIds.toList()..sort()));
  }

  @override
  Future<Map<String, GameResourceInstallRecord>> readResourceRecords() async {
    final box = await _open();
    final records = <String, GameResourceInstallRecord>{};
    for (final key in box.keys.whereType<String>()) {
      if (!key.startsWith('resource:')) continue;
      try {
        final decoded = jsonDecode(box.get(key)!);
        if (decoded is! Map) continue;
        final json = Map<String, Object?>.from(decoded);
        final record = GameResourceInstallRecord.fromJson(json);
        records['${record.moduleId}:${record.resourceId}'] = record;
      } on Object {
        // A corrupt resource row is isolated; other modules remain available.
        continue;
      }
    }
    return records;
  }

  @override
  Future<void> writeResourceRecord(GameResourceInstallRecord record) async {
    final box = await _open();
    await box.put(
      _resourceKey(record.moduleId, record.resourceId),
      jsonEncode(record.toJson()),
    );
  }

  @override
  Future<void> removeResourceRecord(String moduleId, String resourceId) async {
    final box = await _open();
    await box.delete(_resourceKey(moduleId, resourceId));
  }

  @override
  Future<CachedGameResourceCatalog?> readCachedResourceCatalog() async {
    final box = await _open();
    final encoded = box.get('resource_catalog');
    if (encoded == null) return null;
    try {
      final decoded = jsonDecode(encoded);
      // Read the pre-expiry cache format for offline inspection only. Its
      // missing expiry deliberately prevents it from authorizing downloads.
      if (decoded is List) {
        return CachedGameResourceCatalog(
          manifests: [
            for (final item in decoded)
              if (item is Map)
                GameModuleManifest.fromJson(Map<String, dynamic>.from(item)),
          ],
        );
      }
      if (decoded is! Map) return null;
      final json = Map<String, dynamic>.from(decoded);
      final modules = json['manifests'];
      if (modules is! List) return null;
      final expiresAtRaw = json['expiresAt'];
      final expiresAt = expiresAtRaw is String
          ? DateTime.tryParse(expiresAtRaw)?.toUtc()
          : null;
      final issuedAtRaw = json['issuedAt'];
      final issuedAt = issuedAtRaw is String
          ? DateTime.tryParse(issuedAtRaw)?.toUtc()
          : null;
      final signedEnvelopeRaw = json['signedEnvelope'];
      Map<String, dynamic>? signedEnvelope;
      if (signedEnvelopeRaw is Map) {
        try {
          signedEnvelope = Map<String, dynamic>.from(signedEnvelopeRaw);
        } on Object {
          // Ignore malformed publisher metadata but keep local tombstones.
        }
      }
      final manifests = <GameModuleManifest>[];
      for (final item in modules) {
        if (item is! Map) continue;
        try {
          manifests.add(
            GameModuleManifest.fromJson(Map<String, dynamic>.from(item)),
          );
        } on Object {
          // Isolate one corrupt cached module; installed state remains separate.
          continue;
        }
      }
      return CachedGameResourceCatalog(
        issuedAt: issuedAtRaw is String && issuedAt == null ? null : issuedAt,
        expiresAt: expiresAtRaw is String && expiresAt == null
            ? null
            : expiresAt,
        signedEnvelope: signedEnvelope,
        manifests: manifests,
      );
    } on Object {
      // A bad cache is ignored; the bundled catalog remains usable offline.
      return null;
    }
  }

  @override
  Future<void> writeCachedResourceCatalog(
    CachedGameResourceCatalog catalog,
  ) async {
    final box = await _open();
    await box.put(
      'resource_catalog',
      jsonEncode({
        'expiresAt': catalog.expiresAt?.toUtc().toIso8601String(),
        'issuedAt': catalog.issuedAt?.toUtc().toIso8601String(),
        'signedEnvelope': catalog.signedEnvelope,
        'manifests': catalog.manifests
            .map((manifest) => manifest.toJson())
            .toList(),
      }),
    );
  }

  String _resourceKey(String moduleId, String resourceId) =>
      'resource:$moduleId:$resourceId';
}
