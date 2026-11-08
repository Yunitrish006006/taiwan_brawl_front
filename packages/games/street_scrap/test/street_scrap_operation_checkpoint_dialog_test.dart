import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taiwan_brawl_game_street_scrap/src/street_scrap_operation_checkpoint_dialog.dart';
import 'package:taiwan_brawl_game_street_scrap/street_scrap_localizations.dart';

Widget _host({
  required String operation,
  required int step,
  String locale = 'zh-Hant',
  String prompt = 'Test checkpoint',
  double targetWidthMultiplier = 1,
  double textScale = 1,
  bool assistedControls = false,
  bool accessibleNavigation = false,
}) => StreetScrapLocalizationsScope(
  locale: locale,
  child: MaterialApp(
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(context).copyWith(
        textScaler: TextScaler.linear(textScale),
        accessibleNavigation: accessibleNavigation,
      ),
      child: child!,
    ),
    home: Builder(
      builder: (context) => Scaffold(
        body: Center(
          child: FilledButton(
            onPressed: () => showDialog<int>(
              context: context,
              builder: (_) => StreetScrapOperationCheckpointDialog(
                operationId: operation,
                step: step,
                prompt: prompt,
                options: const ['miss', 'hit', 'other'],
                correctOption: 1,
                targetWidthMultiplier: targetWidthMultiplier,
                assistedControls: assistedControls,
              ),
            ),
            child: const Text('Begin'),
          ),
        ),
      ),
    ),
  ),
);

