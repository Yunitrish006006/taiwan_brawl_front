import 'dart:async';
import 'dart:collection';
import 'dart:convert';

import 'package:crypto/crypto.dart';

import 'street_scrap_inventory.dart';

const streetScrapProgressSchemaVersion = 1;
const _maximumCommandReceipts = 256;
const streetScrapTransferFormat = 'taiwan-brawl.street-scrap.save';
const streetScrapTransferFormatVersion = 1;
const streetScrapTransferMaximumBytes = 5 * 1024 * 1024;

/// The host must atomically compare and replace a slot and retain its two
/// previous valid snapshots. A null expected revision means the slot is empty.
abstract interface class StreetScrapProgressStore {
  Future<Map<String, Object?>?> read(String slotKey);

  Future<bool> compareAndSwap({
    required String slotKey,
    required int? expectedRevision,
    required Map<String, Object?> nextSnapshot,
  });
}

class StreetScrapRecoveryCandidate {
  const StreetScrapRecoveryCandidate({
    required this.snapshot,
    required this.isCurrent,
  });

  final StreetScrapProgressSnapshot snapshot;
  final bool isCurrent;
}

class StreetScrapRecoveryReport {
  const StreetScrapRecoveryReport({
    required this.storageToken,
    required this.currentSnapshotIsDamaged,
    required this.candidates,
  });

  /// Opaque token for the exact stored history inspected by the player.
  final String storageToken;
  final bool currentSnapshotIsDamaged;
  final List<StreetScrapRecoveryCandidate> candidates;
}

abstract interface class StreetScrapRecoveryStore
    implements StreetScrapProgressStore {
  Future<StreetScrapRecoveryReport> inspectRecovery(String slotKey);

  /// Restores a player-selected prior snapshot only if storage still matches
  /// the inspected token. The restored data is written as a new revision.
  Future<StreetScrapProgressSnapshot> restoreBackup({
    required String slotKey,
    required int backupRevision,
    required String expectedStorageToken,
  });
}

abstract interface class StreetScrapWriterLease {
  Future<void> release();
}

abstract interface class StreetScrapWriterLeaseStore {
  /// Returns null when another page or session already owns the write lease.
  Future<StreetScrapWriterLease?> acquireWriterLease(String slotKey);
}

class StreetScrapProgressSnapshot {
  StreetScrapProgressSnapshot._({
    required this.schemaVersion,
    required this.rulesetVersion,
    required this.contentVersions,
    required this.revision,
    required this.savedAt,
    required this.state,
    required this.commandReceipts,
    required this.checksum,
  });

  final int schemaVersion;
  final int rulesetVersion;
  final Map<String, String> contentVersions;
  final int revision;
  final DateTime savedAt;
  final Map<String, Object?> state;
  final Map<String, Map<String, Object?>> commandReceipts;
  final String checksum;

  factory StreetScrapProgressSnapshot.create({
    required int rulesetVersion,
    required Map<String, String> contentVersions,
    required int revision,
    required DateTime savedAt,
    required Map<String, Object?> state,
    required Map<String, Map<String, Object?>> commandReceipts,
  }) {
    if (rulesetVersion < 1 || revision < 0) {
      throw const FormatException('Invalid Street Scrap save version.');
    }
    if (contentVersions.entries.any(
      (entry) => entry.key.trim().isEmpty || !_isSemVer(entry.value),
    )) {
      throw const FormatException('Invalid Street Scrap content version map.');
    }
    final versions = Map<String, String>.unmodifiable(contentVersions);
    final frozenState = _freezeMap(state);
    final receipts = Map<String, Map<String, Object?>>.unmodifiable({
      for (final entry in commandReceipts.entries)
        entry.key: _freezeMap(entry.value),
    });
    final timestamp = savedAt.toUtc();
    final payload = _snapshotPayload(
      schemaVersion: streetScrapProgressSchemaVersion,
      rulesetVersion: rulesetVersion,
      contentVersions: versions,
      revision: revision,
      savedAt: timestamp,
      state: frozenState,
      commandReceipts: receipts,
    );
    return StreetScrapProgressSnapshot._(
      schemaVersion: streetScrapProgressSchemaVersion,
      rulesetVersion: rulesetVersion,
      contentVersions: versions,
      revision: revision,
      savedAt: timestamp,
      state: frozenState,
      commandReceipts: receipts,
      checksum: sha256.convert(utf8.encode(_canonicalJson(payload))).toString(),
    );
  }

