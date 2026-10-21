import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taiwan_brawl/services/messaging_core_service.dart';
import 'package:taiwan_brawl/widgets/messaging_storage_status_banner.dart';

void main() {
  testWidgets('hides the banner for durable storage', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: MessagingStorageStatusBanner(
          status: MessagingStorageStatus.durable(),
        ),
      ),
    );

    expect(find.textContaining('訊息目前只保存在'), findsNothing);
  });

  testWidgets('explains degraded storage to the user', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: MessagingStorageStatusBanner(
          status: MessagingStorageStatus.degraded('keychain unavailable'),
        ),
      ),
    );

    expect(find.textContaining('訊息目前只保存在'), findsOneWidget);
    expect(find.textContaining('keychain unavailable'), findsOneWidget);
  });
}
