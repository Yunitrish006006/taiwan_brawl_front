import 'dart:async';

import 'mini_royale_module.dart';

/// Storage boundary implemented by the host; the game owns the schema above it.
abstract interface class MiniRoyalePlayerDataBackend {
  Future<Object?> read(String key);
  Future<void> write(String key, Object value);
  Future<void> delete(String key);
}

/// A small, profile-scoped deck draft. Drafts never replace server-owned decks.
class MiniRoyaleDeckDraft {
  const MiniRoyaleDeckDraft({
    required this.slot,
    required this.name,
    required this.cardIds,
    required this.heroId,
  });

  final int slot;
  final String name;
  final List<String> cardIds;
  final String heroId;

  Map<String, Object?> toJson() => {
    'slot': slot,
    'name': name,
    'cardIds': cardIds,
    'heroId': heroId,
  };

  factory MiniRoyaleDeckDraft.fromJson(Map<String, Object?> json) {
    final slot = json['slot'];
    final cardIds = json['cardIds'];
    if (slot is! int ||
        slot < 1 ||
        cardIds is! List ||
        cardIds.any((id) => id is! String) ||
        json['name'] is! String ||
        json['heroId'] is! String) {
      throw const FormatException('Invalid Mini Royale deck draft');
    }
    return MiniRoyaleDeckDraft(
      slot: slot,
      name: json['name']! as String,
      cardIds: List<String>.unmodifiable(cardIds.cast<String>()),
      heroId: json['heroId']! as String,
    );
  }
}

typedef MiniRoyalePlayerDataMigration =
    Map<String, Object?> Function(Map<String, Object?> data);

class MiniRoyalePlayerDataRepository {
  MiniRoyalePlayerDataRepository({
    required MiniRoyalePlayerDataBackend backend,
    Map<int, MiniRoyalePlayerDataMigration> migrations = const {
      0: _migrateLegacyDeckDraft,
    },
  }) : _backend = backend,
       _migrations = migrations;

  final MiniRoyalePlayerDataBackend _backend;
  final Map<int, MiniRoyalePlayerDataMigration> _migrations;
  static final Map<String, Future<void>> _pendingOperations = {};

  String _key(String profileId, int slot) =>
      'profile:$profileId:deck-draft:$slot';

  Future<MiniRoyaleDeckDraft?> readDeckDraft(
    String profileId,
    int slot,
  ) => _serialize(_key(profileId, slot), () async {
    final raw = await _backend.read(_key(profileId, slot));
    if (raw == null) {
      return null;
    }
    if (raw is! Map) {
      throw const FormatException('Invalid player data envelope');
    }
    var version = raw['schemaVersion'];
    final payload = raw['data'];
    if (version is! int || payload is! Map) {
      throw const FormatException('Invalid player data envelope');
    }
    if (version > miniRoyaleDataSchemaVersion) {
      throw FormatException('Unsupported Mini Royale data schema $version');
    }
    var data = Map<String, Object?>.from(payload);
    while (version < miniRoyaleDataSchemaVersion) {
      final migration = _migrations[version];
      if (migration == null) {
        throw FormatException(
          'Missing Mini Royale data migration from $version',
        );
      }
      data = migration(data);
      version += 1;
    }
    // Validate the fully migrated value before replacing the persisted source.
    // A malformed legacy record must remain recoverable for a later repair.
    final draft = MiniRoyaleDeckDraft.fromJson(data);
    if (draft.slot != slot) {
      throw FormatException(
        'Mini Royale draft slot ${draft.slot} does not match requested slot $slot',
      );
    }
    if (raw['schemaVersion'] != miniRoyaleDataSchemaVersion) {
      await _writeUnlocked(profileId, slot, data);
    }
    return draft;
  });

  Future<void> writeDeckDraft(String profileId, MiniRoyaleDeckDraft draft) =>
      _serialize(
        _key(profileId, draft.slot),
        () => _writeUnlocked(profileId, draft.slot, draft.toJson()),
      );

  Future<void> deleteDeckDraft(String profileId, int slot) => _serialize(
    _key(profileId, slot),
    () => _backend.delete(_key(profileId, slot)),
  );

  Future<void> _writeUnlocked(
    String profileId,
    int slot,
    Map<String, Object?> data,
  ) => _backend.write(_key(profileId, slot), {
    'schemaVersion': miniRoyaleDataSchemaVersion,
    'data': data,
  });

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

Map<String, Object?> _migrateLegacyDeckDraft(Map<String, Object?> data) {
  final migrated = Map<String, Object?>.from(data);
  migrated['cardIds'] ??= migrated.remove('cards');
  migrated['heroId'] ??= 'ordinary_person';
  migrated['name'] ??= 'Battle Deck';
  return migrated;
}
