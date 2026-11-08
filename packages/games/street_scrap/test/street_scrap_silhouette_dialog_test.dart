import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taiwan_brawl_game_street_scrap/street_scrap_silhouette_dialog.dart';
import 'package:taiwan_brawl_game_street_scrap/street_scrap_localizations.dart';

void main() {
  testWidgets(
    'silhouette choices remain tappable at 200% text on a 320px viewport',
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
      int? selected;
      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: const TextScaler.linear(2)),
            child: child!,
          ),
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                key: const Key('open-survey'),
                onPressed: () async {
                  selected = await showDialog<int>(
                    context: context,
                    builder: (_) => const StreetScrapSilhouetteSurveyDialog(
                      clueSlot: 2,
                      materialItemId: 'wood.chip',
                      materialLabel: '木屑',
                    ),
                  );
                },
                child: const Text('開始'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.byKey(const Key('open-survey')));
      await tester.pumpAndSettle();

      for (var slot = 0; slot < 3; slot++) {
        final target = find.byKey(Key('street-scrap-silhouette-target-$slot'));
        await tester.ensureVisible(target);
        final rect = tester.getRect(target);
        expect(rect.width, greaterThan(0));
        expect(rect.height, greaterThanOrEqualTo(94));
        expect(rect.left, greaterThanOrEqualTo(0));
        expect(rect.right, lessThanOrEqualTo(320));
        final reveal = find.byKey(Key('street-scrap-reveal-silhouette-$slot'));
        await tester.ensureVisible(reveal);
        await tester.tap(reveal);
        await tester.pumpAndSettle();
        final select = find.byKey(Key('street-scrap-select-silhouette-$slot'));
        expect(tester.widget<TextButton>(select).onPressed, isNotNull);
        expect(tester.getSize(select).height, greaterThanOrEqualTo(48));
        final selectRect = tester.getRect(select);
        expect(selectRect.left, greaterThanOrEqualTo(0));
        expect(selectRect.right, lessThanOrEqualTo(320));
      }
      expect(
        MediaQuery.of(
          tester.element(
            find.byKey(const Key('street-scrap-silhouette-target-2')),
          ),
        ).textScaler.scale(10),
        20,
      );
      expect(errors, isEmpty);
      await tester.tap(
        find.byKey(const Key('street-scrap-select-silhouette-2')),
      );
      await tester.pumpAndSettle();
      expect(selected, 2);
    },
  );

  testWidgets('silhouette reveal interaction uses the active English locale', (
    tester,
  ) async {
    int? selected;
    await tester.pumpWidget(
      StreetScrapLocalizationsScope(
        locale: 'en',
        child: MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                key: const Key('open-survey'),
                onPressed: () async {
                  selected = await showDialog<int>(
                    context: context,
                    builder: (_) => const StreetScrapSilhouetteSurveyDialog(
                      clueSlot: 1,
                      materialItemId: 'wood.chip',
                      materialLabel: 'Wood chips',
                    ),
                  );
                },
                child: const Text('Open survey'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.byKey(const Key('open-survey')));
    await tester.pumpAndSettle();
    expect(find.text('Read the on-site clue'), findsOneWidget);
    expect(
      find.text(
        'Clue: the Wood chips target is under the middle silhouette. A wrong choice still finds 1 item.',
      ),
      findsOneWidget,
    );
    final selectMiddle = find.byKey(
      const Key('street-scrap-select-silhouette-1'),
    );
    expect(tester.widget<TextButton>(selectMiddle).onPressed, isNull);
    await tester.tap(find.byKey(const Key('street-scrap-reveal-silhouette-1')));
    await tester.pumpAndSettle();
    expect(find.text('Silhouette revealed'), findsOneWidget);
    expect(tester.widget<TextButton>(selectMiddle).onPressed, isNotNull);
    await tester.tap(selectMiddle);
    await tester.pumpAndSettle();
    expect(selected, 1);
  });

  testWidgets('tap reveals a silhouette before it can be selected', (
    tester,
  ) async {
    int? selected;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              key: const Key('open-survey'),
              onPressed: () async {
                selected = await showDialog<int>(
                  context: context,
                  builder: (_) => const StreetScrapSilhouetteSurveyDialog(
                    clueSlot: 1,
                    materialItemId: 'wood.chip',
                    materialLabel: '木屑',
                  ),
                );
              },
              child: const Text('開始'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.byKey(const Key('open-survey')));
    await tester.pumpAndSettle();
    final selectMiddle = find.byKey(
      const Key('street-scrap-select-silhouette-1'),
    );
    expect(tester.widget<TextButton>(selectMiddle).onPressed, isNull);
    await tester.tap(find.byKey(const Key('street-scrap-reveal-silhouette-1')));
    await tester.pumpAndSettle();
    expect(find.text('輪廓已露出'), findsOneWidget);
    expect(tester.widget<TextButton>(selectMiddle).onPressed, isNotNull);
    await tester.tap(selectMiddle);
    await tester.pumpAndSettle();
    expect(selected, 1);
  });

  testWidgets('dragging the debris onto a target reveals that silhouette', (
    tester,
  ) async {
    int? selected;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              key: const Key('open-survey'),
              onPressed: () async {
                selected = await showDialog<int>(
                  context: context,
                  builder: (_) => const StreetScrapSilhouetteSurveyDialog(
                    clueSlot: 0,
                    materialItemId: 'wood.chip',
                    materialLabel: '木屑',
                  ),
                );
              },
              child: const Text('開始'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.byKey(const Key('open-survey')));
    await tester.pumpAndSettle();
    final gesture = await tester.startGesture(
      tester.getCenter(find.byKey(const Key('street-scrap-draggable-debris'))),
    );
    await tester.pump(const Duration(milliseconds: 600));
    await gesture.moveTo(
      tester.getCenter(
        find.byKey(const Key('street-scrap-silhouette-target-0')),
      ),
    );
    await tester.pump();
    await gesture.up();
    await tester.pumpAndSettle();
    expect(find.text('輪廓已露出'), findsOneWidget);
    await tester.tap(find.byKey(const Key('street-scrap-select-silhouette-0')));
    await tester.pumpAndSettle();
    expect(selected, 0);
  });
}
