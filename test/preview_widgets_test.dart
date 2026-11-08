import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:taiwan_brawl/config/app_configuration.dart';
import 'package:taiwan_brawl/widgets/preview_widgets.dart';

void main() {
  testWidgets('local P2P preview card stays bounded on a narrow viewport', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(320, 700);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      Provider<AppConfiguration>.value(
        value: const AppConfiguration(
          apiBaseUrl: 'http://127.0.0.1:8788',
          googleWebClientId: '',
          googleServerClientId: '',
          p2pChatEnabled: false,
          previewMode: true,
        ),
        child: const MaterialApp(
          home: Scaffold(body: Column(children: [PreviewP2pDemo()])),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.text('送出測試事件'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
