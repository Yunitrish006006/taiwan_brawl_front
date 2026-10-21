import 'dart:async';

import 'package:flutter/foundation.dart';

import '../game_modules/game_module_manifest.dart';
import 'game_library_store.dart';
import 'game_resource_catalog_source.dart';

typedef CachedGameCatalogVerifier =
    Future<GameResourceCatalogSnapshot> Function(Map<String, dynamic> envelope);

class GameLibraryController extends ChangeNotifier {
  GameLibraryController({
    required GameModuleCatalog catalog,
    required this.store,
    DateTime Function()? clock,
    this.cachedCatalogVerifier,
  }) : _catalog = catalog,
       _clock = clock ?? DateTime.now;

  GameModuleCatalog _catalog;
  GameModuleCatalog get catalog => _catalog;
  final GameLibraryStore store;
  final CachedGameCatalogVerifier? cachedCatalogVerifier;
  final DateTime Function() _clock;
  DateTime? _remoteCatalogExpiresAt;
  DateTime? _remoteCatalogIssuedAt;
  bool _hasLoadedRemoteCatalog = false;
  Timer? _catalogExpiryTimer;
  DateTime? get remoteCatalogExpiresAt => _remoteCatalogExpiresAt;
  DateTime? get remoteCatalogIssuedAt => _remoteCatalogIssuedAt;
  bool get canInstallRemoteResources =>
      !_hasLoadedRemoteCatalog ||
      (_remoteCatalogExpiresAt != null &&
          _remoteCatalogExpiresAt!.isAfter(_clock().toUtc()));
  Set<String> _enabledModuleIds = <String>{};
  Map<String, GameResourceInstallRecord> _resourceRecords = {};
  bool _initialized = false;

  bool get isInitialized => _initialized;
  Set<String> get enabledModuleIds => Set.unmodifiable(_enabledModuleIds);
  List<GameModuleManifest> get manifests => _catalog.manifests;

  void mergeRemoteManifests(Iterable<GameModuleManifest> remoteManifests) {
    _mergeRemoteManifests(remoteManifests, notify: true);
  }

  void _mergeRemoteManifests(
    Iterable<GameModuleManifest> remoteManifests, {
    required bool notify,
  }) {
    final bundledById = {
      for (final item in _catalog.manifests) item.moduleId: item,
    };
    for (final remote in remoteManifests) {
      final bundled = bundledById[remote.moduleId];
      if (bundled == null) {
        throw FormatException(
          'Catalog references unknown game code: ${remote.moduleId}',
        );
      }
      final remoteResourceIds = remote.resources
          .map((resource) => resource.resourceId)
          .toSet();
      for (final resource in remote.resources) {
        final declaredSchema = resource.payloadSchemaVersion;
        if (declaredSchema != null &&
            bundled.supportedResourceSchemas[resource.resourceId] !=
                declaredSchema) {
          throw FormatException(
            'Unsupported payload schema $declaredSchema for '
            '${resource.resourceId} in ${bundled.moduleId}.',
          );
        }
      }
      final retainedLocalResources = bundled.resources
          .map(
            (resource) => MapEntry(
              resource,
              resourceRecord(bundled.moduleId, resource.resourceId),
            ),
          )
          .where((entry) {
            final record = entry.value;
            return !remoteResourceIds.contains(entry.key.resourceId) &&
                (record?.status == GameResourceInstallStatus.installed ||
                    record?.status == GameResourceInstallStatus.removing);
          })
          // Withdrawn packs remain visible for inspection/removal, but their
          // old download metadata must never authorize a new install/update.
          .map(
            (entry) => GameResourceManifest.fromJson({
              ...entry.key.toJson(),
              'version': entry.value!.version,
              'sha256': entry.value!.sha256,
              'downloadUrl': null,
              'byteLength': null,
              'signature': null,
              'signingKeyId': null,
            }),
          )
          .toList(growable: false);
      bundledById[remote.moduleId] = GameModuleManifest(
        // Game code identity and compatibility are bundled with the App.
        // The remote catalog may publish only downloadable resource metadata.
        moduleId: bundled.moduleId,
        displayName: bundled.displayName,
        description: bundled.description,
        manifestVersion: bundled.manifestVersion,
        kind: bundled.kind,
        publisher: bundled.publisher,
        packageVersion: bundled.packageVersion,
        minimumShellVersion: bundled.minimumShellVersion,
        hostApiRange: bundled.hostApiRange,
        dataSchemaVersion: bundled.dataSchemaVersion,
        dependencies: bundled.dependencies,
        platforms: bundled.platforms,
        multiplayer: bundled.multiplayer,
        supportedResourceSchemas: bundled.supportedResourceSchemas,
        resources: [...remote.resources, ...retainedLocalResources],
      );
    }
    _catalog = GameModuleCatalog(bundledById.values);
    if (notify) notifyListeners();
  }

