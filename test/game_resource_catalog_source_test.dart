import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:cryptography/cryptography.dart';
import 'package:taiwan_brawl/config/app_configuration.dart';
import 'package:taiwan_brawl/game_modules/bundled_game_catalog.dart';
import 'package:taiwan_brawl/services/api_client.dart';
import 'package:taiwan_brawl/services/game_library_controller.dart';
import 'package:taiwan_brawl/services/game_resource_catalog_source.dart';
import 'package:taiwan_brawl/services/game_resource_content_store.dart';
import 'package:taiwan_brawl/services/game_library_store.dart';
import 'package:taiwan_brawl/services/game_resource_installer.dart';
import 'package:taiwan_brawl/services/game_resource_library_service.dart';
import 'package:taiwan_brawl/game_modules/game_module_manifest.dart';
import 'package:taiwan_brawl_messaging/taiwan_brawl_messaging.dart';

class _MemoryStore implements GameLibraryStore, CachedGameResourceCatalogStore {
  CachedGameResourceCatalog? cachedCatalog;
  final Map<String, GameResourceInstallRecord> records = {};

  @override
  Future<Set<String>> readEnabledModuleIds() async => {};
  @override
  Future<void> writeEnabledModuleIds(Set<String> moduleIds) async {}
  @override
  Future<Map<String, GameResourceInstallRecord>> readResourceRecords() async =>
      Map.of(records);
  @override
  Future<void> writeResourceRecord(GameResourceInstallRecord record) async {
    records['${record.moduleId}:${record.resourceId}'] = record;
  }

  @override
  Future<void> removeResourceRecord(String moduleId, String resourceId) async {
    records.remove('$moduleId:$resourceId');
  }

  @override
  Future<CachedGameResourceCatalog?> readCachedResourceCatalog() async =>
      cachedCatalog;
  @override
  Future<void> writeCachedResourceCatalog(
    CachedGameResourceCatalog catalog,
  ) async {
    cachedCatalog = catalog;
  }
}

class _UnusedContentStore implements GameResourceContentStore {
  @override
  Future<void> activate(
    String moduleId,
    String resourceId,
    String version,
  ) async {}
  @override
  Future<void> activateSet(
    String moduleId,
    Map<String, String> versions,
  ) async {}
  @override
  Future<void> discardStaged(
    String moduleId,
    String resourceId,
    String version,
  ) async {}
  @override
  Future<Uint8List?> readActive(String moduleId, String resourceId) async =>
      null;
  @override
  Future<String?> readActiveVersion(String moduleId, String resourceId) async =>
      null;
  @override
  Future<Map<String, String>> readActiveSet(String moduleId) async => {};
  @override
  Future<List<Uint8List>> readStagedChunks(
    String moduleId,
    String resourceId,
    String version,
  ) async => [];
  @override
  Future<void> remove(String moduleId, String resourceId) async {}
  @override
  Future<void> removeSet(String moduleId, List<String> resourceIds) async {}
  @override
  Future<void> restoreActiveSet(
    String moduleId,
    Map<String, String> versions,
  ) async {}
  @override
  Future<void> restoreActiveVersion(
    String moduleId,
    String resourceId,
    String? version,
  ) async {}
  @override
  Future<void> writeStaged(
    String moduleId,
    String resourceId,
    String version,
    Uint8List bytes,
  ) async {}
  @override
  Future<void> writeStagedChunk(
    String moduleId,
    String resourceId,
    String version,
    int index,
    Uint8List bytes,
  ) async {}
}

class _UnusedVerifier implements GameResourceSignatureVerifier {
  @override
  Future<bool> verify({
    required String keyId,
    required String signature,
    required String moduleId,
    required String resourceId,
    required String version,
    required String sha256,
    required Uint8List payload,
  }) async => false;
}

class _MemoryCredentials implements CredentialStore {
  @override
  Future<String?> read(String key) async => null;
  @override
  Future<void> write(String key, String value) async {}
  @override
  Future<void> delete(String key) async {}
}