  factory StreetScrapProgressSnapshot.fromJson(Map<String, Object?> json) {
    const expectedKeys = {
      'schemaVersion',
      'rulesetVersion',
      'contentVersions',
      'revision',
      'savedAt',
      'state',
      'commandReceipts',
      'checksum',
    };
    if (!json.keys.toSet().containsAll(expectedKeys) ||
        json.keys.any((key) => !expectedKeys.contains(key))) {
      throw const FormatException('Unknown Street Scrap save envelope field.');
    }
    final schema = json['schemaVersion'];
    if (schema is! int || schema != streetScrapProgressSchemaVersion) {
      throw FormatException('Unsupported Street Scrap save schema: $schema.');
    }
    final ruleset = json['rulesetVersion'];
    final revision = json['revision'];
    final timestamp = json['savedAt'];
    final rawVersions = json['contentVersions'];
    final rawState = json['state'];
    final rawReceipts = json['commandReceipts'];
    final storedChecksum = json['checksum'];
    if (ruleset is! int ||
        revision is! int ||
        timestamp is! String ||
        rawVersions is! Map ||
        rawState is! Map ||
        rawReceipts is! Map ||
        storedChecksum is! String) {
      throw const FormatException('Malformed Street Scrap save envelope.');
    }
    final versions = <String, String>{};
    for (final entry in rawVersions.entries) {
      if (entry.key is! String || entry.value is! String) {
        throw const FormatException('Invalid content version map.');
      }
      versions[entry.key as String] = entry.value as String;
    }
    final receipts = <String, Map<String, Object?>>{};
    for (final entry in rawReceipts.entries) {
      if (entry.key is! String || entry.value is! Map) {
        throw const FormatException('Invalid command receipt map.');
      }
      final receipt = Map<String, Object?>.from(entry.value as Map);
      if (receipt['revision'] is! int ||
          (receipt['revision']! as int) < 1 ||
          (receipt['revision']! as int) > revision ||
          !receipt.containsKey('result')) {
        throw const FormatException('Invalid command receipt.');
      }
      receipts[entry.key as String] = receipt;
    }
    final savedAt = DateTime.tryParse(timestamp)?.toUtc();
    if (savedAt == null) {
      throw const FormatException('Invalid Street Scrap save timestamp.');
    }
    final snapshot = StreetScrapProgressSnapshot.create(
      rulesetVersion: ruleset,
      contentVersions: versions,
      revision: revision,
      savedAt: savedAt,
      state: Map<String, Object?>.from(rawState),
      commandReceipts: receipts,
    );
    if (!_constantTimeEquals(storedChecksum, snapshot.checksum)) {
      throw const FormatException('Street Scrap save checksum mismatch.');
    }
    // Older builds accidentally stored the q2.03 disposition string inside
    // tutorialTasks, whose contract is a map of boolean completion flags.
    // Verify the original envelope first, then normalize that known legacy
    // shape in memory so existing saves remain playable without data loss.
    final rawTasks = snapshot.state['tutorialTasks'];
    if (rawTasks is Map &&
        const {'keep', 'fillet'}.contains(rawTasks['q2.03Choice'])) {
      final tasks = Map<String, Object?>.from(rawTasks)..remove('q2.03Choice');
      final normalizedState = Map<String, Object?>.from(snapshot.state)
        ..['tutorialTasks'] = tasks;
      final topLevelChoice = normalizedState['q2.03Choice'];
      if (!const {'keep', 'fillet'}.contains(topLevelChoice)) {
        normalizedState['q2.03Choice'] = rawTasks['q2.03Choice'];
      }
      return StreetScrapProgressSnapshot.create(
        rulesetVersion: snapshot.rulesetVersion,
        contentVersions: snapshot.contentVersions,
        revision: snapshot.revision,
        savedAt: snapshot.savedAt,
        state: normalizedState,
        commandReceipts: snapshot.commandReceipts,
      );
    }
    return snapshot;
  }