  /// Replaces the remote resource metadata with one complete, verified
  /// publisher snapshot. Omitted modules/resources lose download metadata;
  /// installed payloads remain visible for inspection and removal.
  void replaceRemoteManifests(
    Iterable<GameModuleManifest> remoteManifests, {
    DateTime? issuedAt,
    DateTime? expiresAt,
  }) {
    final normalizedIssuedAt = issuedAt?.toUtc();
    if (normalizedIssuedAt != null &&
        _remoteCatalogIssuedAt != null &&
        normalizedIssuedAt.isBefore(_remoteCatalogIssuedAt!)) {
      throw const FormatException(
        'Refusing to replace the game catalog with an older signed snapshot.',
      );
    }
    final remoteById = {
      for (final manifest in remoteManifests) manifest.moduleId: manifest,
    };
    final bundledIds = _catalog.manifests
        .map((manifest) => manifest.moduleId)
        .toSet();
    final unknown = remoteById.keys.where(
      (moduleId) => !bundledIds.contains(moduleId),
    );
    if (unknown.isNotEmpty) {
      throw FormatException(
        'Catalog references unknown game code: ${unknown.first}',
      );
    }

    _mergeRemoteManifests([
      for (final current in _catalog.manifests)
        remoteById[current.moduleId] ??
            GameModuleManifest(
              moduleId: current.moduleId,
              displayName: current.displayName,
              description: current.description,
              manifestVersion: current.manifestVersion,
              kind: current.kind,
              publisher: current.publisher,
              packageVersion: current.packageVersion,
              minimumShellVersion: current.minimumShellVersion,
              hostApiRange: current.hostApiRange,
              dataSchemaVersion: current.dataSchemaVersion,
              dependencies: current.dependencies,
              multiplayer: current.multiplayer,
              supportedResourceSchemas: current.supportedResourceSchemas,
              platforms: current.platforms,
              resources: const [],
            ),
    ], notify: false);
    _remoteCatalogExpiresAt = expiresAt?.toUtc();
    _remoteCatalogIssuedAt = normalizedIssuedAt;
    _hasLoadedRemoteCatalog = true;
    _scheduleCatalogExpiryNotification();
    notifyListeners();
  }

  void _scheduleCatalogExpiryNotification() {
    _catalogExpiryTimer?.cancel();
    final expiresAt = _remoteCatalogExpiresAt;
    if (expiresAt == null) return;
    final delay = expiresAt.difference(_clock().toUtc());
    if (delay <= Duration.zero) return;
    _catalogExpiryTimer = Timer(delay, () {
      _catalogExpiryTimer = null;
      notifyListeners();
    });
  }

  @override
  void dispose() {
    _catalogExpiryTimer?.cancel();
    super.dispose();
  }

  bool isModuleEnabled(String moduleId) => _enabledModuleIds.contains(moduleId);

  GameResourceInstallRecord? resourceRecord(
    String moduleId,
    String resourceId,
  ) => _resourceRecords['$moduleId:$resourceId'];

  bool isResourceUpdateAvailable(
    String moduleId,
    GameResourceManifest catalogResource,
  ) {
    final installed = resourceRecord(moduleId, catalogResource.resourceId);
    return installed?.status == GameResourceInstallStatus.installed &&
        (installed?.version != catalogResource.version ||
            installed?.sha256.toLowerCase() !=
                catalogResource.sha256.toLowerCase());
  }

