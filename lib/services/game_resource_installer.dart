import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:cryptography/cryptography.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../game_modules/game_module_manifest.dart';
import 'game_library_controller.dart';
import 'game_resource_content_store.dart';

abstract interface class GameResourceSignatureVerifier {
  Future<bool> verify({
    required String keyId,
    required String signature,
    required String moduleId,
    required String resourceId,
    required String version,
    required String sha256,
    required Uint8List payload,
  });
}

class Ed25519GameResourceSignatureVerifier
    implements GameResourceSignatureVerifier {
  Ed25519GameResourceSignatureVerifier(Map<String, List<int>> trustedKeys)
    : _trustedKeys = {
        for (final entry in trustedKeys.entries)
          entry.key: List<int>.unmodifiable(entry.value),
      };

  final Map<String, List<int>> _trustedKeys;

  static Uint8List canonicalSignedMessage({
    required String moduleId,
    required String resourceId,
    required String version,
    required String sha256,
    required Uint8List payload,
  }) {
    final header = utf8.encode(
      '$moduleId\n$resourceId\n$version\n${sha256.toLowerCase()}\n',
    );
    return Uint8List.fromList([...header, ...payload]);
  }

  @override
  Future<bool> verify({
    required String keyId,
    required String signature,
    required String moduleId,
    required String resourceId,
    required String version,
    required String sha256,
    required Uint8List payload,
  }) async {
    final publicKeyBytes = _trustedKeys[keyId];
    if (publicKeyBytes == null || publicKeyBytes.length != 32) return false;
    final signatureBytes = _decodeBase64Url(signature);
    if (signatureBytes == null || signatureBytes.length != 64) return false;
    return Ed25519().verify(
      canonicalSignedMessage(
        moduleId: moduleId,
        resourceId: resourceId,
        version: version,
        sha256: sha256,
        payload: payload,
      ),
      signature: Signature(
        signatureBytes,
        publicKey: SimplePublicKey(publicKeyBytes, type: KeyPairType.ed25519),
      ),
    );
  }

  List<int>? _decodeBase64Url(String value) {
    try {
      return base64Url.decode(base64Url.normalize(value));
    } on FormatException {
      return null;
    }
  }
}

typedef GameResourceMigration = Future<void> Function(Uint8List payload);

class GameResourceInstaller {
  static const _downloadChunkBytes = 64 * 1024;

  GameResourceInstaller({
    required this.controller,
    required this.contentStore,
    required this.signatureVerifier,
    http.Client? client,
  }) : _client = client ?? http.Client();

  final GameLibraryController controller;
  final GameResourceContentStore contentStore;
  final GameResourceSignatureVerifier signatureVerifier;
  final http.Client _client;

  Future<void> install(
    String moduleId,
    String resourceId, {
    GameResourceMigration? migrate,
  }) => installSet(moduleId, [
    resourceId,
  ], migrations: migrate == null ? const {} : {resourceId: migrate});

