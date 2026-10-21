import 'dart:async';

import '../game_modules/game_module_manifest.dart';
import 'game_library_controller.dart';
import 'game_library_store.dart';
import 'game_resource_catalog_source.dart';
import 'game_resource_content_store.dart';
import 'game_resource_installer.dart';

class GameResourceLibraryService {
  GameResourceLibraryService({
    required this.controller,
    required this.catalogSource,
    required this.installer,
    required this.contentStore,
    this.resourceMigrations = const {},
  });

  final GameLibraryController controller;
  final GameResourceCatalogSource catalogSource;
  final GameResourceInstaller installer;
  final GameResourceContentStore contentStore;

  /// Package-owned payload validators/migrations keyed by
  /// `<moduleId>:<resourceId>`.
  final Map<String, GameResourceMigration> resourceMigrations;
  final Map<String, Future<void>> _pendingResourceOperations = {};

  Future<void> refreshCatalog() async {
    final snapshot = await catalogSource.fetchSnapshot();
    if (!snapshot.isPublisherVerified) return;

    controller.replaceRemoteManifests(
      snapshot.manifests,
      issuedAt: snapshot.issuedAt,
      expiresAt: snapshot.expiresAt,
    );
    final localStore = controller.store;
    if (localStore is CachedGameResourceCatalogStore) {
      await (localStore as CachedGameResourceCatalogStore)
          .writeCachedResourceCatalog(
            CachedGameResourceCatalog(
              manifests: controller.catalog.manifests,
              issuedAt: snapshot.issuedAt,
              expiresAt: snapshot.expiresAt,
              signedEnvelope: snapshot.signedEnvelope,
            ),
          );
    }
  }

  Future<void> install(String moduleId, String resourceId) =>
      _serialize(moduleId, resourceId, () async {
        _ensureCatalogFresh();
        final module = controller.catalog[moduleId];
        final resource = module?.resources
            .where((candidate) => candidate.resourceId == resourceId)
            .firstOrNull;
        if (resource == null) {
          throw ArgumentError('The resource is not declared by $moduleId.');
        }
        final groupIds = resource.activationGroup == null
            ? [resourceId]
            : module!.resources
                  .where(
                    (candidate) =>
                        candidate.activationGroup == resource.activationGroup,
                  )
                  .map((candidate) => candidate.resourceId)
                  .toList(growable: false);
        if (groupIds.length == 1) {
          final migrations = _migrationsFor(moduleId, groupIds);
          await installer.install(
            moduleId,
            resourceId,
            migrate: migrations[resourceId],
          );
        } else {
          await installer.installSet(
            moduleId,
            groupIds,
            migrations: _migrationsFor(moduleId, groupIds),
          );
        }
      });

  Future<void> installSet(String moduleId, List<String> resourceIds) =>
      _serialize(moduleId, '*resource-set*', () async {
        _ensureCatalogFresh();
        final ids = _expandActivationGroups(moduleId, resourceIds);
        await installer.installSet(
          moduleId,
          ids,
          migrations: _migrationsFor(moduleId, ids),
        );
      });

  void _ensureCatalogFresh() {
    if (!controller.canInstallRemoteResources) {
      throw StateError(
        'The verified game catalog has expired or is unavailable offline. Refresh it before downloading or updating resources.',
      );
    }
  }

  Map<String, GameResourceMigration> _migrationsFor(
    String moduleId,
    List<String> resourceIds,
  ) {
    final module = controller.catalog[moduleId];
    if (module == null) throw ArgumentError('Unknown module: $moduleId.');
    final migrations = <String, GameResourceMigration>{};
    for (final resourceId in resourceIds) {
      final migration = resourceMigrations['$moduleId:$resourceId'];
      if (module.supportedResourceSchemas.containsKey(resourceId) &&
          migration == null) {
        throw StateError(
          'No package payload validator is registered for $resourceId.',
        );
      }
      if (migration != null) migrations[resourceId] = migration;
    }
    return migrations;
  }