  Future<void> initialize() async {
    _enabledModuleIds = await store.readEnabledModuleIds();
    _resourceRecords = await store.readResourceRecords();
    try {
      final localStore = store;
      if (localStore is CachedGameResourceCatalogStore) {
        final cachedCatalog =
            await (localStore as CachedGameResourceCatalogStore)
                .readCachedResourceCatalog();
        if (cachedCatalog != null) {
          var restoredFromSignedEnvelope = false;
          final envelope = cachedCatalog.signedEnvelope;
          final verifier = cachedCatalogVerifier;
          if (envelope != null && verifier != null) {
            try {
              final snapshot = await verifier(envelope);
              if (snapshot.isPublisherVerified) {
                replaceRemoteManifests(
                  snapshot.manifests,
                  issuedAt: snapshot.issuedAt,
                  expiresAt: snapshot.expiresAt,
                );
                restoredFromSignedEnvelope = true;
              }
            } on Object {
              // An invalid or unknown cached signature grants no download
              // authority; installed tombstones are restored separately.
            }
          }
          if (!restoredFromSignedEnvelope) {
            // Older cache formats and unknown/invalid publisher signatures
            // remain viewable only through installed local tombstones.
            replaceRemoteManifests(const [], expiresAt: null);
          }
          _restoreInstalledTombstones(cachedCatalog.manifests);
        }
      }
    } on Object {
      // Keep the bundled catalog usable when persisted remote metadata is bad.
    }
    _initialized = true;
    notifyListeners();
  }

  void _restoreInstalledTombstones(
    Iterable<GameModuleManifest> cachedManifests,
  ) {
    final currentById = {
      for (final manifest in _catalog.manifests) manifest.moduleId: manifest,
    };
    var changed = false;
    for (final cached in cachedManifests) {
      final current = currentById[cached.moduleId];
      if (current == null) continue;
      final resources = current.resources.toList();
      final presentIds = resources
          .map((resource) => resource.resourceId)
          .toSet();
      for (final cachedResource in cached.resources) {
        if (presentIds.contains(cachedResource.resourceId)) continue;
        final record = resourceRecord(
          cached.moduleId,
          cachedResource.resourceId,
        );
        if (record == null ||
            (record.status != GameResourceInstallStatus.installed &&
                record.status != GameResourceInstallStatus.removing)) {
          continue;
        }
        resources.add(
          GameResourceManifest.fromJson({
            ...cachedResource.toJson(),
            'version': record.version,
            'sha256': record.sha256,
            'downloadUrl': null,
            'byteLength': null,
            'signature': null,
            'signingKeyId': null,
          }),
        );
        presentIds.add(cachedResource.resourceId);
        changed = true;
      }
      if (resources.length != current.resources.length) {
        currentById[cached.moduleId] = GameModuleManifest.fromJson({
          ...current.toJson(),
          'resources': resources.map((resource) => resource.toJson()).toList(),
        });
      }
    }
    if (changed) {
      _catalog = GameModuleCatalog(currentById.values);
      notifyListeners();
    }
  }

  Future<void> setModuleEnabled(String moduleId, bool enabled) async {
    if (!_initialized) throw StateError('Game library has not initialized.');
    final module = _catalog[moduleId];
    if (module == null) {
      throw ArgumentError.value(moduleId, 'moduleId', 'Unknown game module.');
    }
    final platform = currentGamePlatform;
    if (enabled && (platform == null || !module.platforms.contains(platform))) {
      throw StateError(
        'Game module $moduleId is unavailable on this platform.',
      );
    }
    if (enabled && !module.supportsHostApiVersion(gameHostApiVersion)) {
      throw StateError(
        'Game module $moduleId requires a different host API version.',
      );
    }
    if (enabled) {
      for (final dependency in module.dependencies.where(
        (item) => !item.optional,
      )) {
        if (dependency.kind == GameDependencyKind.module) {
          final requiredModule = _catalog[dependency.id];
          if (requiredModule == null ||
              !_enabledModuleIds.contains(dependency.id) ||
              !dependency.acceptsVersion(requiredModule.packageVersion)) {
            throw StateError(
              'Required module dependency ${dependency.id} is not enabled at a compatible version.',
            );
          }
        } else {
          final owner = _catalog.manifests
              .where(
                (candidate) =>
                    dependency.id.startsWith('${candidate.moduleId}.'),
              )
              .firstOrNull;
          final resource = owner?.resources
              .where((candidate) => candidate.resourceId == dependency.id)
              .firstOrNull;
          final installed = owner == null || resource == null
              ? null
              : resourceRecord(owner.moduleId, resource.resourceId);
          if (resource == null ||
              installed?.status != GameResourceInstallStatus.installed ||
              installed?.version == null ||
              !dependency.acceptsVersion(installed!.version) ||
              !RegExp(r'^[a-fA-F0-9]{64}$').hasMatch(installed.sha256)) {
            throw StateError(
              'Required resource dependency ${dependency.id} is not verified and installed.',
            );
          }
        }
      }
    } else {
      final dependent = _catalog.manifests.where(
        (candidate) =>
            _enabledModuleIds.contains(candidate.moduleId) &&
            candidate.dependencies.any(
              (dependency) =>
                  dependency.kind == GameDependencyKind.module &&
                  !dependency.optional &&
                  dependency.id == moduleId,
            ),
      );
      if (dependent.isNotEmpty) {
        throw StateError(
          'Module $moduleId is required by ${dependent.first.moduleId}.',
        );
      }
    }
    final next = Set<String>.of(_enabledModuleIds);
    if (enabled) {
      next.add(moduleId);
    } else {
      next.remove(moduleId);
    }
    await store.writeEnabledModuleIds(next);
    _enabledModuleIds = next;
    notifyListeners();
  }

