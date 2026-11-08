import 'street_scrap_progress.dart';

const streetScrapReliefInterval = Duration(days: 1);
const streetScrapReliefVisibleLimit = 7;
const streetScrapReliefInitialClaims = 1;
const streetScrapReliefRestoreAmount = 40;

/// Offline relief claims with a persisted UTC high-water mark. Clock rollback
/// never removes claims or moves the accrual anchor backwards.
class StreetScrapReliefProgress {
  const StreetScrapReliefProgress({
    required this.totalClaims,
    required this.accrualAnchor,
    required this.highWater,
    required this.ended,
    required this.clockRollbackEvents,
    required this.clockRollbackActive,
  });

  final int totalClaims;
  final DateTime accrualAnchor;
  final DateTime highWater;
  final bool ended;
  final int clockRollbackEvents;
  final bool clockRollbackActive;

  int get visibleClaims => totalClaims.clamp(0, streetScrapReliefVisibleLimit);
  int get reserveClaims =>
      (totalClaims - streetScrapReliefVisibleLimit).clamp(0, totalClaims);

  factory StreetScrapReliefProgress.start(DateTime createdAt) =>
      StreetScrapReliefProgress(
        totalClaims: streetScrapReliefInitialClaims,
        accrualAnchor: createdAt.toUtc(),
        highWater: createdAt.toUtc(),
        ended: false,
        clockRollbackEvents: 0,
        clockRollbackActive: false,
      );

  factory StreetScrapReliefProgress.fromJson(Map<String, Object?> json) {
    final claims = json['totalClaims'];
    final anchor = DateTime.tryParse(json['accrualAnchor'] as String? ?? '');
    final highWater = DateTime.tryParse(json['highWater'] as String? ?? '');
    final ended = json['ended'];
    final rollbackEvents = json['clockRollbackEvents'] ?? 0;
    final rollbackActive = json['clockRollbackActive'] ?? false;
    if (claims is! int ||
        claims < 0 ||
        anchor == null ||
        highWater == null ||
        ended is! bool ||
        highWater.isBefore(anchor) ||
        rollbackEvents is! int ||
        rollbackEvents < 0 ||
        rollbackActive is! bool) {
      throw const FormatException('Malformed Street Scrap relief progress.');
    }
    return StreetScrapReliefProgress(
      totalClaims: claims,
      accrualAnchor: anchor.toUtc(),
      highWater: highWater.toUtc(),
      ended: ended,
      clockRollbackEvents: rollbackEvents,
      clockRollbackActive: rollbackActive,
    );
  }

  Map<String, Object?> toJson() => {
    'totalClaims': totalClaims,
    'accrualAnchor': accrualAnchor.toUtc().toIso8601String(),
    'highWater': highWater.toUtc().toIso8601String(),
    'ended': ended,
    'clockRollbackEvents': clockRollbackEvents,
    'clockRollbackActive': clockRollbackActive,
  };

  StreetScrapReliefProgress accrue(DateTime now) {
    if (ended) return this;
    final utcNow = now.toUtc();
    final rolledBack = utcNow.isBefore(highWater);
    final effectiveNow = utcNow.isBefore(highWater) ? highWater : utcNow;
    final elapsedSeconds = effectiveNow.difference(accrualAnchor).inSeconds;
    if (elapsedSeconds < streetScrapReliefInterval.inSeconds) {
      return StreetScrapReliefProgress(
        totalClaims: totalClaims,
        accrualAnchor: accrualAnchor,
        highWater: effectiveNow,
        ended: false,
        clockRollbackEvents:
            clockRollbackEvents + (rolledBack && !clockRollbackActive ? 1 : 0),
        clockRollbackActive: rolledBack,
      );
    }
    final earned = elapsedSeconds ~/ streetScrapReliefInterval.inSeconds;
    return StreetScrapReliefProgress(
      totalClaims: totalClaims + earned,
      accrualAnchor: accrualAnchor.add(Duration(days: earned)),
      highWater: effectiveNow,
      ended: false,
      clockRollbackEvents:
          clockRollbackEvents + (rolledBack && !clockRollbackActive ? 1 : 0),
      clockRollbackActive: rolledBack,
    );
  }

  StreetScrapReliefProgress claim() {
    if (totalClaims == 0) throw StateError('noReliefClaims');
    return StreetScrapReliefProgress(
      totalClaims: totalClaims - 1,
      accrualAnchor: accrualAnchor,
      highWater: highWater,
      ended: ended,
      clockRollbackEvents: clockRollbackEvents,
      clockRollbackActive: clockRollbackActive,
    );
  }

  StreetScrapReliefProgress stop() => StreetScrapReliefProgress(
    totalClaims: totalClaims,
    accrualAnchor: accrualAnchor,
    highWater: highWater,
    ended: true,
    clockRollbackEvents: clockRollbackEvents,
    clockRollbackActive: clockRollbackActive,
  );
}

