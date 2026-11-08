import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import '../integration_test/game_resource_native_lifecycle_test.dart' as native;

void main() {
  test('native lifecycle fixture satisfies the current download contract', () {
    for (final version in ['1.0.0', '2.0.0']) {
      final manifest = native.nativeLifecycleManifest(
        Uint8List.fromList([1, 2, 3]),
        version,
      );
      expect(manifest.validate, returnsNormally);
      expect(
        manifest.resources.single.payloadSchemaVersion,
        manifest.dataSchemaVersion,
      );
    }
  });
}