  Future<void> recordResourceState(GameResourceInstallRecord record) async {
    if (!_initialized) throw StateError('Game library has not initialized.');
    final manifest = _catalog[record.moduleId];
    final resource = manifest?.resources
        .where((candidate) => candidate.resourceId == record.resourceId)
        .firstOrNull;
    if (resource == null) {
      throw ArgumentError.value(
        record.resourceId,
        'resourceId',
        'Resource is not declared by its owning game module.',
      );
    }
    if (!RegExp(r'^[a-fA-F0-9]{64}$').hasMatch(record.sha256) ||
        record.downloadedBytes < 0 ||
        (record.totalBytes != null &&
            record.downloadedBytes > record.totalBytes!)) {
      throw ArgumentError('Invalid resource integrity or download progress.');
    }
    final previous = resourceRecord(record.moduleId, record.resourceId);
    if (previous != null &&
        !_isAllowedTransition(previous.status, record.status)) {
      throw StateError(
        'Invalid resource transition: ${previous.status.name} -> ${record.status.name}.',
      );
    }
    await store.writeResourceRecord(record);
    _resourceRecords['${record.moduleId}:${record.resourceId}'] = record;
    notifyListeners();
  }

  Future<void> removeResource(String moduleId, String resourceId) async {
    final manifest = _catalog[moduleId];
    if (manifest == null ||
        !manifest.resources.any(
          (resource) => resource.resourceId == resourceId,
        )) {
      throw ArgumentError('Resource does not belong to a known game module.');
    }
    await store.removeResourceRecord(moduleId, resourceId);
    _resourceRecords.remove('$moduleId:$resourceId');
    notifyListeners();
  }

  Future<void> restoreResourceRecordSnapshot(
    String moduleId,
    String resourceId,
    GameResourceInstallRecord? snapshot,
  ) async {
    if (!_initialized) throw StateError('Game library has not initialized.');
    if (snapshot == null) {
      await store.removeResourceRecord(moduleId, resourceId);
      _resourceRecords.remove('$moduleId:$resourceId');
    } else {
      await store.writeResourceRecord(snapshot);
      _resourceRecords['$moduleId:$resourceId'] = snapshot;
    }
    notifyListeners();
  }

  bool _isAllowedTransition(
    GameResourceInstallStatus previous,
    GameResourceInstallStatus next,
  ) {
    if (previous == next &&
        (next == GameResourceInstallStatus.downloading ||
            next == GameResourceInstallStatus.verifying ||
            next == GameResourceInstallStatus.removing)) {
      return true;
    }
    return switch (previous) {
      GameResourceInstallStatus.queued =>
        next == GameResourceInstallStatus.downloading ||
            next == GameResourceInstallStatus.failed,
      GameResourceInstallStatus.downloading =>
        next == GameResourceInstallStatus.verifying ||
            next == GameResourceInstallStatus.failed,
      GameResourceInstallStatus.verifying =>
        next == GameResourceInstallStatus.migrating ||
            next == GameResourceInstallStatus.failed,
      GameResourceInstallStatus.migrating =>
        next == GameResourceInstallStatus.installed ||
            next == GameResourceInstallStatus.failed,
      GameResourceInstallStatus.installed =>
        next == GameResourceInstallStatus.queued ||
            next == GameResourceInstallStatus.removing,
      GameResourceInstallStatus.removing => false,
      GameResourceInstallStatus.failed =>
        next == GameResourceInstallStatus.queued,
    };
  }
}