Future<StreetScrapCommandResult> claimStreetScrapRelief({
  required StreetScrapSession session,
  required String commandId,
  required int expectedRevision,
  required DateTime now,
  required int maxStamina,
}) => session.apply(
  commandId: commandId,
  expectedRevision: expectedRevision,
  reduce: (state) {
    if (maxStamina < 1) throw ArgumentError.value(maxStamina, 'maxStamina');
    final stamina = state['stamina'] as int? ?? maxStamina;
    if (stamina < 0 || stamina > maxStamina) {
      throw StateError('invalidStamina');
    }
    if (stamina == maxStamina) throw StateError('staminaFull');
    final rawProgress = state['relief'];
    final progress = rawProgress == null
        ? StreetScrapReliefProgress.start(session.snapshot.savedAt)
        : rawProgress is Map
        ? StreetScrapReliefProgress.fromJson(
            Map<String, Object?>.from(rawProgress),
          )
        : throw const FormatException('Malformed Street Scrap relief state.');
    final nextProgress = progress.accrue(now).claim();
    final restored = (stamina + streetScrapReliefRestoreAmount).clamp(
      0,
      maxStamina,
    );
    return StreetScrapReduction(
      state: {...state, 'stamina': restored, 'relief': nextProgress.toJson()},
      result: {
        'reliefClaims': nextProgress.totalClaims,
        'recovery': streetScrapReliefRestoreAmount,
        'actualRestored': restored - stamina,
        'overflow': (stamina + streetScrapReliefRestoreAmount - maxStamina)
            .clamp(0, maxStamina),
      },
    );
  },
);

Future<StreetScrapCommandResult> finishStreetScrapRelief({
  required StreetScrapSession session,
  required String commandId,
  required int expectedRevision,
  required DateTime now,
}) => session.apply(
  commandId: commandId,
  expectedRevision: expectedRevision,
  reduce: (state) {
    final tasks = state['tutorialTasks'];
    if ((state['chapter'] as int? ?? 0) < 5 ||
        tasks is! Map ||
        tasks['q5.02'] != true ||
        state['reliefStopWarningAcknowledged'] != true) {
      throw StateError('reliefTransitionLocked');
    }
    final rawProgress = state['relief'];
    final progress = rawProgress == null
        ? StreetScrapReliefProgress.start(session.snapshot.savedAt)
        : rawProgress is Map
        ? StreetScrapReliefProgress.fromJson(
            Map<String, Object?>.from(rawProgress),
          )
        : throw const FormatException('Malformed Street Scrap relief state.');
    if (progress.ended || state['reliefTransitionSupplyGranted'] == true) {
      throw StateError('reliefTransitionAlreadyComplete');
    }
    final settled = progress.accrue(now).stop();
    final existingSupply = state['chapterSupplyBalance'] ?? 0;
    if (existingSupply is! int || existingSupply < 0) {
      throw StateError('invalidChapterSupplyBalance');
    }
    return StreetScrapReduction(
      state: {
        ...state,
        'relief': settled.toJson(),
        'chapterSupplyBalance': existingSupply + 80,
        'reliefTransitionSupplyGranted': true,
      },
      result: {
        'reliefClaims': settled.totalClaims,
        'chapterSupplyGranted': 80,
        'reliefEnded': true,
      },
    );
  },
);

Future<StreetScrapCommandResult> acknowledgeStreetScrapReliefStop({
  required StreetScrapSession session,
  required String commandId,
  required int expectedRevision,
}) => session.apply(
  commandId: commandId,
  expectedRevision: expectedRevision,
  reduce: (state) {
    final tasks = state['tutorialTasks'];
    if ((state['chapter'] as int? ?? 0) < 5 ||
        tasks is! Map ||
        tasks['q5.02'] != true) {
      throw StateError('reliefTransitionLocked');
    }
    final raw = state['relief'];
    final progress = raw is Map
        ? StreetScrapReliefProgress.fromJson(Map<String, Object?>.from(raw))
        : throw const FormatException('Malformed Street Scrap relief state.');
    if (progress.ended || state['reliefTransitionSupplyGranted'] == true) {
      throw StateError('reliefTransitionAlreadyComplete');
    }
    if (state['reliefStopWarningAcknowledged'] == true) {
      return StreetScrapReduction(
        state: state,
        result: {'acknowledged': true, 'alreadyAcknowledged': true},
      );
    }
    return StreetScrapReduction(
      state: {...state, 'reliefStopWarningAcknowledged': true},
      result: {'acknowledged': true},
    );
  },
);

Future<StreetScrapCommandResult> claimStreetScrapChapterSupply({
  required StreetScrapSession session,
  required String commandId,
  required int expectedRevision,
  required int maxStamina,
}) => session.apply(
  commandId: commandId,
  expectedRevision: expectedRevision,
  reduce: (state) {
    final reliefValue = state['relief'];
    if (reliefValue is! Map ||
        !StreetScrapReliefProgress.fromJson(
          Map<String, Object?>.from(reliefValue),
        ).ended) {
      throw StateError('reliefNotEnded');
    }
    final balance = state['chapterSupplyBalance'];
    if (balance is! int || balance < 0) {
      throw StateError('invalidChapterSupplyBalance');
    }
    if (maxStamina < 1) throw ArgumentError.value(maxStamina, 'maxStamina');
    final stamina = state['stamina'] as int? ?? maxStamina;
    if (stamina < 0 || stamina > maxStamina) {
      throw StateError('invalidStamina');
    }
    if (stamina == maxStamina) throw StateError('staminaFull');
    if (balance == 0) throw StateError('noChapterSupply');
    final restored = balance.clamp(0, maxStamina - stamina);
    final nextBalance = balance - restored;
    return StreetScrapReduction(
      state: {
        ...state,
        'stamina': stamina + restored,
        'chapterSupplyBalance': nextBalance,
      },
      result: {'actualRestored': restored, 'remainingSupply': nextBalance},
    );
  },
);
