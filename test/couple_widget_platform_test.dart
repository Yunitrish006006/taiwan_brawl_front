import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taiwan_brawl/services/couple_widget_bridge.dart';

void main() {
  test('iOS is opt-in until native capability and signing are verified', () {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    expect(
      NativeCoupleWidgetBridge.supported,
      !kIsWeb && NativeCoupleWidgetBridge.iosEnabled,
    );
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    expect(NativeCoupleWidgetBridge.supported, !kIsWeb);
    debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
    expect(NativeCoupleWidgetBridge.supported, isFalse);
  });
}
