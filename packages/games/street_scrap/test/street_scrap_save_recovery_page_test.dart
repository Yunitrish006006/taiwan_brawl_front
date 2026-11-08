import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taiwan_brawl_game_street_scrap/street_scrap_progress.dart';
import 'package:taiwan_brawl_game_street_scrap/street_scrap_save_recovery_page.dart';
import 'package:taiwan_brawl_game_street_scrap/street_scrap_localizations.dart';

void main() {
  final backup = StreetScrapProgressSnapshot.create(
    rulesetVersion: 1,
    contentVersions: const {'content': '0.1.0'},
    revision: 7,
    savedAt: DateTime.utc(2026, 10, 21, 9, 30),
    state: const {'chapter': 2},
    commandReceipts: const {},
  );

  testWidgets('save recovery uses the active English locale', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: StreetScrapLocalizationsScope(
          locale: 'en',
          child: StreetScrapSaveRecoveryPage(
            report: const StreetScrapRecoveryReport(
              storageToken: 'opaque-token',
              currentSnapshotIsDamaged: true,
              candidates: [],
            ),
            supportedRulesetVersion: 1,
            onRestore: (_) async {},
          ),
        ),
      ),
    );
    expect(find.text('Recover Street Scrap Save'), findsOneWidget);
    expect(find.text('The current save could not be verified'), findsOneWidget);
    expect(
      find.text(
        'No valid backup is available. Do not reset or overwrite this save.',
      ),
      findsOneWidget,
    );
    expect(find.text('目前存檔無法驗證'), findsNothing);
  });

  testWidgets('shows backup time and requires confirmation before restore', (
    tester,
  ) async {
    StreetScrapRecoveryCandidate? selected;
    await tester.pumpWidget(
      MaterialApp(
        home: StreetScrapSaveRecoveryPage(
          report: StreetScrapRecoveryReport(
            storageToken: 'opaque-token',
            currentSnapshotIsDamaged: true,
            candidates: [
              StreetScrapRecoveryCandidate(snapshot: backup, isCurrent: false),
            ],
          ),
          supportedRulesetVersion: 1,
          onRestore: (candidate) async {
            selected = candidate;
          },
        ),
      ),
    );

    expect(find.text('目前存檔無法驗證'), findsOneWidget);
    expect(find.textContaining('儲存時間：'), findsOneWidget);
    await tester.tap(find.text('選擇恢復'));
    await tester.pumpAndSettle();
    expect(find.text('確認恢復備份？'), findsOneWidget);
    expect(selected, isNull);
    await tester.tap(find.text('恢復這份備份'));
    await tester.pumpAndSettle();
    expect(selected?.snapshot.revision, 7);
  });

  testWidgets('never offers recovery when there is no valid backup', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: StreetScrapSaveRecoveryPage(
          report: const StreetScrapRecoveryReport(
            storageToken: 'opaque-token',
            currentSnapshotIsDamaged: true,
            candidates: [],
          ),
          supportedRulesetVersion: 1,
          onRestore: (_) async {},
        ),
      ),
    );

    expect(find.text('沒有可用的有效備份。請勿重置或覆蓋此存檔。'), findsOneWidget);
    expect(find.text('選擇恢復'), findsNothing);
  });
}
