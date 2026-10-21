import 'dart:async';

import 'archery_game_module.dart';

/// Host-provided durable storage boundary; the game owns keys and schema.
abstract interface class ArcheryPlayerDataBackend {
  Future<Object?> read(String key);
  Future<void> write(String key, Object value);
  Future<void> delete(String key);
}

class ArcheryPlayerProgress {
  const ArcheryPlayerProgress({required this.highScore});

  final int highScore;

  Map<String, Object?> toJson() => {'highScore': highScore};

  factory ArcheryPlayerProgress.fromJson(Map<String, Object?> json) {
    final score = json['highScore'];
    if (score is! int || score < 0) {
      throw const FormatException('Invalid Archery player progress.');
    }
    return ArcheryPlayerProgress(highScore: score);
  }
}

typedef ArcheryProgressMigration =
    Map<String, Object?> Function(Map<String, Object?> data);

/// Versioned, profile-scoped player progress owned by the Archery module.
class ArcheryPlayerDataRepository {
  ArcheryPlayerDataRepository({
    required ArcheryPlayerDataBackend backend,
    Map<int, ArcheryProgressMigration> migrations = const {
      0: _migrateLegacyHighScore,
    },
  }) : _backend = backend,
       _migrations = migrations;

  final ArcheryPlayerDataBackend _backend;
  final Map<int, ArcheryProgressMigration> _migrations;
  static final Map<String, Future<void>> _pendingOperations = {};

  String _key(String profileId) => 'profile:$profileId:progress';

  Future<ArcheryPlayerProgress> readProgress(String profileId) => _serialize(
    _key(profileId),
    () async {
      final raw = await _backend.read(_key(profileId));
      if (raw == null) return const ArcheryPlayerProgress(highScore: 0);
      if (raw is! Map || raw['schemaVersion'] is! int || raw['data'] is! Map) {
        throw const FormatException('Invalid Archery player-data envelope.');
      }
      var version = raw['schemaVersion']! as int;
      if (version > archeryGameDataSchemaVersion || version < 0) {
        throw FormatException('Unsupported Archery data schema $version.');
      }
      var data = Map<String, Object?>.from(raw['data']! as Map);
      while (version < archeryGameDataSchemaVersion) {
        final migrate = _migrations[version];
        if (migrate == null) {
          throw FormatException(
            'Missing Archery migration from schema $version.',
          );
        }
        data = migrate(data);
        version += 1;
      }
      if (raw['schemaVersion'] != archeryGameDataSchemaVersion) {
        await _writeProgress(profileId, ArcheryPlayerProgress.fromJson(data));
      }
      return ArcheryPlayerProgress.fromJson(data);
    },
  );

  Future<void> writeProgress(
    String profileId,
    ArcheryPlayerProgress progress,
  ) => _serialize(_key(profileId), () => _writeProgress(profileId, progress));

  Future<void> _writeProgress(
    String profileId,
    ArcheryPlayerProgress progress,
  ) => _backend.write(_key(profileId), {
    'schemaVersion': archeryGameDataSchemaVersion,
    'data': progress.toJson(),
  });

  Future<void> deleteProgress(String profileId) =>
      _serialize(_key(profileId), () => _backend.delete(_key(profileId)));

  Future<T> _serialize<T>(String key, Future<T> Function() operation) async {
    final previous = _pendingOperations[key] ?? Future<void>.value();
    final release = Completer<void>();
    _pendingOperations[key] = release.future;
    await previous;
    try {
      return await operation();
    } finally {
      release.complete();
      if (identical(_pendingOperations[key], release.future)) {
        _pendingOperations.remove(key);
      }
    }
  }
}

Map<String, Object?> _migrateLegacyHighScore(Map<String, Object?> data) => {
  'highScore': data['highScore'] ?? data['best_score'] ?? 0,
};