  /// Downloads, verifies, migrates and activates a related set of packs. The
  /// active version map is switched by the content store in one pointer write,
  /// so readers cannot observe a mixed old/new resource set.
  Future<void> installSet(
    String moduleId,
    List<String> resourceIds, {
    Map<String, GameResourceMigration> migrations = const {},
  }) async {
    final module = controller.catalog[moduleId];
    if (module == null) {
      throw ArgumentError('Unknown game module: $moduleId.');
    }
    if (resourceIds.isEmpty ||
        resourceIds.toSet().length != resourceIds.length) {
      throw ArgumentError('A resource set must contain unique resource IDs.');
    }
    final resources = <GameResourceManifest>[];
    for (final resourceId in resourceIds) {
      final resource = module.resources
          .where((candidate) => candidate.resourceId == resourceId)
          .firstOrNull;
      if (resource == null) {
        throw ArgumentError('The resource is not declared by $moduleId.');
      }
      resources.add(resource);
    }
    final platform = currentGamePlatform;
    if (platform == null || !module.platforms.contains(platform)) {
      throw StateError('The game module is unavailable on this platform.');
    }
    final resourceIdSet = resourceIds.toSet();
    final metadata = <String, (Uri, String, String, int)>{};
    for (final resource in resources) {
      if (!resource.platforms.contains(platform)) {
        throw StateError(
          'Resource ${resource.resourceId} is unavailable on this platform.',
        );
      }
      await _ensureDependenciesAvailable(
        resource,
        stagedResourceIds: resourceIdSet,
      );
      final uri = Uri.tryParse(resource.downloadUrl ?? '');
      final signature = resource.signature;
      final keyId = resource.signingKeyId;
      final byteLength = resource.byteLength;
      if (uri == null ||
          !uri.hasAuthority ||
          uri.scheme != 'https' ||
          signature == null ||
          keyId == null ||
          byteLength == null) {
        throw StateError(
          'Resource ${resource.resourceId} is missing signed download metadata.',
        );
      }
      metadata[resource.resourceId] = (uri, signature, keyId, byteLength);
    }

    final previousActiveSet = await contentStore.readActiveSet(moduleId);
    final previousRecords = {
      for (final resource in resources)
        resource.resourceId: controller.resourceRecord(
          moduleId,
          resource.resourceId,
        ),
    };
    final attempted = <GameResourceManifest>[];
    final payloads = <String, Uint8List>{};
    var activated = false;
    try {
      for (final resource in resources) {
        attempted.add(resource);
        await _record(moduleId, resource, GameResourceInstallStatus.queued);
        final (uri, signature, keyId, byteLength) =
            metadata[resource.resourceId]!;
        final payload = await _downloadPayload(
          moduleId,
          resource,
          uri,
          expectedBytes: byteLength,
        );
        payloads[resource.resourceId] = payload;
        await _record(
          moduleId,
          resource,
          GameResourceInstallStatus.verifying,
          downloadedBytes: payload.length,
          totalBytes: byteLength,
        );
        final actualDigest = sha256.convert(payload).toString();
        if (actualDigest.toLowerCase() != resource.sha256.toLowerCase()) {
          throw FormatException(
            'Resource ${resource.resourceId} SHA-256 digest mismatch.',
          );
        }
        final signatureIsValid = await signatureVerifier.verify(
          keyId: keyId,
          signature: signature,
          moduleId: moduleId,
          resourceId: resource.resourceId,
          version: resource.version,
          sha256: actualDigest,
          payload: payload,
        );
        if (!signatureIsValid) {
          throw FormatException(
            'Resource ${resource.resourceId} publisher signature is invalid.',
          );
        }
        await contentStore.writeStaged(
          moduleId,
          resource.resourceId,
          resource.version,
          payload,
        );
        await _record(
          moduleId,
          resource,
          GameResourceInstallStatus.migrating,
          downloadedBytes: payload.length,
          totalBytes: byteLength,
        );
      }

      for (final resource in resources) {
        await migrations[resource.resourceId]?.call(
          payloads[resource.resourceId]!,
        );
        await _ensureDependenciesAvailable(
          resource,
          stagedResourceIds: resourceIdSet,
        );
      }
      final nextActiveSet = Map<String, String>.of(previousActiveSet)
        ..addEntries(
          resources.map(
            (resource) => MapEntry(resource.resourceId, resource.version),
          ),
        );
      await contentStore.activateSet(moduleId, nextActiveSet);
      activated = true;
      for (final resource in resources) {
        await _record(
          moduleId,
          resource,
          GameResourceInstallStatus.installed,
          downloadedBytes: payloads[resource.resourceId]!.length,
          totalBytes: metadata[resource.resourceId]!.$4,
        );
      }
    } on Object {
      if (activated) {
        await contentStore.restoreActiveSet(moduleId, previousActiveSet);
      }
      for (final resource in resources) {
        final progress = controller.resourceRecord(
          moduleId,
          resource.resourceId,
        );
        final isResumable =
            progress?.status == GameResourceInstallStatus.downloading &&
            progress!.totalBytes != null &&
            progress.downloadedBytes < progress.totalBytes!;
        if (!isResumable) {
          await contentStore.discardStaged(
            moduleId,
            resource.resourceId,
            resource.version,
          );
        }
      }
      for (final resource in attempted) {
        final snapshot = previousRecords[resource.resourceId];
        try {
          if (snapshot != null) {
            await controller.restoreResourceRecordSnapshot(
              moduleId,
              resource.resourceId,
              snapshot,
            );
          } else {
            final record = controller.resourceRecord(
              moduleId,
              resource.resourceId,
            );
            if (record != null &&
                record.status != GameResourceInstallStatus.failed) {
              if (record.status == GameResourceInstallStatus.installed) {
                await controller.recordResourceState(
                  GameResourceInstallRecord(
                    moduleId: moduleId,
                    resourceId: resource.resourceId,
                    version: resource.version,
                    sha256: resource.sha256,
                    status: GameResourceInstallStatus.queued,
                    payloadSchemaVersion: resource.payloadSchemaVersion,
                  ),
                );
              }
              await _record(
                moduleId,
                resource,
                GameResourceInstallStatus.failed,
                downloadedBytes: record.downloadedBytes,
                totalBytes: record.totalBytes,
              );
            }
          }
        } on Object {
          // Preserve the original install failure if rollback metadata also fails.
        }
      }
      rethrow;
    }
  }