void main() {
  testWidgets(
    'long checkpoint prompt is compact visually and complete in semantics',
    (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      const prompt = '先確認布料紋理方向，再沿著三個亮起的縫線孔依序施力，保持針具穩定並避開布料破損的位置。';
      await tester.pumpWidget(_host(operation: 'sew', step: 0, prompt: prompt));
      await tester.tap(find.text('Begin'));
      await tester.pumpAndSettle();

      final promptText = tester.widget<Text>(find.text(prompt));
      expect(promptText.maxLines, 2);
      expect(promptText.overflow, TextOverflow.ellipsis);
      expect(find.bySemanticsLabel(prompt), findsOneWidget);
      expect(find.bySemanticsLabel('點擊發亮目標區'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'text-assisted checkpoint targets meet 48px minimum at 200% text on a narrow screen',
    (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final errors = <FlutterErrorDetails>[];
      final previousHandler = FlutterError.onError;
      FlutterError.onError = (details) {
        errors.add(details);
        previousHandler?.call(details);
      };
      addTearDown(() => FlutterError.onError = previousHandler);
      await tester.pumpWidget(
        _host(operation: 'sew', step: 0, textScale: 2, assistedControls: true),
      );
      await tester.tap(find.text('Begin'));
      await tester.pumpAndSettle();

      for (var target = 1; target <= 3; target++) {
        final label = find.text('選第 $target 孔');
        expect(label, findsOneWidget);
        expect(MediaQuery.of(tester.element(label)).textScaler.scale(10), 20);
        final button = find.ancestor(
          of: label,
          matching: find.byType(OutlinedButton),
        );
        expect(tester.getSize(button).height, greaterThanOrEqualTo(48));
        final rect = tester.getRect(button);
        expect(rect.left, greaterThanOrEqualTo(0));
        expect(rect.right, lessThanOrEqualTo(320));
      }
      expect(errors, isEmpty);
    },
  );

  testWidgets('checkpoint controls and target labels use English locale', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(operation: 'sew', step: 0, locale: 'en', assistedControls: true),
    );
    await tester.tap(find.text('Begin'));
    await tester.pumpAndSettle();
    expect(find.text('Crafting step 1 / 3'), findsOneWidget);
    expect(find.text('Input help'), findsOneWidget);
    expect(
      find.bySemanticsLabel('Input assistance: tap text targets'),
      findsOneWidget,
    );
    expect(
      find.bySemanticsLabel('Tap the highlighted target area'),
      findsOneWidget,
    );
    expect(find.text('Choose hole 1'), findsOneWidget);
    expect(find.text('Save this step'), findsOneWidget);
    await tester.tap(find.text('Choose hole 1'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save this step'));
    await tester.pumpAndSettle();
    expect(find.text('On target'), findsOneWidget);
    expect(find.text('Save and continue'), findsOneWidget);
  });

  testWidgets(
    'assisted text targets are open and retain the same success score',
    (tester) async {
      await tester.pumpWidget(
        _host(operation: 'sew', step: 0, assistedControls: true),
      );
      await tester.tap(find.text('Begin'));
      await tester.pumpAndSettle();
      expect(find.text('輔助操作'), findsOneWidget);
      final target = find.text('選第 1 孔');
      expect(target, findsOneWidget);
      await tester.tap(target);
      await tester.pumpAndSettle();
      await tester.tap(find.text('保存本步'));
      await tester.pumpAndSettle();
      expect(find.text('到位'), findsOneWidget);
    },
  );

  testWidgets(
    'spatial checkpoint scores the tapped target and returns persisted answer',
    (tester) async {
      await tester.pumpWidget(_host(operation: 'cut', step: 0));
      await tester.tap(find.text('Begin'));
      await tester.pumpAndSettle();
      final board = find.byKey(const Key('street-scrap-operation-target'));
      final rect = tester.getRect(board);
      await tester.tapAt(
        Offset(rect.left + rect.width * 0.25, rect.top + rect.height * 0.54),
      );
      await tester.pump();
      await tester.tap(find.text('保存本步'));
      await tester.pump();
      expect(find.text('到位'), findsOneWidget);
      expect(find.text('保存並繼續'), findsOneWidget);
    },
  );

  testWidgets(
    'spatial cut targets stay aligned with their visible positions at every step',
    (tester) async {
      for (var step = 0; step < 3; step++) {
        await tester.pumpWidget(_host(operation: 'cut', step: step));
        await tester.tap(find.text('Begin'));
        await tester.pumpAndSettle();
        final board = find.byKey(const Key('street-scrap-operation-target'));
        final target = find.byKey(
          const Key('street-scrap-cut-target-hit-area'),
        );
        expect(target, findsOneWidget);
        final boardRect = tester.getRect(board);
        final targetRect = tester.getRect(target);
        expect(
          targetRect.center.dx,
          closeTo(boardRect.left + boardRect.width * (step + 1) / 4, 0.1),
          reason: 'step $step hit target must align horizontally with its art',
        );
        expect(
          targetRect.center.dy,
          closeTo(boardRect.top + boardRect.height * 0.54, 0.1),
          reason: 'step $step hit target must align vertically with its art',
        );
        await tester.tap(target);
        await tester.pump();
        await tester.tap(find.text('保存本步'));
        await tester.pump();
        expect(find.text('到位'), findsOneWidget, reason: 'step $step');
        await tester.tap(find.text('保存並繼續'));
        await tester.pumpAndSettle();
      }
    },
  );

  testWidgets(
    'sewing targets use visible hit areas at every step and preserve misses outside',
    (tester) async {
      for (var step = 0; step < 3; step++) {
        await tester.pumpWidget(_host(operation: 'sew', step: step));
        await tester.tap(find.text('Begin'));
        await tester.pumpAndSettle();
        final board = find.byKey(const Key('street-scrap-operation-target'));
        final target = find.byKey(
          const Key('street-scrap-sew-target-hit-area'),
        );
        expect(target, findsOneWidget);
        final boardRect = tester.getRect(board);
        final targetRect = tester.getRect(target);
        expect(
          targetRect.center.dx,
          closeTo(boardRect.left + boardRect.width * (step + 1) / 4, 0.1),
          reason: 'step $step hit target must align horizontally with its art',
        );
        expect(
          targetRect.center.dy,
          closeTo(boardRect.top + boardRect.height * 0.54, 0.1),
          reason: 'step $step hit target must align vertically with its art',
        );
        await tester.tap(target);
        await tester.pump();
        await tester.tap(find.text('保存本步'));
        await tester.pump();
        expect(find.text('到位'), findsOneWidget, reason: 'step $step');
        if (step < 2) {
          await tester.tap(find.text('保存並繼續'));
          await tester.pumpAndSettle();
        } else {
          await tester.tap(find.text('保存並繼續'));
          await tester.pumpAndSettle();
        }
      }

      await tester.pumpWidget(_host(operation: 'sew', step: 0));
      await tester.tap(find.text('Begin'));
      await tester.pumpAndSettle();
      final board = find.byKey(const Key('street-scrap-operation-target'));
      final rect = tester.getRect(board);
      await tester.tapAt(
        Offset(rect.left + rect.width * 0.5, rect.top + rect.height * 0.54),
      );
      await tester.pump();
      await tester.tap(find.text('保存本步'));
      await tester.pump();
      expect(find.text('失手'), findsOneWidget);
    },
  );

  testWidgets(
    'spatial checkpoint records a deliberate miss outside the 12 percent target radius',
    (tester) async {
      await tester.pumpWidget(_host(operation: 'cut', step: 0));
      await tester.tap(find.text('Begin'));
      await tester.pumpAndSettle();
      final board = find.byKey(const Key('street-scrap-operation-target'));
      final rect = tester.getRect(board);
      await tester.tapAt(
        Offset(rect.left + rect.width * 0.5, rect.top + rect.height * 0.54),
      );
      await tester.pump();
      await tester.tap(find.text('保存本步'));
      await tester.pump();
      expect(find.text('失手'), findsOneWidget);
    },
  );

  testWidgets(
    'mix checkpoint uses a target band slider rather than answer choices',
    (tester) async {
      await tester.pumpWidget(_host(operation: 'mix', step: 0));
      await tester.tap(find.text('Begin'));
      await tester.pumpAndSettle();
      expect(find.byType(Slider), findsOneWidget);
      await tester.drag(find.byType(Slider), const Offset(-110, 0));
      await tester.pumpAndSettle();
      await tester.tap(find.text('保存本步'));
      await tester.pump();
      expect(find.text('到位'), findsOneWidget);
    },
  );

  testWidgets('cook checkpoint exposes a fire-control target slider', (
    tester,
  ) async {
    await tester.pumpWidget(_host(operation: 'cook', step: 0));
    await tester.tap(find.text('Begin'));
    await tester.pumpAndSettle();
    expect(find.byType(Slider), findsOneWidget);
    expect(find.text('控火目標區段 1'), findsOneWidget);
    await tester.drag(find.byType(Slider), const Offset(-110, 0));
    await tester.pumpAndSettle();
    await tester.tap(find.text('保存本步'));
    await tester.pump();
    expect(find.text('到位'), findsOneWidget);
  });

  testWidgets('even-burn widens the heat target by ten percent', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(operation: 'heat', step: 0, targetWidthMultiplier: 1.1),
    );
    await tester.tap(find.text('Begin'));
    await tester.pumpAndSettle();
    expect(find.text('控火目標區段 1（範圍擴大 10%）'), findsOneWidget);
    final slider = tester.widget<Slider>(find.byType(Slider));
    slider.onChanged!(
      0.36,
    ); // target is 0.25; +0.11 is outside the base window.
    await tester.pump();
    await tester.tap(find.text('保存本步'));
    await tester.pump();
    expect(find.text('到位'), findsOneWidget);
  });

  testWidgets(
    'swipe checkpoint requires passing through its highlighted zone',
    (tester) async {
      await tester.pumpWidget(_host(operation: 'wash', step: 1));
      await tester.tap(find.text('Begin'));
      await tester.pumpAndSettle();
      final board = find.byKey(const Key('street-scrap-operation-target'));
      final rect = tester.getRect(board);
      await tester.dragFrom(
        Offset(rect.left + 4, rect.top + rect.height * 0.5),
        Offset(rect.width * 0.8, 0),
      );
      await tester.pump();
      await tester.tap(find.text('保存本步'));
      await tester.pump();
      expect(find.text('到位'), findsOneWidget);
    },
  );

  testWidgets(
    'wash miss is recorded when the stroke does not cover the stain',
    (tester) async {
      await tester.pumpWidget(_host(operation: 'wash', step: 1));
      await tester.tap(find.text('Begin'));
      await tester.pumpAndSettle();
      final board = find.byKey(const Key('street-scrap-operation-target'));
      final rect = tester.getRect(board);
      await tester.dragFrom(
        Offset(rect.left + rect.width * 0.36, rect.top + rect.height * 0.5),
        Offset(rect.width * 0.1, 0),
      );
      await tester.pump();
      await tester.tap(find.text('保存本步'));
      await tester.pump();
      expect(find.text('失手'), findsOneWidget);
    },
  );

  testWidgets(
    'each rust-wiping step maps its own target to the shared success marker',
    (tester) async {
      for (var step = 0; step < 3; step++) {
        await tester.pumpWidget(_host(operation: 'wash', step: step));
        await tester.tap(find.text('Begin'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('輔助操作'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('完成污點 ${step + 1}'));
        await tester.pump();
        await tester.tap(find.text('保存本步'));
        await tester.pump();
        expect(find.text('到位'), findsOneWidget);
        await tester.tap(find.text('保存並繼續'));
        await tester.pumpAndSettle();
      }
    },
  );

  testWidgets(
    'coating accepts coverage at or above the documented 80 percent',
    (tester) async {
      await tester.pumpWidget(_host(operation: 'coat', step: 2));
      await tester.tap(find.text('Begin'));
      await tester.pumpAndSettle();
      final board = find.byKey(const Key('street-scrap-operation-target'));
      final rect = tester.getRect(board);
      await tester.dragFrom(
        Offset(rect.left + rect.width * 0.68, rect.top + rect.height * 0.5),
        Offset(rect.width * 0.285, 0),
      );
      await tester.pump();
      await tester.tap(find.text('保存本步'));
      await tester.pump();
      expect(find.text('到位'), findsOneWidget);
    },
  );

  testWidgets(
    'alignment middle checkpoint enforces the documented ten degree tolerance',
    (tester) async {
      await tester.pumpWidget(_host(operation: 'align', step: 1));
      await tester.tap(find.text('Begin'));
      await tester.pumpAndSettle();
      expect(find.byType(Slider), findsOneWidget);
      expect(tester.widget<Slider>(find.byType(Slider)).divisions, 40);
      await tester.tap(find.text('輔助操作'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('0°'));
      await tester.pump();
      await tester.tap(find.text('保存本步'));
      await tester.pump();
      expect(find.text('到位'), findsOneWidget);
    },
  );

  testWidgets(
    'keyboard and screen-reader alternative identifies each target action',
    (tester) async {
      await tester.pumpWidget(_host(operation: 'sew', step: 0));
      await tester.tap(find.text('Begin'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('輔助操作'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('選第 1 孔'));
      await tester.pump();
      await tester.tap(find.text('保存本步'));
      await tester.pump();
      expect(find.text('到位'), findsOneWidget);
    },
  );

  testWidgets(
    'system accessible navigation opens text target controls automatically',
    (tester) async {
      await tester.pumpWidget(
        _host(
          operation: 'heat',
          step: 1,
          locale: 'en',
          accessibleNavigation: true,
        ),
      );
      await tester.tap(find.text('Begin'));
      await tester.pumpAndSettle();

      expect(find.text('Input help'), findsOneWidget);
      expect(
        find.bySemanticsLabel('Input assistance: tap text targets'),
        findsOneWidget,
      );
      expect(find.text('Choose target segment 1'), findsOneWidget);
      expect(find.text('Choose target segment 2'), findsOneWidget);
      expect(find.text('Choose target segment 3'), findsOneWidget);
      expect(tester.widget<Slider>(find.byType(Slider)).onChanged, isNotNull);
      await tester.tap(find.text('Choose target segment 2'));
      await tester.pump();
      await tester.tap(find.text('Save this step'));
      await tester.pump();
      expect(find.text('On target'), findsOneWidget);
      await tester.tap(find.text('Save and continue'));
      await tester.pumpAndSettle();
      expect(find.text('Begin'), findsOneWidget);
    },
  );
}