  Future<void> remove(String moduleId, String resourceId) =>
      removeSet(moduleId, [resourceId]);

  Future<void> removeSet(String moduleId, List<String> resourceIds) =>
      _serialize(moduleId, '*resource-remove-set*', () async {
        final ids = _expandActivationGroups(moduleId, resourceIds);
        final idSet = ids.toSet();
        _ensureNoRequiredDependents(idSet);
        for (final resourceId in ids) {
          final installed = controller.resourceRecord(moduleId, resourceId);
          if (installed != null &&
              installed.status != GameResourceInstallStatus.removing) {
            await controller.recordResourceState(
              GameResourceInstallRecord(
                moduleId: installed.moduleId,
                resourceId: installed.resourceId,
                version: installed.version,
                sha256: installed.sha256,
                status: GameResourceInstallStatus.removing,
                downloadedBytes: installed.downloadedBytes,
                totalBytes: installed.totalBytes,
                payloadSchemaVersion: installed.payloadSchemaVersion,
              ),
            );
          }
        }
        // One pointer-set update removes the entire activation group. Marking
        // all rows removing first keeps compatibility checks fail-closed.
        await contentStore.removeSet(moduleId, ids);
        for (final resourceId in ids) {
          await controller.removeResource(moduleId, resourceId);
        }
      });

  List<String> _expandActivationGroups(
    String moduleId,
    List<String> requestedIds,
  ) {
    final module = controller.catalog[moduleId];
    if (module == null || requestedIds.isEmpty) {
      throw ArgumentError('Unknown module or empty resource set.');
    }
    final result = <String>{};
    for (final id in requestedIds) {
      final resource = module.resources
          .where((candidate) => candidate.resourceId == id)
          .firstOrNull;
      if (resource == null) {
        throw ArgumentError('Unknown module resource: $id.');
      }
      if (resource.activationGroup == null) {
        result.add(id);
      } else {
        result.addAll(
          module.resources
              .where(
                (candidate) =>
                    candidate.activationGroup == resource.activationGroup,
              )
              .map((candidate) => candidate.resourceId),
        );
      }
    }
    return result.toList()..sort();
  }

  void _ensureNoRequiredDependents(Set<String> resourceIds) {
    for (final module in controller.catalog.manifests) {
      final moduleNeedsResource =
          controller.isModuleEnabled(module.moduleId) &&
          module.dependencies.any(
            (dependency) =>
                !dependency.optional &&
                dependency.kind == GameDependencyKind.resource &&
                resourceIds.contains(dependency.id),
          );
      if (moduleNeedsResource) {
        throw StateError(
          'A selected resource is required by enabled module ${module.moduleId}.',
        );
      }
      for (final dependent in module.resources) {
        final dependentRecord = controller.resourceRecord(
          module.moduleId,
          dependent.resourceId,
        );
        if (!resourceIds.contains(dependent.resourceId) &&
            dependentRecord?.status == GameResourceInstallStatus.installed &&
            dependent.dependencies.any(
              (dependency) =>
                  !dependency.optional &&
                  dependency.kind == GameDependencyKind.resource &&
                  resourceIds.contains(dependency.id),
            )) {
          throw StateError(
            'A selected resource is required by installed pack ${dependent.resourceId}.',
          );
        }
      }
    }
  }

  Future<void> _serialize(
    String moduleId,
    String resourceId,
    Future<void> Function() operation,
  ) async {
    // Resource pointers are committed as a per-module set, so all operations
    // within one game share a lock rather than racing independent pointers.
    final key = moduleId;
    final previous = _pendingResourceOperations[key];
    final release = Completer<void>();
    _pendingResourceOperations[key] = release.future;
    try {
      if (previous != null) await previous;
      await operation();
    } finally {
      release.complete();
      if (identical(_pendingResourceOperations[key], release.future)) {
        _pendingResourceOperations.remove(key);
      }
    }
  }
}