  Map<String, Object?> toJson() => {
    ..._snapshotPayload(
      schemaVersion: schemaVersion,
      rulesetVersion: rulesetVersion,
      contentVersions: contentVersions,
      revision: revision,
      savedAt: savedAt,
      state: state,
      commandReceipts: commandReceipts,
    ),
    'checksum': checksum,
  };
}

/// A single-file, checksummed save transfer. The snapshot has its own checksum
/// as well, so transport corruption and save-envelope corruption are detected
/// independently before an import can reach the local store.
class StreetScrapSaveTransfer {
  const StreetScrapSaveTransfer._(this.snapshot);

  final StreetScrapProgressSnapshot snapshot;

  factory StreetScrapSaveTransfer.fromSnapshot(
    StreetScrapProgressSnapshot snapshot,
  ) => StreetScrapSaveTransfer._(snapshot);

  factory StreetScrapSaveTransfer.decodeBytes(List<int> bytes) {
    if (bytes.isEmpty || bytes.length > streetScrapTransferMaximumBytes) {
      throw const FormatException(
        'Street Scrap transfer file size is invalid.',
      );
    }
    final decoded = jsonDecode(utf8.decode(bytes));
    if (decoded is! Map) {
      throw const FormatException('Malformed Street Scrap transfer file.');
    }
    final envelope = Map<String, Object?>.from(decoded);
    const expectedKeys = {'format', 'formatVersion', 'snapshot', 'checksum'};
    if (envelope.keys.toSet().length != expectedKeys.length ||
        envelope.keys.any((key) => !expectedKeys.contains(key)) ||
        envelope['format'] != streetScrapTransferFormat ||
        envelope['formatVersion'] != streetScrapTransferFormatVersion ||
        envelope['snapshot'] is! Map ||
        envelope['checksum'] is! String) {
      throw const FormatException(
        'Unsupported or malformed Street Scrap transfer format.',
      );
    }
    final payload = {
      'format': envelope['format'],
      'formatVersion': envelope['formatVersion'],
      'snapshot': envelope['snapshot'],
    };
    final expectedChecksum = sha256
        .convert(utf8.encode(_canonicalJson(payload)))
        .toString();
    if (!_constantTimeEquals(
      envelope['checksum']! as String,
      expectedChecksum,
    )) {
      throw const FormatException('Street Scrap transfer checksum mismatch.');
    }
    return StreetScrapSaveTransfer._(
      StreetScrapProgressSnapshot.fromJson(
        Map<String, Object?>.from(envelope['snapshot'] as Map),
      ),
    );
  }

  List<int> encodeBytes() {
    final payload = {
      'format': streetScrapTransferFormat,
      'formatVersion': streetScrapTransferFormatVersion,
      'snapshot': snapshot.toJson(),
    };
    final checksum = sha256
        .convert(utf8.encode(_canonicalJson(payload)))
        .toString();
    final bytes = utf8.encode(jsonEncode({...payload, 'checksum': checksum}));
    if (bytes.length > streetScrapTransferMaximumBytes) {
      throw const FormatException('Street Scrap save is too large to export.');
    }
    return bytes;
  }
}

class StreetScrapStaleRevision implements Exception {
  const StreetScrapStaleRevision(this.expected, this.actual);

  final int expected;
  final int actual;

  @override
  String toString() =>
      'Street Scrap revision conflict: expected $expected, actual $actual.';
}

class StreetScrapConcurrentWrite implements Exception {
  const StreetScrapConcurrentWrite(this.expectedRevision);

  final int expectedRevision;

  @override
  String toString() =>
      'Street Scrap changed in another writer at revision $expectedRevision.';
}

class StreetScrapReadOnlySession implements Exception {
  const StreetScrapReadOnlySession();

  @override
  String toString() =>
      'This Street Scrap save is open in another page and is read-only here.';
}

class StreetScrapCommandResult {
  const StreetScrapCommandResult({
    required this.revision,
    required this.result,
    required this.wasDuplicate,
  });