Future<({Map<String, dynamic> envelope, List<int> publicKey})> _signedEnvelope({
  required Map<String, dynamic> payload,
  required DateTime issuedAt,
  required DateTime expiresAt,
  String publisher = 'taiwan-brawl',
  String keyId = 'catalog-test-key',
}) async {
  final algorithm = Ed25519();
  final keyPair = await algorithm.newKeyPair();
  final publicKey = await keyPair.extractPublicKey();
  final issued = issuedAt.toUtc().toIso8601String();
  final expires = expiresAt.toUtc().toIso8601String();
  final signature = await algorithm.sign(
    GameResourceCatalogSource.canonicalSignedMessage(
      publisher: publisher,
      signingKeyId: keyId,
      issuedAt: issued,
      expiresAt: expires,
      catalog: payload,
    ),
    keyPair: keyPair,
  );
  return (
    envelope: {
      'envelopeVersion': 1,
      'publisher': publisher,
      'signingKeyId': keyId,
      'issuedAt': issued,
      'expiresAt': expires,
      'payload': payload,
      'signature': base64Url.encode(signature.bytes).replaceAll('=', ''),
    },
    publicKey: publicKey.bytes,
  );
}

GameResourceCatalogSource _source(
  Map<String, dynamic> response, {
  Map<String, GameCatalogTrustKey> trustedKeys = const {},
  required DateTime now,
}) {
  final client = ApiClient(
    client: MockClient((_) async => http.Response(jsonEncode(response), 200)),
    credentials: _MemoryCredentials(),
    configuration: const AppConfiguration(
      apiBaseUrl: 'https://example.test',
      googleWebClientId: '',
      googleServerClientId: '',
      p2pChatEnabled: false,
      previewMode: true,
      peerVerificationEnabled: false,
    ),
  );
  return GameResourceCatalogSource(
    client,
    trustedKeys: trustedKeys,
    clock: () => now,
  );
}

