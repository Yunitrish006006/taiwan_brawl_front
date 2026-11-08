import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taiwan_brawl/pages/general/splash_page.dart';

void main() {
  testWidgets('composition bootstrap renders a visible first frame', (
    tester,
  ) async {
    await tester.pumpWidget(const BootstrapLoadingApp());

    expect(find.text('Taiwan Brawl'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });
}