  final int revision;
  final Object? result;
  final bool wasDuplicate;
}

class StreetScrapReduction {
  const StreetScrapReduction({required this.state, this.result});

  final Map<String, Object?> state;
  final Object? result;
}

typedef StreetScrapReducer =
    StreetScrapReduction Function(Map<String, Object?> currentState);

typedef StreetScrapInventoryReducer =
    StreetScrapInventory Function(StreetScrapInventory currentInventory);

/// A profile-scoped local session. It never receives authentication tokens or
/// network dependencies; the application supplies the durable store port.
class StreetScrapSession {
  static final Map<String, StreetScrapSession> _activeWriters = {};

  StreetScrapSession({
    required String profileScope,
    required StreetScrapProgressStore store,
    required Map<String, String> contentVersions,
    Map<String, Set<String>> compatibleContentVersions = const {},
    required this.rulesetVersion,
    DateTime Function()? clock,
  }) : _store = store,
       _clock = clock ?? DateTime.now,
       contentVersions = Map.unmodifiable(contentVersions),
       compatibleContentVersions = Map.unmodifiable({
         for (final entry in compatibleContentVersions.entries)
           entry.key: Set<String>.unmodifiable(entry.value),
       }),
       slotKey = _makeSlotKey(profileScope) {
    if (profileScope.trim().isEmpty || rulesetVersion < 1) {
      throw ArgumentError('A profile scope and positive ruleset are required.');
    }
  }

  final StreetScrapProgressStore _store;
  final DateTime Function() _clock;
  final String slotKey;
  final int rulesetVersion;
  final Map<String, String> contentVersions;
  final Map<String, Set<String>> compatibleContentVersions;
  StreetScrapProgressSnapshot? _snapshot;
  bool _persisted = false;
  bool _isWriter = false;
  bool _closed = false;
  bool _closing = false;
  StreetScrapWriterLease? _writerLease;
  final Completer<void> _closeSignal = Completer<void>();
  Future<void>? _closeFuture;
  Future<void> _tail = Future<void>.value();

  bool get isReadOnly => !_isWriter;

  StreetScrapProgressSnapshot get snapshot =>
      _snapshot ?? (throw StateError('Street Scrap session is not loaded.'));

  Future<void> load() => _serialize(() async {
    if (_closed) throw StateError('Street Scrap session is closed.');
    while (true) {
      final currentWriter = _activeWriters[slotKey];
      if (currentWriter != null &&
          !identical(currentWriter, this) &&
          currentWriter._closing) {
        // A route can be disposed and reopened before its async close has
        // released the browser/native writer lease. Wait for that teardown,
        // then compete for ownership normally instead of becoming read-only.
        await currentWriter._closeSignal.future;
        continue;
      }
      if (currentWriter == null || identical(currentWriter, this)) {
        _activeWriters[slotKey] = this;
        final leaseStore = _store;
        if (leaseStore is StreetScrapWriterLeaseStore) {
          _writerLease ??= await (leaseStore as StreetScrapWriterLeaseStore)
              .acquireWriterLease(slotKey);
          _isWriter = _writerLease != null;
          if (!_isWriter && identical(_activeWriters[slotKey], this)) {
            _activeWriters.remove(slotKey);
          }
        } else {
          _isWriter = true;
        }
        break;
      } else {
        _isWriter = false;
        break;
      }
    }
    final raw = await _store.read(slotKey);
    if (raw == null) {
      _snapshot = StreetScrapProgressSnapshot.create(
        rulesetVersion: rulesetVersion,
        contentVersions: contentVersions,
        revision: 0,
        savedAt: _clock(),
        state: const {},
        commandReceipts: const {},
      );
      _persisted = false;
      return;
    }
    final restored = StreetScrapProgressSnapshot.fromJson(raw);
    if (restored.rulesetVersion != rulesetVersion) {
      throw FormatException(
        'Save ruleset ${restored.rulesetVersion} is incompatible with $rulesetVersion.',
      );
    }
    _snapshot = restored;
    _persisted = true;
  });

