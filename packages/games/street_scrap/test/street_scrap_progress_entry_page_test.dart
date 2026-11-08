import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taiwan_brawl_game_street_scrap/src/street_scrap_progress_entry_page.dart';
import 'package:taiwan_brawl_game_street_scrap/street_scrap_progress.dart';

class _LeaseStore
    implements StreetScrapProgressStore, StreetScrapWriterLeaseStore {
  final Map<String, Map<String, Object?>> values = {};
  final Set<String> leasedSlots = {};
  Object? readFailure;

  @override
  Future<Map<String, Object?>?> read(String slotKey) async {
    if (readFailure case final error?) throw error;
    return values[slotKey];
  }

  @override
  Future<bool> compareAndSwap({
    required String slotKey,
    required int? expectedRevision,
    required Map<String, Object?> nextSnapshot,
  }) async {
    final currentRevision = values[slotKey]?['revision'] as int?;
    if (currentRevision != expectedRevision) return false;
    values[slotKey] = nextSnapshot;
    return true;
  }

  @override
  Future<StreetScrapWriterLease?> acquireWriterLease(String slotKey) async {
    if (!leasedSlots.add(slotKey)) return null;
    return _Lease(() => leasedSlots.remove(slotKey));
  }
}

class _Lease implements StreetScrapWriterLease {
  _Lease(this.onRelease);

  final void Function() onRelease;
  bool _released = false;

  @override
  Future<void> release() async {
    if (_released) return;
    _released = true;
    onRelease();
  }
}

StreetScrapSession _session(_LeaseStore store) => StreetScrapSession(
  profileScope: 'entry-page-test-profile',
  store: store,
  contentVersions: const {},
  rulesetVersion: 1,
);

StreetScrapProgressEntryPage _page(
  StreetScrapSession session, {
  bool contentInstalled = false,
  Future<Uint8List?> Function()? readContent,
}) => StreetScrapProgressEntryPage(
  session: session,
  contentInstalled: contentInstalled,
  readContent: readContent ?? () async => null,
  onOpenLibrary: () {},
);

void main() {
  testWidgets('shows read-only lease and allows a fresh entry after release', (
    tester,
  ) async {
    final store = _LeaseStore();
    final existingTab = _session(store);
    await existingTab.load();

    final secondTab = _session(store);
    await tester.pumpWidget(MaterialApp(home: _page(secondTab)));
    await tester.pumpAndSettle();

    expect(find.text('本機存檔已載入'), findsOneWidget);
    expect(find.text('此存檔已在另一個分頁開啟，目前為唯讀。'), findsOneWidget);
    expect(find.text('關閉另一個分頁後重新開啟本頁即可取得寫入權。'), findsOneWidget);

    await existingTab.close();
    await tester.pumpWidget(const MaterialApp(home: SizedBox.shrink()));
    await tester.pumpAndSettle();

    final reopenedTab = _session(store);
    await tester.pumpWidget(MaterialApp(home: _page(reopenedTab)));
    await tester.pumpAndSettle();

    expect(find.text('本機存檔已載入'), findsOneWidget);
    expect(find.text('此存檔已在另一個分頁開啟，目前為唯讀。'), findsNothing);
    expect(reopenedTab.isReadOnly, isFalse);
  });

  testWidgets('save-load failure shows recovery advice, not raw exception', (
    tester,
  ) async {
    final store = _LeaseStore()
      ..readFailure = StateError('PRIVATE-SAVE-DETAIL');
    final session = _session(store);
    await tester.pumpWidget(MaterialApp(home: _page(session)));
    await tester.pumpAndSettle();

    expect(find.text('存檔無法載入；原始資料尚未修改。'), findsOneWidget);
    expect(find.textContaining('請返回遊戲庫後再試'), findsOneWidget);
    expect(find.textContaining('PRIVATE-SAVE-DETAIL'), findsNothing);
  });

  testWidgets('content-load failure shows recovery advice, not raw exception', (
    tester,
  ) async {
    final store = _LeaseStore();
    final session = _session(store);
    await tester.pumpWidget(
      MaterialApp(
        home: _page(
          session,
          contentInstalled: true,
          readContent: () async => throw StateError('PRIVATE-CONTENT-DETAIL'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('已安裝的街區內容無法讀取；本機存檔未修改。'), findsOneWidget);
    expect(find.textContaining('請返回遊戲庫檢查或重新下載'), findsOneWidget);
    expect(find.textContaining('PRIVATE-CONTENT-DETAIL'), findsNothing);
  });
}
