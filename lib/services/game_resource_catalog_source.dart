import 'dart:convert';

import 'package:cryptography/cryptography.dart';

import '../game_modules/game_module_manifest.dart';
import 'api_client.dart';

class GameCatalogTrustKey {
  const GameCatalogTrustKey({required this.publisher, required this.publicKey});

  final String publisher;
  final List<int> publicKey;
}

class GameResourceCatalogSnapshot {
  const GameResourceCatalogSnapshot({
    required this.isPublisherVerified,
    required this.manifests,
    this.issuedAt,
    this.expiresAt,
    this.signedEnvelope,
  });

  /// False only for the Worker's unsigned, unpublished-catalog placeholder.
  final bool isPublisherVerified;
  final List<GameModuleManifest> manifests;
  final DateTime? issuedAt;
  final DateTime? expiresAt;
  final Map<String, dynamic>? signedEnvelope;
}

class GameResourceCatalogSource {
  const GameResourceCatalogSource(
    this._apiClient, {
    this.trustedKeys = const {},
    DateTime Function()? clock,
  }) : _clock = clock;

  final ApiClient _apiClient;
  final Map<String, GameCatalogTrustKey> trustedKeys;
  final DateTime Function()? _clock;
  static final _ed25519 = Ed25519();

  static List<int> canonicalSignedMessage({
    required String publisher,
    required String signingKeyId,
    required String issuedAt,
    required String expiresAt,
    required Map<String, dynamic> catalog,
  }) => [
    ...utf8.encode(
      'game-catalog-v1\n$publisher\n$signingKeyId\n$issuedAt\n$expiresAt\n',
    ),
    ...utf8.encode(_canonicalJson(catalog)),
  ];

  Future<List<GameModuleManifest>> fetch() async {
    return (await fetchSnapshot()).manifests;
  }

  Future<GameResourceCatalogSnapshot> fetchSnapshot() async {
    final response = await _apiClient.getJson('/api/games/catalog');
    return _verifyEnvelope(response, allowExpired: false);
  }

  /// Verifies a persisted publisher envelope while allowing it to be expired.
  /// Expiry still disables downloads; this path exists only to restore trusted
  /// metadata for offline inspection and installed-resource management.
  Future<GameResourceCatalogSnapshot> verifyCachedEnvelope(
    Map<String, dynamic> envelope,
  ) => _verifyEnvelope(envelope, allowExpired: true);

  Future<GameResourceCatalogSnapshot> _verifyEnvelope(
    Map<String, dynamic> response, {
    required bool allowExpired,
  }) async {
    // The backend's unpublished-catalog response is intentionally unsigned and
    // empty. Any non-empty catalog must arrive in a verified envelope.
    if (response['catalogVersion'] == 1 &&
        response['modules'] is List &&
        (response['modules'] as List).isEmpty &&
        response['envelopeVersion'] == null) {
      return const GameResourceCatalogSnapshot(
        isPublisherVerified: false,
        manifests: [],
      );
    }
    final envelope = _asStringMap(response);
    final payload = _asStringMap(envelope['payload']);
    if (envelope['envelopeVersion'] != 1 ||
        envelope['publisher'] is! String ||
        envelope['signingKeyId'] is! String ||
        envelope['issuedAt'] is! String ||
        envelope['expiresAt'] is! String ||
        envelope['signature'] is! String ||
        payload['catalogVersion'] != 1 ||
        payload['modules'] is! List) {
      throw const FormatException('Unsupported signed game catalog envelope.');
    }

    final publisher = envelope['publisher']! as String;
    final keyId = envelope['signingKeyId']! as String;
    if (publisher.trim().isEmpty || keyId.trim().isEmpty) {
      throw const FormatException('Catalog publisher and key ID are required.');
    }
    final issuedAtRaw = envelope['issuedAt']! as String;
    final expiresAtRaw = envelope['expiresAt']! as String;
    final issuedAt = DateTime.tryParse(issuedAtRaw)?.toUtc();
    final expiresAt = DateTime.tryParse(expiresAtRaw)?.toUtc();
    final now = (_clock?.call() ?? DateTime.now()).toUtc();
    if (issuedAt == null ||
        expiresAt == null ||
        (!allowExpired && !expiresAt.isAfter(now)) ||
        expiresAt.isBefore(issuedAt) ||
        issuedAt.isAfter(now.add(const Duration(minutes: 5)))) {
      throw const FormatException(
        'Game catalog envelope is expired or invalid.',
      );
    }
    final trustKey = trustedKeys[keyId];
    if (trustKey == null || trustKey.publisher != publisher) {
      throw const FormatException('Game catalog publisher is not trusted.');
    }
    final signatureBytes = _decodeBase64Url(envelope['signature']! as String);
    if (trustKey.publicKey.length != 32 ||
        signatureBytes == null ||
        signatureBytes.length != 64) {
      throw const FormatException('Invalid game catalog signature encoding.');
    }
    final verified = await _ed25519.verify(
      canonicalSignedMessage(
        publisher: publisher,
        signingKeyId: keyId,
        issuedAt: issuedAtRaw,
        expiresAt: expiresAtRaw,
        catalog: payload,
      ),
      signature: Signature(
        signatureBytes,
        publicKey: SimplePublicKey(
          trustKey.publicKey,
          type: KeyPairType.ed25519,
        ),
      ),
    );
    if (!verified) {
      throw const FormatException(
        'Game catalog publisher signature is invalid.',
      );
    }
    final rawModules = payload['modules'] as List<dynamic>;
    final moduleIds = <String>{};
    final manifests = <GameModuleManifest>[];
    for (final item in rawModules) {
      final manifest = GameModuleManifest.fromJson(
        Map<String, dynamic>.from(item as Map),
      );
      if (!moduleIds.add(manifest.moduleId)) {
        throw FormatException(
          'Catalog contains duplicate module ${manifest.moduleId}.',
        );
      }
      manifests.add(manifest);
    }
    if (manifests.any((manifest) => manifest.publisher != publisher)) {
      throw const FormatException(
        'Catalog contains a module from another publisher.',
      );
    }
    return GameResourceCatalogSnapshot(
      isPublisherVerified: true,
      manifests: List.unmodifiable(manifests),
      issuedAt: issuedAt,
      expiresAt: expiresAt,
      signedEnvelope: Map.unmodifiable(envelope),
    );
  }

  static Map<String, dynamic> _asStringMap(Object? value) {
    if (value is! Map) {
      throw const FormatException('Invalid game catalog object.');
    }
    try {
      return Map<String, dynamic>.from(value);
    } on Object {
      throw const FormatException('Game catalog keys must be strings.');
    }
  }

  static List<int>? _decodeBase64Url(String value) {
    try {
      return base64Url.decode(base64Url.normalize(value));
    } on FormatException {
      return null;
    }
  }

  static String _canonicalJson(Object? value) {
    if (value == null || value is bool || value is String || value is num) {
      return jsonEncode(value);
    }
    if (value is List) {
      return '[${value.map(_canonicalJson).join(',')}]';
    }
    if (value is Map) {
      final entries = <MapEntry<String, Object?>>[];
      for (final entry in value.entries) {
        if (entry.key is! String) {
          throw const FormatException('Catalog object keys must be strings.');
        }
        entries.add(MapEntry(entry.key as String, entry.value));
      }
      entries.sort((left, right) => left.key.compareTo(right.key));
      return '{${entries.map((entry) => '${jsonEncode(entry.key)}:${_canonicalJson(entry.value)}').join(',')}}';
    }
    throw const FormatException('Catalog contains a non-JSON value.');
  }
}