  Future<void> close() {
    final existing = _closeFuture;
    if (existing != null) return existing;
    _closing = true;
    return _closeFuture = _serialize(() async {
      try {
        await _writerLease?.release();
      } finally {
        if (identical(_activeWriters[slotKey], this)) {
          _activeWriters.remove(slotKey);
        }
        _writerLease = null;
        _isWriter = false;
        _closed = true;
        if (!_closeSignal.isCompleted) _closeSignal.complete();
      }
    });
  }

  Future<StreetScrapRecoveryReport> inspectRecovery() async {
    final recoveryStore = _store;
    if (recoveryStore is! StreetScrapRecoveryStore) {
      throw UnsupportedError('The host store does not support save recovery.');
    }
    return recoveryStore.inspectRecovery(slotKey);
  }

  Future<void> restoreBackup({
    required int backupRevision,
    required String expectedStorageToken,
  }) => _serialize(() async {
    _ensureWritable();
    final recoveryStore = _store;
    if (recoveryStore is! StreetScrapRecoveryStore) {
      throw UnsupportedError('The host store does not support save recovery.');
    }
    final report = await recoveryStore.inspectRecovery(slotKey);
    if (!report.currentSnapshotIsDamaged ||
        report.storageToken != expectedStorageToken) {
      throw const StreetScrapConcurrentWrite(-1);
    }
    final candidate = report.candidates
        .where(
          (item) => !item.isCurrent && item.snapshot.revision == backupRevision,
        )
        .firstOrNull;
    if (candidate == null) {
      throw const FormatException(
        'The selected Street Scrap backup is unavailable.',
      );
    }
    if (candidate.snapshot.rulesetVersion != rulesetVersion) {
      throw FormatException(
        'Backup ruleset ${candidate.snapshot.rulesetVersion} is incompatible with $rulesetVersion.',
      );
    }
    final restored = await recoveryStore.restoreBackup(
      slotKey: slotKey,
      backupRevision: backupRevision,
      expectedStorageToken: expectedStorageToken,
    );
    _snapshot = restored;
    _persisted = true;
  });

  /// Imports a reviewed transfer atomically. The host store's CAS history keeps
  /// the previous local snapshot available for recovery if the import succeeds.
  Future<void> importTransfer({
    required StreetScrapSaveTransfer transfer,
    required void Function(Map<String, Object?> state) validateState,
  }) => _serialize(() async {
    _ensureWritable();
    final imported = transfer.snapshot;
    if (imported.rulesetVersion != rulesetVersion) {
      throw const FormatException('Incompatible Street Scrap ruleset version.');
    }
    const requiredBaseContent = 'game.street-scrap.content.chapters-0-4';
    if (!imported.contentVersions.containsKey(requiredBaseContent)) {
      throw const FormatException('Street Scrap save is missing base content.');
    }
    for (final entry in imported.contentVersions.entries) {
      if (entry.key == 'game.street-scrap.content.active') continue;
      if (contentVersions[entry.key] != entry.value &&
          compatibleContentVersions[entry.key]?.contains(entry.value) != true) {
        throw FormatException(
          'Street Scrap content version mismatch for ${entry.key}.',
        );
      }
    }
    final chapter = imported.state['chapter'] ?? 0;
    if (chapter is! int || chapter < 0 || chapter > 5) {
      throw const FormatException('Invalid Street Scrap chapter in save.');
    }
    validateState(imported.state);
    final current = snapshot;
    final next = StreetScrapProgressSnapshot.create(
      rulesetVersion: rulesetVersion,
      contentVersions: contentVersions,
      revision: current.revision + 1,
      savedAt: _clock(),
      state: imported.state,
      // Receipts belong to the source device and must not deduplicate commands
      // generated in this local session.
      commandReceipts: const {},
    );
    final committed = await _store.compareAndSwap(
      slotKey: slotKey,
      expectedRevision: _persisted ? current.revision : null,
      nextSnapshot: next.toJson(),
    );
    if (!committed) throw StreetScrapConcurrentWrite(current.revision);
    _snapshot = next;
    _persisted = true;
  });

