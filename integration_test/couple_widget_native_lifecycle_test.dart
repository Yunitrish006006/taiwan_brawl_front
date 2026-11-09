import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:taiwan_brawl/services/couple_widget_bridge.dart';

// Replaces native widget storage. Run ONLY on a disposable emulator/simulator:
// flutter test integration_test/couple_widget_native_lifecycle_test.dart
//   -d <disposable-device> --dart-define=COUPLE_WIDGET_DISPOSABLE_TEST=true
// iOS additionally requires ENABLE_IOS_COUPLE_WIDGET=true and App Group setup.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  const enabled = bool.fromEnvironment('COUPLE_WIDGET_DISPOSABLE_TEST');
  final bridge = NativeCoupleWidgetBridge();
  const channel = NativeCoupleWidgetBridge.channel;
  final scopeA = 'a' * 64;
  final scopeB = 'b' * 64;

  Map<String, dynamic> active(String scope, int generation, int sequence) => {
    'schemaVersion': 1,
    'accountScope': scope,
    'sessionGeneration': generation,
    'requestSequence': sequence,
    'relationshipId': 'synthetic-native-lifecycle',
    'relationshipVersion': 1,
    'startedOn': '2026-01-01',
    'status': 'active',
    'lastSyncedAt': '2026-01-01T00:00:00.000Z',
    'partnerName': 'Synthetic Partner',
  };
  Future<Map<dynamic, dynamic>?> counter() =>
      channel.invokeMapMethod<dynamic, dynamic>('readCounter');
  final rejected = throwsA(
    isA<PlatformException>().having(
      (error) => error.code,
      'code',
      'WIDGET_WRITE_REJECTED',
    ),
  );

  testWidgets(
    'real native channel isolates accounts and rejects late writes',
    (tester) async {
      expect(NativeCoupleWidgetBridge.supported, isTrue);
      final originalPalette = await channel.invokeMethod<String>(
        'readAppearance',
      );
      addTearDown(() async {
        await bridge.beginSession(null);
        await channel.invokeMethod<void>('setAppearance', {
          'palette': originalPalette,
        });
      });

      final generationA = await bridge.beginSession(scopeA);
      expect(await counter(), isNull);
      await bridge.replace(active(scopeA, generationA, 1));
      expect(await counter(), {
        'schemaVersion': 1,
        'startedOn': '2026-01-01',
        'lastSyncedAt': '2026-01-01T00:00:00.000Z',
      });
      await expectLater(
        bridge.replace(active(scopeA, generationA, 1)),
        rejected,
      );
      await expectLater(
        bridge.replace(active(scopeB, generationA, 2)),
        rejected,
      );
      expect((await counter())?['startedOn'], '2026-01-01');

      await channel.invokeMethod<void>('setAppearance', {
        'palette': 'midnight',
      });
      final generationB = await NativeCoupleWidgetBridge().beginSession(scopeB);
      expect(generationB, greaterThan(generationA));
      expect(await counter(), isNull);
      await expectLater(
        bridge.replace(active(scopeA, generationA, 2)),
        rejected,
      );
      expect(await counter(), isNull);
      await bridge.replace(active(scopeB, generationB, 1));
      expect(await counter(), isNotNull);

      final logout = await bridge.beginSession(null);
      expect(logout, greaterThan(generationB));
      expect(await counter(), isNull);
      await expectLater(
        bridge.replace(active(scopeB, generationB, 2)),
        rejected,
      );
      expect(await counter(), isNull);
      expect(await channel.invokeMethod<String>('readAppearance'), 'midnight');

      final relogin = await bridge.beginSession(scopeB);
      expect(relogin, greaterThan(logout));
      await expectLater(
        bridge.replace(active(scopeB, generationB, 3)),
        rejected,
      );
      await bridge.replace(active(scopeB, relogin, 1));
      await bridge.replace({
        ...active(scopeB, relogin, 2),
        'relationshipId': null,
        'relationshipVersion': null,
        'startedOn': null,
        'status': 'unbound',
        'lastSyncedAt': null,
        'partnerName': null,
      });
      expect(await counter(), isNull);
    },
    skip: !enabled,
  );
}
