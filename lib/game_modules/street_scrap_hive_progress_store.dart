import 'dart:async';
import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:taiwan_brawl_game_street_scrap/street_scrap_progress.dart';

import 'street_scrap_writer_lease.dart' as writer_lease;

/// Hive host adapter. Each logical write replaces one box value containing
/// the current save plus its two previous valid snapshots.
class HiveStreetScrapProgressStore
    implements StreetScrapRecoveryStore, StreetScrapWriterLeaseStore {
  HiveStreetScrapProgressStore({this.boxName = 'street_scrap_saves_v1'});

  final String boxName;
  static final Map<String, Future<void>> _queues = {};

  Future<Box<String>> _open() => Hive.openBox<String>(boxName);

  String _key(String slotKey) => 'save:$slotKey';

  @override
  Future<StreetScrapWriterLease?> acquireWriterLease(String slotKey) =>
      writer_lease.acquireStreetScrapWriterLease(slotKey);

  @override
  Future<Map<String, Object?>?> read(String slotKey) async {
    final box = await _open();
    final encoded = box.get(_key(slotKey));
    if (encoded == null) return null;
    final snapshots = _decodeHistory(encoded);
    if (snapshots.isEmpty) {
      throw const FormatException('No Street Scrap save snapshot exists.');
    }
    // Do not silently roll back. The caller can present recovery candidates
    // and require an explicit player choice before activating an older copy.
    return StreetScrapProgressSnapshot.fromJson(snapshots.first).toJson();
  }

  /// Returns the valid copies newest-first so the UI can offer explicit
  /// recovery when the latest snapshot is damaged.
  @override
  Future<StreetScrapRecoveryReport> inspectRecovery(
    String slotKey,
  ) async {
    final box = await _open();
    final encoded = box.get(_key(slotKey));
    if (encoded == null) {
      return const StreetScrapRecoveryReport(
        storageToken: '',
        currentSnapshotIsDamaged: false,
        candidates: [],
      );
    }
    final rows = _decodeHistory(encoded);
    final valid = <StreetScrapRecoveryCandidate>[];
    var headDamaged = true;
    for (var index = 0; index < rows.length; index++) {
      try {
        final snapshot = StreetScrapProgressSnapshot.fromJson(rows[index]);
        if (index == 0) headDamaged = false;
        valid.add(StreetScrapRecoveryCandidate(
          snapshot: snapshot,
          isCurrent: index == 0,
        ));
      } on Object {
        continue;
      }
    }
    return StreetScrapRecoveryReport(
      storageToken: sha256.convert(utf8.encode(encoded)).toString(),
      currentSnapshotIsDamaged: headDamaged,
      candidates: List.unmodifiable(valid),
    );
  }

  @override
  Future<StreetScrapProgressSnapshot> restoreBackup({
    required String slotKey,
    required int backupRevision,
    required String expectedStorageToken,
  }) => _serialize(slotKey, () async {
    final box = await _open();
    final key = _key(slotKey);
    final encoded = box.get(key);
    if (encoded == null ||
        sha256.convert(utf8.encode(encoded)).toString() !=
            expectedStorageToken) {
      throw const StreetScrapConcurrentWrite(-1);
    }
    final rows = _decodeHistory(encoded);
    if (rows.isEmpty) {
      throw const FormatException('No Street Scrap backup can be restored.');
    }
    var headIsValid = false;
    try {
      StreetScrapProgressSnapshot.fromJson(rows.first);
      headIsValid = true;
    } on Object {
      // Recovery is allowed only after the current snapshot fails validation.
    }
    if (headIsValid) {
      throw StateError('The current save is valid; recovery is not required.');
    }

    StreetScrapProgressSnapshot? selected;
    var selectedIndex = -1;
    var maximumValidRevision = -1;
    final validHistory = <StreetScrapProgressSnapshot>[];
    for (var index = 1; index < rows.length; index++) {
      try {
        final snapshot = StreetScrapProgressSnapshot.fromJson(rows[index]);
        validHistory.add(snapshot);
        if (snapshot.revision > maximumValidRevision) {
          maximumValidRevision = snapshot.revision;
        }
        if (snapshot.revision == backupRevision) {
          selected = snapshot;
          selectedIndex = index;
        }
      } on Object {
        continue;
      }
    }
    if (selected == null || selectedIndex < 1) {
      throw const FormatException('The selected Street Scrap backup is unavailable.');
    }
    final restored = StreetScrapProgressSnapshot.create(
      rulesetVersion: selected.rulesetVersion,
      contentVersions: selected.contentVersions,
      revision: maximumValidRevision + 1,
      savedAt: DateTime.now().toUtc(),
      state: selected.state,
      commandReceipts: selected.commandReceipts,
    );
    final retained = <Map<String, Object?>>[
      restored.toJson(),
      selected.toJson(),
    ];
    for (var index = selectedIndex + 1;
        index < rows.length && retained.length < 3;
        index++) {
      final prior = _tryParseSnapshot(rows[index]);
      if (prior != null) retained.add(prior.toJson());
    }
    await box.put(key, jsonEncode(retained));
    return restored;
  });

  @override
  Future<bool> compareAndSwap({
    required String slotKey,
    required int? expectedRevision,
    required Map<String, Object?> nextSnapshot,
  }) => _serialize(slotKey, () async {
    final candidate = StreetScrapProgressSnapshot.fromJson(nextSnapshot);
    final box = await _open();
    final key = _key(slotKey);
    final encoded = box.get(key);
    final history = encoded == null ? <Map<String, Object?>>[] : _decodeHistory(encoded);
    if (history.isNotEmpty) {
      try {
        StreetScrapProgressSnapshot.fromJson(history.first);
      } on Object {
        // A damaged head requires explicit recovery; never write over it.
        return false;
      }
    }
    final validHistory = <StreetScrapProgressSnapshot>[];
    for (final row in history) {
      try {
        validHistory.add(StreetScrapProgressSnapshot.fromJson(row));
      } on Object {
        continue;
      }
    }
    final currentRevision = validHistory.isEmpty
        ? null
        : validHistory.first.revision;
    if (currentRevision != expectedRevision ||
        candidate.revision != (expectedRevision ?? 0) + 1) {
      return false;
    }
    final retained = <Map<String, Object?>>[
      candidate.toJson(),
      for (final previous in validHistory.take(2)) previous.toJson(),
    ];
    await box.put(key, jsonEncode(retained));
    return true;
  });

  List<Map<String, Object?>> _decodeHistory(String encoded) {
    final decoded = jsonDecode(encoded);
    if (decoded is! List) {
      throw const FormatException('Invalid Street Scrap save history.');
    }
    final snapshots = <Map<String, Object?>>[];
    for (final row in decoded) {
      try {
        snapshots.add(
          row is Map ? Map<String, Object?>.from(row) : <String, Object?>{},
        );
      } on Object {
        snapshots.add(<String, Object?>{});
      }
    }
    return snapshots;
  }

  StreetScrapProgressSnapshot? _tryParseSnapshot(Map<String, Object?> row) {
    try {
      return StreetScrapProgressSnapshot.fromJson(row);
    } on Object {
      return null;
    }
  }

  Future<T> _serialize<T>(String slotKey, Future<T> Function() operation) async {
    final key = '$boxName:$slotKey';
    final previous = _queues[key] ?? Future<void>.value();
    final release = Completer<void>();
    _queues[key] = release.future;
    await previous;
    try {
      return await operation();
    } finally {
      release.complete();
      if (identical(_queues[key], release.future)) _queues.remove(key);
    }
  }
}