  Future<StreetScrapCommandResult> apply({
    required String commandId,
    required int expectedRevision,
    required StreetScrapReducer reduce,
  }) => _serialize(() async {
    _ensureWritable();
    final current = snapshot;
    if (commandId.trim().isEmpty) {
      throw ArgumentError.value(commandId, 'commandId');
    }
    final receipt = current.commandReceipts[commandId];
    if (receipt != null) {
      return StreetScrapCommandResult(
        revision: receipt['revision']! as int,
        result: receipt['result'],
        wasDuplicate: true,
      );
    }
    if (expectedRevision != current.revision) {
      throw StreetScrapStaleRevision(expectedRevision, current.revision);
    }
    final reduction = reduce(current.state);
    final nextState = _recordCollectionDiscoveries(
      current.state,
      reduction.state,
    );
    _validateCraftReservationsRaw(current.state, nextState, commandId);
    final receipts = Map<String, Map<String, Object?>>.from(
      current.commandReceipts,
    );
    receipts[commandId] = {
      'revision': current.revision + 1,
      'result': reduction.result,
    };
    while (receipts.length > _maximumCommandReceipts) {
      receipts.remove(receipts.keys.first);
    }
    final next = StreetScrapProgressSnapshot.create(
      rulesetVersion: rulesetVersion,
      contentVersions: contentVersions,
      revision: current.revision + 1,
      savedAt: _clock(),
      state: nextState,
      commandReceipts: receipts,
    );
    final committed = await _store.compareAndSwap(
      slotKey: slotKey,
      expectedRevision: _persisted ? current.revision : null,
      nextSnapshot: next.toJson(),
    );
    if (!committed) {
      throw StreetScrapConcurrentWrite(current.revision);
    }
    _snapshot = next;
    _persisted = true;
    return StreetScrapCommandResult(
      revision: next.revision,
      result: reduction.result,
      wasDuplicate: false,
    );
  });

  Map<String, Object?> _recordCollectionDiscoveries(
    Map<String, Object?> currentState,
    Map<String, Object?> nextState,
  ) {
    final existingValue = currentState['collectionItemIds'];
    if (existingValue != null &&
        (existingValue is! List || existingValue.any((id) => id is! String))) {
      throw const FormatException('Malformed Street Scrap collection state.');
    }
    final discovered = <String>{
      if (existingValue is List) ...existingValue.cast<String>(),
    };
    late void Function(Object?) collectObject;
    collectObject = (Object? value) {
      if (value == null) return;
      if (value is! Map || value['itemId'] is! String) {
        throw const FormatException('Malformed collected inventory object.');
      }
      discovered.add(value['itemId'] as String);
      final contents = value['containerContents'];
      if (contents != null) {
        if (contents is! List) {
          throw const FormatException(
            'Malformed collected container contents.',
          );
        }
        for (final child in contents) {
          collectObject(child);
        }
      }
    };

    void collectInventory(Object? value) {
      if (value == null) return;
      if (value is! Map) {
        throw const FormatException(
          'Malformed inventory in collection update.',
        );
      }
      final objects = value['objects'];
      if (objects == null) return;
      if (objects is! List) {
        throw const FormatException(
          'Malformed inventory objects in collection update.',
        );
      }
      for (final object in objects) {
        collectObject(object);
      }
    }

    collectInventory(nextState['inventory']);
    if (discovered.isEmpty && existingValue == null) return nextState;
    final sorted = discovered.toList()..sort();
    return {...nextState, 'collectionItemIds': sorted};
  }

