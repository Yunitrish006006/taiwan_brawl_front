import 'dart:async';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taiwan_brawl_game_street_scrap/street_scrap_inventory.dart';
import 'package:taiwan_brawl_game_street_scrap/street_scrap_crafting.dart';
import 'package:taiwan_brawl_game_street_scrap/street_scrap_inventory_page.dart';
import 'package:taiwan_brawl_game_street_scrap/street_scrap_localizations.dart';
import 'package:taiwan_brawl_game_street_scrap/street_scrap_progress.dart';

const _contentVersions = {'game.street-scrap.content.chapters-0-4': '0.1.0'};

class _MemoryStore implements StreetScrapProgressStore {
  final Map<String, Map<String, Object?>> values = {};
  final Map<String, List<Map<String, Object?>>> previous = {};

  @override
  Future<Map<String, Object?>?> read(String slotKey) async => values[slotKey];

  @override
  Future<bool> compareAndSwap({
    required String slotKey,
    required int? expectedRevision,
    required Map<String, Object?> nextSnapshot,
  }) async {
    final current = values[slotKey];
    if ((current?['revision'] as int?) != expectedRevision) return false;
    if (current != null) previous.putIfAbsent(slotKey, () => []).add(current);
    values[slotKey] = nextSnapshot;
    return true;
  }
}

class _TransferFilePicker extends FilePicker {
  Uint8List? exportedBytes;
  FilePickerResult? importResult;
  Completer<FilePickerResult?>? pendingImport;
  int pickCalls = 0;
  bool? lastWithData;
  bool? lastWithReadStream;

  @override
  Future<String?> saveFile({
    String? dialogTitle,
    String? fileName,
    String? initialDirectory,
    FileType type = FileType.any,
    List<String>? allowedExtensions,
    Uint8List? bytes,
    bool lockParentWindow = false,
  }) async {
    exportedBytes = bytes;
    return fileName;
  }

  @override
  Future<FilePickerResult?> pickFiles({
    String? dialogTitle,
    String? initialDirectory,
    FileType type = FileType.any,
    List<String>? allowedExtensions,
    Function(FilePickerStatus)? onFileLoading,
    bool allowCompression = false,
    int compressionQuality = 0,
    bool allowMultiple = false,
    bool withData = false,
    bool withReadStream = false,
    bool lockParentWindow = false,
    bool readSequential = false,
  }) async {
    pickCalls++;
    lastWithData = withData;
    lastWithReadStream = withReadStream;
    final pending = pendingImport;
    if (pending != null) return pending.future;
    return importResult;
  }
}

