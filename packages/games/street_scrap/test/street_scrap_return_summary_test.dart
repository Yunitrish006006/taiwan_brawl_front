import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taiwan_brawl_game_street_scrap/street_scrap_progress.dart';
import 'package:taiwan_brawl_game_street_scrap/src/street_scrap_localizations.dart';
import 'package:taiwan_brawl_game_street_scrap/src/street_scrap_return_summary.dart';

void main() {
  testWidgets('shows resumable local progress without granting rewards', (
    tester,
  ) async {
    final snapshot = StreetScrapProgressSnapshot.create(
      rulesetVersion: 1,
      contentVersions: const {},
      revision: 4,
      savedAt: DateTime.utc(2026, 10, 20),
      state: {
        'chapter': 2,
        'stamina': 18,
        'craftOperation': {
          'answers': [1, 0],
        },
        'fishingPendingResult': {'kind': 'fish'},
      },
      commandReceipts: const {},
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StreetScrapReturnSummary(
            snapshot: snapshot,
            maxStamina: 60,
            now: DateTime.utc(2026, 10, 23),
          ),
        ),
      ),
    );

    // Keep the checks anchored to semantic phrases so punctuation/line wrapping
    // can change without weakening the asserted saved-state summary.

    expect(find.text('接續你的進度'), findsOneWidget);
    expect(find.textContaining('第 2 階段'), findsOneWidget);
    expect(find.textContaining('加工尚未結算'), findsOneWidget);
    expect(find.textContaining('釣魚結果尚未領取'), findsOneWidget);
    expect(find.textContaining('目前體力：18 / 60'), findsOneWidget);
    expect(snapshot.revision, 4);
    expect(snapshot.state['fishingPendingResult'], isNotNull);
  });

  testWidgets('does not imply a login streak or fabricate relief claims', (
    tester,
  ) async {
    final snapshot = StreetScrapProgressSnapshot.create(
      rulesetVersion: 1,
      contentVersions: const {},
      revision: 0,
      savedAt: DateTime.utc(2026, 10, 23),
      state: {'chapter': 0},
      commandReceipts: const {},
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StreetScrapReturnSummary(
            snapshot: snapshot,
            maxStamina: 60,
            now: DateTime.utc(2026, 10, 23),
          ),
        ),
      ),
    );

    expect(find.textContaining('沒有每日登入獎勵或期限'), findsOneWidget);
    expect(find.textContaining('救助便當可領'), findsNothing);
    expect(snapshot.revision, 0);
  });

  testWidgets('localizes the full resumable summary for English players', (
    tester,
  ) async {
    final snapshot = StreetScrapProgressSnapshot.create(
      rulesetVersion: 1,
      contentVersions: const {},
      revision: 2,
      savedAt: DateTime.utc(2026, 10, 22, 9, 30),
      state: {
        'chapter': 4,
        'stamina': 12,
        'craftOperation': {'answers': [1, 1]},
        'expedition': {
          'claimed': false,
          'returned': true,
          'pendingRewards': [1, 2],
          'visited': [0, 1, 2],
        },
        'fishingPendingResult': {'kind': 'fish'},
      },
      commandReceipts: const {},
    );

    await tester.pumpWidget(
      MaterialApp(
        home: StreetScrapLocalizationsScope(
          locale: 'en',
          child: Scaffold(
            body: StreetScrapReturnSummary(
              snapshot: snapshot,
              maxStamina: 60,
              now: DateTime.utc(2026, 10, 23),
            ),
          ),
        ),
      ),
    );

    expect(find.text('Continue where you left off'), findsOneWidget);
    expect(find.textContaining('Current progress: Phase 4'), findsOneWidget);
    expect(find.textContaining('2 of 3 steps complete'), findsOneWidget);
    expect(find.textContaining('2 reward(s) to sort'), findsOneWidget);
    expect(find.textContaining('A fishing result is waiting'), findsOneWidget);
    expect(find.textContaining('Current stamina: 12 / 60'), findsOneWidget);
    expect(find.textContaining('no daily login rewards or deadlines'), findsOneWidget);
    expect(find.textContaining('目前進度'), findsNothing);
    expect(snapshot.revision, 2);
  });
}