  /// Applies a pure inventory operation and stores its complete result through
  /// the same command receipt and revision/CAS boundary as every other change.
  Future<StreetScrapCommandResult> applyInventoryCommand({
    required String commandId,
    required int expectedRevision,
    required StreetScrapInventoryCatalog catalog,
    required Map<String, StreetScrapGridSpec> grids,
    required StreetScrapInventoryReducer reduceInventory,
    Object? result,
    StreetScrapInventory? initialInventory,
  }) => apply(
    commandId: commandId,
    expectedRevision: expectedRevision,
    reduce: (state) {
      final raw = state['inventory'];
      final current = raw == null
          ? initialInventory == null
                ? catalog.emptyInventory(grids: grids)
                : catalog.inventoryFromJson(
                    grids: grids,
                    json: initialInventory.toJson(),
                  )
          : raw is Map
          ? catalog.inventoryFromJson(
              grids: grids,
              json: Map<String, Object?>.from(raw),
            )
          : throw const FormatException(
              'Malformed saved Street Scrap inventory.',
            );
      final next = reduceInventory(current);
      _validateCraftReservations(current, next, state['craftOperation']);
      return StreetScrapReduction(
        state: {...state, 'inventory': next.toJson()},
        result: result,
      );
    },
  );

  Future<T> _serialize<T>(Future<T> Function() operation) async {
    final previous = _tail;
    final release = Completer<void>();
    _tail = release.future;
    await previous;
    try {
      return await operation();
    } finally {
      release.complete();
    }
  }

  void _ensureWritable() {
    if (_closed) throw StateError('Street Scrap session is closed.');
    if (!_isWriter) throw const StreetScrapReadOnlySession();
  }

  void _validateCraftReservations(
    StreetScrapInventory current,
    StreetScrapInventory next,
    Object? rawOperation,
  ) {
    if (rawOperation == null) return;
    if (rawOperation is! Map ||
        rawOperation['lockedInstanceIds'] is! List ||
        (rawOperation['lockedInstanceIds'] as List).any(
          (id) => id is! String,
        )) {
      throw const FormatException('Malformed Street Scrap craft reservations.');
    }
    for (final id
        in (rawOperation['lockedInstanceIds'] as List).cast<String>()) {
      final before = current.objects[id];
      final after = next.objects[id];
      final beforePlacement = current.placements[id];
      final afterPlacement = next.placements[id];
      final isStored = next.storage.values.any((ids) => ids.contains(id));
      if (before == null ||
          after == null ||
          beforePlacement == null ||
          afterPlacement == null ||
          isStored ||
          before.itemId != after.itemId ||
          before.source != after.source ||
          before.quality != after.quality ||
          before.toolDurability != after.toolDurability ||
          before.acquiredRevision != after.acquiredRevision ||
          before.rotation != after.rotation ||
          before.footprint.width != after.footprint.width ||
          before.footprint.height != after.footprint.height ||
          jsonEncode(before.traits) != jsonEncode(after.traits) ||
          jsonEncode(before.containerState) !=
              jsonEncode(after.containerState) ||
          jsonEncode(before.provenance) != jsonEncode(after.provenance) ||
          before.containerContents.isNotEmpty ||
          after.containerContents.isNotEmpty ||
          beforePlacement.gridId != afterPlacement.gridId ||
          beforePlacement.x != afterPlacement.x ||
          beforePlacement.y != afterPlacement.y ||
          beforePlacement.rotation != afterPlacement.rotation) {
        throw StateError('craftInputLocked:$id');
      }
    }
  }

