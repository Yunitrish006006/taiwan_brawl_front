import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taiwan_brawl/services/couple_widget_bridge.dart';
import 'package:taiwan_brawl/widgets/couple_widget_appearance_picker.dart';

class MemoryAppearance implements CoupleWidgetAppearanceStore {
  CoupleWidgetPalette palette = CoupleWidgetPalette.rose;
  bool fail = false;
  Completer<void>? pending;
  final writes = <CoupleWidgetPalette>[];
  @override
  Future<CoupleWidgetPalette> read() async => palette;
  @override
  Future<void> write(CoupleWidgetPalette value) async {
    writes.add(value);
    await pending?.future;
    if (fail) throw StateError('write failed');
    palette = value;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('named preview keeps the day count readable with a long name', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CoupleWidgetAppearancePicker(
            days: 330,
            partnerName:
                'A very long partner name that should be truncated rather than shrinking the counter',
            store: MemoryAppearance(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('第 330 天'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  Future<void> show(
    WidgetTester tester,
    MemoryAppearance store, {
    int? days = 123,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: CoupleWidgetAppearancePicker(days: days, store: store),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  ChoiceChip chip(WidgetTester tester, String name) =>
      tester.widget<ChoiceChip>(find.byKey(ValueKey('widget-palette-$name')));

  testWidgets('selection persists and is restored after reopening', (
    tester,
  ) async {
    final store = MemoryAppearance();
    await show(tester, store);
    await tester.tap(find.byKey(const ValueKey('widget-palette-ocean')));
    await tester.pumpAndSettle();
    expect(chip(tester, 'ocean').selected, isTrue);
    expect(store.palette, CoupleWidgetPalette.ocean);
    await tester.pumpWidget(const SizedBox());
    await show(tester, store);
    expect(chip(tester, 'ocean').selected, isTrue);
  });
  testWidgets('failed persistence retains the previous confirmed color', (
    tester,
  ) async {
    final store = MemoryAppearance()..fail = true;
    await show(tester, store);
    await tester.tap(find.byKey(const ValueKey('widget-palette-lavender')));
    await tester.pumpAndSettle();
    expect(chip(tester, 'rose').selected, isTrue);
    expect(find.text('無法儲存配色，請重試。'), findsOneWidget);
  });
  testWidgets('in-flight write disables further choices', (tester) async {
    final store = MemoryAppearance()..pending = Completer<void>();
    await show(tester, store);
    await tester.tap(find.byKey(const ValueKey('widget-palette-mint')));
    await tester.pump();
    expect(chip(tester, 'sand').onSelected, isNull);
    expect(store.writes, [CoupleWidgetPalette.mint]);
    store.pending!.complete();
    await tester.pumpAndSettle();
    expect(chip(tester, 'mint').selected, isTrue);
  });
  testWidgets('unbound preview shows no invented day count; large font fits', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(2)),
          child: Scaffold(
            body: SingleChildScrollView(
              child: CoupleWidgetAppearancePicker(store: MemoryAppearance()),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('尚未綁定情侶'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  test('all foregrounds meet 4.5:1 against both gradient endpoints', () {
    for (final palette in CoupleWidgetPalette.values) {
      for (final color in [palette.start, palette.end]) {
        final a = Color(color).computeLuminance(),
            b = Color(palette.ink).computeLuminance();
        final ratio = a > b ? (a + 0.05) / (b + 0.05) : (b + 0.05) / (a + 0.05);
        expect(ratio, greaterThanOrEqualTo(4.5), reason: palette.name);
      }
    }
  });
  test('appearance channel sends only a palette ID', () async {
    final calls = <MethodCall>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(NativeCoupleWidgetBridge.channel, (
          call,
        ) async {
          calls.add(call);
          return call.method == 'readAppearance' ? 'midnight' : null;
        });
    addTearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(NativeCoupleWidgetBridge.channel, null),
    );
    const store = NativeCoupleWidgetAppearanceStore();
    expect(await store.read(), CoupleWidgetPalette.midnight);
    await store.write(CoupleWidgetPalette.sand);
    expect(calls.last.arguments, {'palette': 'sand'});
    expect(CoupleWidgetPalette.decode('obsolete'), CoupleWidgetPalette.rose);
  });
}