  Future<void> _ensureDependenciesAvailable(
    GameResourceManifest resource, {
    Set<String> stagedResourceIds = const {},
  }) async {
    for (final dependency in resource.dependencies.where(
      (item) => !item.optional,
    )) {
      if (dependency.kind == GameDependencyKind.module) {
        final requiredModule = controller.catalog[dependency.id];
        if (requiredModule == null ||
            !controller.isModuleEnabled(dependency.id) ||
            !dependency.acceptsVersion(requiredModule.packageVersion)) {
          throw StateError(
            'Required module dependency ${dependency.id} is not available.',
          );
        }
      } else {
        final dependencyModule = controller.catalog.manifests
            .where(
              (candidate) => dependency.id.startsWith('${candidate.moduleId}.'),
            )
            .firstOrNull;
        final dependencyResource = dependencyModule?.resources
            .where((candidate) => candidate.resourceId == dependency.id)
            .firstOrNull;
        if (stagedResourceIds.contains(dependency.id) &&
            dependencyResource != null &&
            dependency.acceptsVersion(dependencyResource.version)) {
          continue;
        }
        final installed = dependencyModule == null || dependencyResource == null
            ? null
            : controller.resourceRecord(
                dependencyModule.moduleId,
                dependencyResource.resourceId,
              );
        if (dependencyModule == null ||
            dependencyResource == null ||
            installed?.status != GameResourceInstallStatus.installed ||
            installed?.version == null ||
            !dependency.acceptsVersion(installed!.version) ||
            !RegExp(r'^[a-fA-F0-9]{64}$').hasMatch(installed.sha256)) {
          throw StateError(
            'Required resource dependency ${dependency.id} is not verified and installed.',
          );
        }
        final activeVersion = await contentStore.readActiveVersion(
          dependencyModule.moduleId,
          dependency.id,
        );
        final activeBytes = await contentStore.readActive(
          dependencyModule.moduleId,
          dependency.id,
        );
        if (activeVersion != installed.version ||
            activeBytes == null ||
            sha256.convert(activeBytes).toString() !=
                installed.sha256.toLowerCase()) {
          throw StateError(
            'Required resource dependency ${dependency.id} is not active and digest-verified.',
          );
        }
      }
    }
  }