  void _validateCraftReservationsRaw(
    Map<String, Object?> before,
    Map<String, Object?> after,
    String commandId,
  ) {
    final rawOperation = before['craftOperation'];
    if (rawOperation == null) return;
    if (rawOperation is! Map ||
        rawOperation['operationId'] is! String ||
        rawOperation['lockedInstanceIds'] is! List ||
        (rawOperation['lockedInstanceIds'] as List).any(
          (id) => id is! String,
        )) {
      throw const FormatException('Malformed Street Scrap craft reservations.');
    }
    final operationId = rawOperation['operationId'] as String;
    if (commandId == 'settle-craft-$operationId' ||
        commandId == 'clear-craft-$operationId' ||
        commandId == 'cancel-craft-$operationId') {
      return;
    }
    final nextOperation = after['craftOperation'];
    if (nextOperation is! Map || nextOperation['operationId'] != operationId) {
      throw StateError('craftOperationActive');
    }
    final beforeInventory = before['inventory'];
    final afterInventory = after['inventory'];
    Map<String, Object?> rowsById(Object? value) {
      if (value is! List) {
        throw const FormatException(
          'Malformed inventory rows while craft inputs are reserved.',
        );
      }
      final rows = <String, Object?>{};
      for (final row in value) {
        if (row is! Map ||
            row['instanceId'] is! String ||
            rows.containsKey(row['instanceId'])) {
          throw const FormatException(
            'Malformed inventory identity while craft inputs are reserved.',
          );
        }
        rows[row['instanceId'] as String] = row;
      }
      return rows;
    }

    if (beforeInventory is! Map || afterInventory is! Map) {
      throw const FormatException(
        'Malformed inventory while craft inputs are reserved.',
      );
    }
    final beforeObjects = rowsById(beforeInventory['objects']);
    final afterObjects = rowsById(afterInventory['objects']);
    final beforePlacements = rowsById(beforeInventory['placements']);
    final afterPlacements = rowsById(afterInventory['placements']);
    final afterStorage = afterInventory['storage'];
    for (final id
        in (rawOperation['lockedInstanceIds'] as List).cast<String>()) {
      if (!beforeObjects.containsKey(id) ||
          !afterObjects.containsKey(id) ||
          jsonEncode(beforeObjects[id]) != jsonEncode(afterObjects[id]) ||
          jsonEncode(beforePlacements[id]) != jsonEncode(afterPlacements[id]) ||
          (afterStorage is Map &&
              afterStorage.values.any(
                (ids) => ids is List && ids.contains(id),
              ))) {
        throw StateError('craftInputLocked:$id');
      }
    }
  }
}

String _makeSlotKey(String profileScope) {
  final profileDigest = sha256.convert(utf8.encode(profileScope.trim()));
  return 'game.street-scrap/$profileDigest/slot-1';
}

bool _isSemVer(String value) => RegExp(
  r'^(0|[1-9]\d*)\.(0|[1-9]\d*)\.(0|[1-9]\d*)(?:-[0-9A-Za-z.-]+)?(?:\+[0-9A-Za-z.-]+)?$',
).hasMatch(value);

Map<String, Object?> _snapshotPayload({
  required int schemaVersion,
  required int rulesetVersion,
  required Map<String, String> contentVersions,
  required int revision,
  required DateTime savedAt,
  required Map<String, Object?> state,
  required Map<String, Map<String, Object?>> commandReceipts,
}) => {
  'schemaVersion': schemaVersion,
  'rulesetVersion': rulesetVersion,
  'contentVersions': contentVersions,
  'revision': revision,
  'savedAt': savedAt.toUtc().toIso8601String(),
  'state': state,
  'commandReceipts': commandReceipts,
};

Map<String, Object?> _freezeMap(Map<String, Object?> source) =>
    Map<String, Object?>.unmodifiable({
      for (final entry in source.entries) entry.key: _freeze(entry.value),
    });

Object? _freeze(Object? value) {
  if (value is Map) {
    final frozen = <String, Object?>{};
    for (final entry in value.entries) {
      if (entry.key is! String) {
        throw const FormatException('Save maps must have string keys.');
      }
      frozen[entry.key as String] = _freeze(entry.value);
    }
    return Map<String, Object?>.unmodifiable(frozen);
  }
  if (value is List) return List<Object?>.unmodifiable(value.map(_freeze));
  return value;
}

String _canonicalJson(Object? value) {
  Object? canonicalize(Object? current) {
    if (current is Map) {
      final sorted = SplayTreeMap<String, Object?>();
      for (final entry in current.entries) {
        if (entry.key is! String) {
          throw const FormatException('Save maps must have string keys.');
        }
        sorted[entry.key as String] = canonicalize(entry.value);
      }
      return sorted;
    }
    if (current is List) return current.map(canonicalize).toList();
    if (current == null ||
        current is String ||
        current is num ||
        current is bool) {
      return current;
    }
    throw const FormatException('Save contains a non-JSON value.');
  }

  return jsonEncode(canonicalize(value));
}

bool _constantTimeEquals(String left, String right) {
  if (left.length != right.length) return false;
  var difference = 0;
  for (var index = 0; index < left.length; index++) {
    difference |= left.codeUnitAt(index) ^ right.codeUnitAt(index);
  }
  return difference == 0;
}