void main() {
  test(
    'catalog signer vector interoperates with the backend Node publisher',
    () async {
      const payload = {'catalogVersion': 1, 'modules': <Object>[]};
      final now = DateTime.utc(2026, 10, 20, 12);
      final envelope = {
        'envelopeVersion': 1,
        'publisher': 'taiwan-brawl',
        'signingKeyId': 'catalog-vector-1',
        'issuedAt': '2026-10-20T12:00:00.000Z',
        'expiresAt': '2026-10-21T12:00:00.000Z',
        'payload': payload,
        'signature':
            '1m9lOFQq_FP-_nfBWYff7q2RBdrLDOb0FPDdEjDD9xzfZCgrV1t0V3L20SVqSKOoE4R7ImUeqwPGwjSGzhoNAw',
      };
      final manifests = await _source(
        envelope,
        trustedKeys: {
          'catalog-vector-1': GameCatalogTrustKey(
            publisher: 'taiwan-brawl',
            publicKey: base64Url.decode(
              base64Url.normalize(
                'iojj3XQJ8ZX9UtstPLpdcspnCb8dlBIb83SIAbQPb1w',
              ),
            ),
          ),
        },
        now: now,
      ).fetch();
      expect(manifests, isEmpty);
    },
  );

  test(
    'only a cryptographically verified cached envelope restores download metadata',
    () async {
      final now = DateTime.utc(2026, 10, 20, 12);
      final manifest = GameModuleManifest(
        moduleId: 'game.archery',
        displayName: 'Archery',
        description: 'Signed offline listing',
        packageVersion: '0.1.0',
        minimumShellVersion: '0.132.0',
        dataSchemaVersion: 1,
        resources: const [
          GameResourceManifest(
            resourceId: 'game.archery.rules',
            version: '1.0.0',
            kind: GameResourceKind.gameplayData,
            sha256:
                'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
            affectsGameplay: true,
            downloadUrl: 'https://example.test/archery/rules',
            byteLength: 8,
            signature: 'payload-signature',
            signingKeyId: 'resource-key',
          ),
        ],
      );
      final signed = await _signedEnvelope(
        payload: {
          'catalogVersion': 1,
          'modules': [manifest.toJson()],
        },
        issuedAt: now.subtract(const Duration(minutes: 1)),
        expiresAt: now.add(const Duration(hours: 1)),
      );
      final trustedKeys = {
        'catalog-test-key': GameCatalogTrustKey(
          publisher: 'taiwan-brawl',
          publicKey: signed.publicKey,
        ),
      };
      final source = _source(
        signed.envelope,
        trustedKeys: trustedKeys,
        now: now,
      );
      final snapshot = await source.verifyCachedEnvelope(signed.envelope);
      final store = _MemoryStore()
        ..cachedCatalog = CachedGameResourceCatalog(
          manifests: snapshot.manifests,
          issuedAt: snapshot.issuedAt,
          expiresAt: snapshot.expiresAt,
          signedEnvelope: snapshot.signedEnvelope,
        );
      final controller = GameLibraryController(
        catalog: bundledGameCatalog,
        store: store,
        clock: () => now,
        cachedCatalogVerifier: source.verifyCachedEnvelope,
      );
      await controller.initialize();
      expect(
        controller.catalog['game.archery']!.resources.single.downloadUrl,
        'https://example.test/archery/rules',
      );
      expect(controller.canInstallRemoteResources, isTrue);
      controller.dispose();

      final expired = await _signedEnvelope(
        payload: {
          'catalogVersion': 1,
          'modules': [manifest.toJson()],
        },
        issuedAt: now.subtract(const Duration(hours: 2)),
        expiresAt: now.subtract(const Duration(minutes: 1)),
      );
      final expiredTrustedKeys = {
        'catalog-test-key': GameCatalogTrustKey(
          publisher: 'taiwan-brawl',
          publicKey: expired.publicKey,
        ),
      };
      final expiredSnapshot = await _source(
        expired.envelope,
        trustedKeys: expiredTrustedKeys,
        now: now,
      ).verifyCachedEnvelope(expired.envelope);
      final expiredController = GameLibraryController(
        catalog: bundledGameCatalog,
        store: _MemoryStore()
          ..cachedCatalog = CachedGameResourceCatalog(
            manifests: expiredSnapshot.manifests,
            issuedAt: expiredSnapshot.issuedAt,
            expiresAt: expiredSnapshot.expiresAt,
            signedEnvelope: expiredSnapshot.signedEnvelope,
          ),
        clock: () => now,
        cachedCatalogVerifier: _source(
          expired.envelope,
          trustedKeys: expiredTrustedKeys,
          now: now,
        ).verifyCachedEnvelope,
      );
      await expiredController.initialize();
      expect(
        expiredController.catalog['game.archery']!.resources.single.downloadUrl,
        'https://example.test/archery/rules',
      );
      expect(expiredController.canInstallRemoteResources, isFalse);
      expiredController.dispose();

      final tamperedEnvelope = Map<String, dynamic>.from(signed.envelope)
        ..['payload'] = {
          ...(signed.envelope['payload'] as Map<String, dynamic>),
          'modules': [
            {
              ...manifest.toJson(),
              'resources': [
                {
                  ...manifest.resources.single.toJson(),
                  'downloadUrl': 'https://attacker.invalid/forged',
                },
              ],
            },
          ],
        };
      final tamperedStore = _MemoryStore()
        ..cachedCatalog = CachedGameResourceCatalog(
          manifests: [manifest],
          issuedAt: snapshot.issuedAt,
          expiresAt: snapshot.expiresAt,
          signedEnvelope: tamperedEnvelope,
        );
      final tamperedController = GameLibraryController(
        catalog: bundledGameCatalog,
        store: tamperedStore,
        clock: () => now,
        cachedCatalogVerifier: source.verifyCachedEnvelope,
      );
      await tamperedController.initialize();
      expect(tamperedController.catalog['game.archery']!.resources, isEmpty);
      expect(tamperedController.canInstallRemoteResources, isFalse);
      tamperedController.dispose();
    },
  );

  test(
    'non-empty catalogs require a valid trusted publisher signature',
    () async {
      final now = DateTime.utc(2026, 10, 20, 12);
      final payload = {
        'catalogVersion': 1,
        'modules': [
          {
            'moduleId': 'game.archery',
            'displayName': 'Archery',
            'description': 'Single-player archery',
            'publisher': 'taiwan-brawl',
            'packageVersion': '0.1.0',
            'minimumShellVersion': '0.132.0',
            'dataSchemaVersion': 1,
            'resources': <Object>[],
          },
        ],
      };
      final signed = await _signedEnvelope(
        payload: payload,
        issuedAt: now.subtract(const Duration(minutes: 1)),
        expiresAt: now.add(const Duration(minutes: 10)),
      );
      final trustedKeys = {
        'catalog-test-key': GameCatalogTrustKey(
          publisher: 'taiwan-brawl',
          publicKey: signed.publicKey,
        ),
      };
      final source = _source(
        signed.envelope,
        trustedKeys: trustedKeys,
        now: now,
      );
      expect((await source.fetch()).single.moduleId, 'game.archery');
      final snapshot = await source.fetchSnapshot();
      expect(snapshot.issuedAt, now.subtract(const Duration(minutes: 1)));
      expect(snapshot.expiresAt, now.add(const Duration(minutes: 10)));

      final tampered = Map<String, dynamic>.from(signed.envelope)
        ..['payload'] = {
          ...payload,
          'modules': [
            {
              ...(payload['modules'] as List).single as Map,
              'packageVersion': '9.9.9',
            },
          ],
        };
      await expectLater(
        _source(tampered, trustedKeys: trustedKeys, now: now).fetch(),
        throwsFormatException,
      );
      final duplicateModulePayload = {
        ...payload,
        'modules': [
          ...(payload['modules'] as List),
          (payload['modules'] as List).single,
        ],
      };
      final duplicateModuleCatalog = await _signedEnvelope(
        payload: duplicateModulePayload,
        issuedAt: now.subtract(const Duration(minutes: 1)),
        expiresAt: now.add(const Duration(minutes: 10)),
      );
      await expectLater(
        _source(
          duplicateModuleCatalog.envelope,
          trustedKeys: {
            'catalog-test-key': GameCatalogTrustKey(
              publisher: 'taiwan-brawl',
              publicKey: duplicateModuleCatalog.publicKey,
            ),
          },
          now: now,
        ).fetch(),
        throwsFormatException,
      );
      await expectLater(
        _source(signed.envelope, now: now).fetch(),
        throwsFormatException,
      );
      await expectLater(
        _source(
          signed.envelope,
          trustedKeys: {
            'catalog-test-key': GameCatalogTrustKey(
              publisher: 'other-publisher',
              publicKey: signed.publicKey,
            ),
          },
          now: now,
        ).fetch(),
        throwsFormatException,
      );
      final expired = await _signedEnvelope(
        payload: payload,
        issuedAt: now.subtract(const Duration(minutes: 2)),
        expiresAt: now.subtract(const Duration(minutes: 1)),
      );
      await expectLater(
        _source(
          expired.envelope,
          trustedKeys: {
            'catalog-test-key': GameCatalogTrustKey(
              publisher: 'taiwan-brawl',
              publicKey: expired.publicKey,
            ),
          },
          now: now,
        ).fetch(),
        throwsFormatException,
      );
    },
  );

  test(
    'catalog source parses manifests and controller merges known modules',
    () async {
      final now = DateTime.utc(2026, 10, 20, 12);
      final payload =
          jsonDecode('''
        {"catalogVersion":1,"modules":[{
          "moduleId":"game.archery","displayName":"Archery",
          "description":"Updated description","publisher":"taiwan-brawl",
          "packageVersion":"0.1.0","minimumShellVersion":"0.132.0",
          "dataSchemaVersion":1,"platforms":["web","android"],
          "dependencies":[],
          "resources":[{"resourceId":"game.archery.map.default",
            "version":"1.0.0","kind":"gameplayData",
            "sha256":"${'a' * 64}","affectsGameplay":true,
            "dependencies":[],"platforms":["web"],
            "downloadUrl":"https://example.test/game-resources/archery/map/1.0.0",
            "byteLength":10,"signature":"signature","signingKeyId":"release-1"}]
        }]}
      ''')
              as Map<String, dynamic>;
      final signed = await _signedEnvelope(
        payload: payload,
        issuedAt: now.subtract(const Duration(minutes: 1)),
        expiresAt: now.add(const Duration(minutes: 10)),
      );
      final client = ApiClient(
        client: MockClient(
          (request) async => http.Response(jsonEncode(signed.envelope), 200),
        ),
        credentials: _MemoryCredentials(),
        configuration: const AppConfiguration(
          apiBaseUrl: 'https://example.test',
          googleWebClientId: '',
          googleServerClientId: '',
          p2pChatEnabled: false,
          previewMode: true,
          peerVerificationEnabled: false,
        ),
      );
      final manifests = await GameResourceCatalogSource(
        client,
        trustedKeys: {
          'catalog-test-key': GameCatalogTrustKey(
            publisher: 'taiwan-brawl',
            publicKey: signed.publicKey,
          ),
        },
        clock: () => now,
      ).fetch();
      final controller = GameLibraryController(
        catalog: bundledGameCatalog,
        store: _MemoryStore(),
      );
      controller.mergeRemoteManifests(manifests);
      expect(
        controller.catalog['game.archery']!.description,
        bundledGameCatalog['game.archery']!.description,
      );
      expect(
        controller.catalog['game.archery']!.resources.single.version,
        '1.0.0',
      );
      expect(
        controller.catalog['game.archery']!.platforms,
        bundledGameCatalog['game.archery']!.platforms,
      );
      expect(controller.catalog['game.archery']!.resources.single.platforms, [
        GamePlatform.web,
      ]);
      expect(controller.catalog['game.mini-royale']!.resources, isEmpty);
    },
  );

  test(
    'verified empty catalog withdraws cached downloads while unpublished empty preserves them',
    () async {
      final now = DateTime.utc(2026, 10, 20, 12);
      const resourceId = 'game.archery.rules';
      final oldManifest = GameModuleManifest(
        moduleId: 'game.archery',
        displayName: 'Archery',
        description: 'Cached resource listing',
        packageVersion: '0.1.0',
        minimumShellVersion: '0.132.0',
        dataSchemaVersion: 1,
        resources: const [
          GameResourceManifest(
            resourceId: resourceId,
            version: '1.0.0',
            kind: GameResourceKind.gameplayData,
            sha256:
                'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
            affectsGameplay: true,
            downloadUrl:
                'https://example.test/game-resources/archery/rules/1.0.0',
            byteLength: 8,
            signature: 'resource-signature',
            signingKeyId: 'resource-key',
          ),
        ],
      );
      final oldSigned = await _signedEnvelope(
        payload: {
          'catalogVersion': 1,
          'modules': [oldManifest.toJson()],
        },
        issuedAt: now.subtract(const Duration(minutes: 2)),
        expiresAt: now.add(const Duration(hours: 1)),
      );
      final oldSource = _source(
        oldSigned.envelope,
        trustedKeys: {
          'catalog-test-key': GameCatalogTrustKey(
            publisher: 'taiwan-brawl',
            publicKey: oldSigned.publicKey,
          ),
        },
        now: now,
      );
      final oldSnapshot = await oldSource.verifyCachedEnvelope(
        oldSigned.envelope,
      );
      final store = _MemoryStore()
        ..cachedCatalog = CachedGameResourceCatalog(
          manifests: oldSnapshot.manifests,
          issuedAt: oldSnapshot.issuedAt,
          expiresAt: oldSnapshot.expiresAt,
          signedEnvelope: oldSnapshot.signedEnvelope,
        )
        ..records['game.archery:$resourceId'] = const GameResourceInstallRecord(
          moduleId: 'game.archery',
          resourceId: resourceId,
          version: '1.0.0',
          sha256:
              'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
          status: GameResourceInstallStatus.installed,
          downloadedBytes: 8,
          totalBytes: 8,
        );
      final controller = GameLibraryController(
        catalog: bundledGameCatalog,
        store: store,
        clock: () => now,
        cachedCatalogVerifier: oldSource.verifyCachedEnvelope,
      );
      await controller.initialize();
      expect(controller.canInstallRemoteResources, isTrue);
      final contentStore = _UnusedContentStore();
      final installer = GameResourceInstaller(
        controller: controller,
        contentStore: contentStore,
        signatureVerifier: _UnusedVerifier(),
      );
      final unpublished = GameResourceLibraryService(
        controller: controller,
        catalogSource: _source(const {
          'catalogVersion': 1,
          'modules': <Object>[],
        }, now: now),
        installer: installer,
        contentStore: contentStore,
      );

      await unpublished.refreshCatalog();
      expect(store.cachedCatalog!.manifests, hasLength(1));
      expect(
        controller.catalog['game.archery']!.resources.single.downloadUrl,
        isNotNull,
      );

      final emptySigned = await _signedEnvelope(
        payload: const {'catalogVersion': 1, 'modules': <Object>[]},
        issuedAt: now.subtract(const Duration(minutes: 1)),
        expiresAt: now.add(const Duration(minutes: 10)),
      );
      final revoked = GameResourceLibraryService(
        controller: controller,
        catalogSource: _source(
          emptySigned.envelope,
          trustedKeys: {
            'catalog-test-key': GameCatalogTrustKey(
              publisher: 'taiwan-brawl',
              publicKey: emptySigned.publicKey,
            ),
          },
          now: now,
        ),
        installer: installer,
        contentStore: contentStore,
      );

      await revoked.refreshCatalog();
      expect(
        store.cachedCatalog!.issuedAt,
        now.subtract(const Duration(minutes: 1)),
      );
      final cachedArchery = store.cachedCatalog!.manifests.singleWhere(
        (manifest) => manifest.moduleId == 'game.archery',
      );
      expect(cachedArchery.resources, hasLength(1));
      expect(cachedArchery.resources.single.downloadUrl, isNull);
      expect(cachedArchery.resources.single.signature, isNull);
      final retained = controller.catalog['game.archery']!.resources.single;
      expect(retained.resourceId, resourceId);
      expect(retained.downloadUrl, isNull);
      expect(retained.signature, isNull);
      expect(
        controller.resourceRecord('game.archery', resourceId)?.status,
        GameResourceInstallStatus.installed,
      );

      final restoredController = GameLibraryController(
        catalog: bundledGameCatalog,
        store: store,
      );
      await restoredController.initialize();
      final restored =
          restoredController.catalog['game.archery']!.resources.single;
      expect(restored.resourceId, resourceId);
      expect(restored.downloadUrl, isNull);
      expect(
        restoredController.resourceRecord('game.archery', resourceId)?.status,
        GameResourceInstallStatus.installed,
      );
      restoredController.dispose();
      controller.dispose();
    },
  );

  test('catalog source rejects unknown schema versions', () async {
    final client = ApiClient(
      client: MockClient(
        (request) async =>
            http.Response('{"catalogVersion":2,"modules":[]}', 200),
      ),
      credentials: _MemoryCredentials(),
      configuration: const AppConfiguration(
        apiBaseUrl: 'https://example.test',
        googleWebClientId: '',
        googleServerClientId: '',
        p2pChatEnabled: false,
        previewMode: true,
        peerVerificationEnabled: false,
      ),
    );
    await expectLater(
      GameResourceCatalogSource(client).fetch(),
      throwsFormatException,
    );
  });
}