  Future<Uint8List> _downloadPayload(
    String moduleId,
    GameResourceManifest resource,
    Uri uri, {
    required int expectedBytes,
  }) async {
    final chunks = <Uint8List>[
      ...await contentStore.readStagedChunks(
        moduleId,
        resource.resourceId,
        resource.version,
      ),
    ];
    var downloaded = chunks.fold<int>(0, (sum, chunk) => sum + chunk.length);
    if (downloaded > expectedBytes) {
      await contentStore.discardStaged(
        moduleId,
        resource.resourceId,
        resource.version,
      );
      chunks.clear();
      downloaded = 0;
    }

    await _record(
      moduleId,
      resource,
      GameResourceInstallStatus.downloading,
      downloadedBytes: downloaded,
      totalBytes: expectedBytes,
    );

    if (downloaded < expectedBytes) {
      final request = http.Request('GET', uri)
        ..headers['accept-encoding'] = 'identity';
      if (downloaded > 0) request.headers['range'] = 'bytes=$downloaded-';
      final response = await _client.send(request);
      if (response.statusCode == 200) {
        if (downloaded > 0) {
          await contentStore.discardStaged(
            moduleId,
            resource.resourceId,
            resource.version,
          );
          chunks.clear();
          downloaded = 0;
        }
      } else if (response.statusCode == 206 && downloaded > 0) {
        final range = RegExp(
          r'^bytes (\d+)-(\d+)/(\d+)$',
        ).firstMatch(response.headers['content-range'] ?? '');
        if (range == null ||
            int.parse(range.group(1)!) != downloaded ||
            int.parse(range.group(2)!) != expectedBytes - 1 ||
            int.parse(range.group(3)!) != expectedBytes) {
          throw const FormatException('Server returned an invalid byte range.');
        }
      } else {
        throw http.ClientException(
          'Resource download failed with HTTP ${response.statusCode}.',
          uri,
        );
      }

      var chunkIndex = chunks.length;
      final pending = <int>[];
      await for (final networkChunk in response.stream) {
        if (networkChunk.length > expectedBytes - downloaded - pending.length) {
          await contentStore.discardStaged(
            moduleId,
            resource.resourceId,
            resource.version,
          );
          await _record(
            moduleId,
            resource,
            GameResourceInstallStatus.failed,
            downloadedBytes: downloaded + pending.length,
            totalBytes: expectedBytes,
          );
          throw FormatException(
            'Resource response exceeds its declared size of $expectedBytes bytes.',
          );
        }
        pending.addAll(networkChunk);
        while (pending.length >= _downloadChunkBytes) {
          final part = Uint8List.fromList(
            pending.sublist(0, _downloadChunkBytes),
          );
          pending.removeRange(0, _downloadChunkBytes);
          await _persistChunk(
            moduleId,
            resource,
            chunkIndex++,
            part,
            downloaded + part.length,
            expectedBytes,
          );
          downloaded += part.length;
          chunks.add(part);
        }
      }
      if (pending.isNotEmpty) {
        final part = Uint8List.fromList(pending);
        await _persistChunk(
          moduleId,
          resource,
          chunkIndex,
          part,
          downloaded + part.length,
          expectedBytes,
        );
        downloaded += part.length;
        chunks.add(part);
      }
    }

    if (downloaded != expectedBytes) {
      throw FormatException(
        'Resource size mismatch: expected $expectedBytes, received $downloaded.',
      );
    }
    final payload = Uint8List(downloaded);
    var offset = 0;
    for (final chunk in chunks) {
      payload.setRange(offset, offset + chunk.length, chunk);
      offset += chunk.length;
    }
    return payload;
  }

  Future<void> _persistChunk(
    String moduleId,
    GameResourceManifest resource,
    int index,
    Uint8List bytes,
    int downloadedBytes,
    int totalBytes,
  ) async {
    await contentStore.writeStagedChunk(
      moduleId,
      resource.resourceId,
      resource.version,
      index,
      bytes,
    );
    await _record(
      moduleId,
      resource,
      GameResourceInstallStatus.downloading,
      downloadedBytes: downloadedBytes,
      totalBytes: totalBytes,
    );
  }

  Future<void> _record(
    String moduleId,
    GameResourceManifest resource,
    GameResourceInstallStatus status, {
    int downloadedBytes = 0,
    int? totalBytes,
  }) => controller.recordResourceState(
    GameResourceInstallRecord(
      moduleId: moduleId,
      resourceId: resource.resourceId,
      version: resource.version,
      sha256: resource.sha256,
      status: status,
      downloadedBytes: downloadedBytes,
      totalBytes: totalBytes,
      payloadSchemaVersion: resource.payloadSchemaVersion,
    ),
  );

  @mustCallSuper
  void dispose() => _client.close();
}