void main() {
  test('save imports stream on web and mobile platforms', () {
    for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
      expect(
        streetScrapSaveTransferUsesReadStream(isWeb: false, platform: platform),
        isTrue,
      );
    }
    expect(
      streetScrapSaveTransferUsesReadStream(
        isWeb: true,
        platform: TargetPlatform.macOS,
      ),
      isTrue,
    );
    expect(
      streetScrapSaveTransferUsesReadStream(
        isWeb: false,
        platform: TargetPlatform.macOS,
      ),
      isFalse,
    );
  });

  testWidgets(
    'save transfer UI exports, previews, then imports on confirmation',
    (tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final filePicker = _TransferFilePicker();
      FilePicker.platform = filePicker;
      final store = _MemoryStore();
      final session = StreetScrapSession(
        profileScope: 'save-transfer-widget',
        store: store,
        contentVersions: _contentVersions,
        rulesetVersion: 1,
      );
      await session.load();
      await session.apply(
        commandId: 'seed-before-transfer',
        expectedRevision: session.snapshot.revision,
        reduce: (_) =>
            const StreetScrapReduction(state: {'chapter': 0, 'stamina': 60}),
      );
      final importedSnapshot = StreetScrapProgressSnapshot.create(
        rulesetVersion: 1,
        contentVersions: _contentVersions,
        revision: 7,
        savedAt: DateTime.utc(2026, 10, 24),
        state: const {'chapter': 2, 'stamina': 38},
        commandReceipts: const {},
      );
      filePicker.importResult = FilePickerResult([
        PlatformFile(
          name: 'street-scrap-save.json',
          size: 0,
          readStream: Stream<List<int>>.fromIterable([
            Uint8List.fromList(
              StreetScrapSaveTransfer.fromSnapshot(
                importedSnapshot,
              ).encodeBytes(),
            ),
          ]),
        ),
      ]);

      await tester.pumpWidget(
        StreetScrapLocalizationsScope(
          locale: 'en',
          child: MaterialApp(
            home: Scaffold(
              body: StreetScrapInventoryPage(
                session: session,
                catalog: StreetScrapInventoryCatalog(
                  footprints: const {},
                  packingRules: const {},
                ),
                recipeCatalog: StreetScrapRecipeCatalog.fromRecipes(
                  const [],
                  expectedCount: 0,
                ),
                expeditionRules: const StreetScrapExpeditionRules(
                  nodeCount: 3,
                  investigationsPerNode: 1,
                  movementCost: 1,
                  investigationCost: 2,
                  fixedWrongQuantity: 1,
                  fixedLocations: [],
                  surprisePools: {},
                  surpriseWeights: {},
                  surpriseTraitPools: {},
                  surpriseTraitChancePercent: 0,
                  scrapQualities: [],
                  intactQualities: [],
                ),
                maxStamina: 60,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('street-scrap-open-settings')));
      await tester.pumpAndSettle();
      final revisionBeforeExport = session.snapshot.revision;
      await tester.tap(find.byKey(const Key('street-scrap-export-save')));
      await tester.pumpAndSettle();
      expect(filePicker.exportedBytes, isNotNull);
      expect(
        StreetScrapSaveTransfer.decodeBytes(
          filePicker.exportedBytes!,
        ).snapshot.revision,
        revisionBeforeExport,
      );

      final revisionBeforeImport = session.snapshot.revision;
      final pendingSelection = Completer<FilePickerResult?>();
      filePicker.pendingImport = pendingSelection;
      await tester.tap(find.byKey(const Key('street-scrap-import-save')));
      await tester.pump();
      expect(
        find.descendant(
          of: find.byKey(const Key('street-scrap-import-save')),
          matching: find.text('Choosing save…'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byKey(const Key('street-scrap-save-settings')),
          matching: find.text('Choosing save…'),
        ),
        findsOneWidget,
      );
      filePicker.pendingImport = null;
      pendingSelection.complete(filePicker.importResult);
      await tester.pumpAndSettle();
      final usesReadStream = streetScrapSaveTransferUsesReadStream(
        isWeb: false,
        platform: defaultTargetPlatform,
      );
      expect(filePicker.lastWithData, !usesReadStream);
      expect(filePicker.lastWithReadStream, usesReadStream);
      expect(find.text('Review this save'), findsOneWidget);
      expect(find.textContaining('Chapter 2'), findsOneWidget);
      expect(session.snapshot.state['chapter'], 0);
      await tester.tap(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.text('Import save'),
        ),
      );
      await tester.pumpAndSettle();

      expect(session.snapshot.revision, revisionBeforeImport + 1);
      expect(session.snapshot.state['chapter'], 2);
      expect(
        store.previous[session.slotKey]?.last['revision'],
        revisionBeforeImport,
      );

      await tester.tap(find.byKey(const Key('street-scrap-open-settings')));
      await tester.pumpAndSettle();
      filePicker.importResult = FilePickerResult([
        PlatformFile(
          name: 'oversized-save.json',
          size: streetScrapTransferMaximumBytes + 1,
        ),
      ]);
      await tester.tap(find.byKey(const Key('street-scrap-import-save')));
      await tester.pumpAndSettle();
      expect(filePicker.pickCalls, 2);
      expect(session.snapshot.revision, revisionBeforeImport + 1);
      expect(session.snapshot.state['chapter'], 2);
      filePicker.importResult = FilePickerResult([
        PlatformFile(
          name: 'misreported-oversized-save.json',
          size: 0,
          readStream: Stream<List<int>>.value(
            List<int>.filled(streetScrapTransferMaximumBytes + 1, 0),
          ),
        ),
      ]);
      await tester.tap(find.byKey(const Key('street-scrap-import-save')));
      await tester.pumpAndSettle();
      expect(session.snapshot.revision, revisionBeforeImport + 1);
      expect(session.snapshot.state['chapter'], 2);
      await session.close();
    },
  );
}
