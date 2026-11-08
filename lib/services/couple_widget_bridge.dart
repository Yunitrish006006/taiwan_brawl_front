import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

abstract interface class CoupleWidgetBridge {
  Future<int> beginSession(String? scope);
  Future<void> replace(Map<String, dynamic> snapshot);
}

class NativeCoupleWidgetBridge implements CoupleWidgetBridge {
  static const channel = MethodChannel('taiwan_brawl/couple_widget');
  // Keep iOS opt-in until Xcode, the App Group and provisioning are verified.
  static const iosEnabled = bool.fromEnvironment('ENABLE_IOS_COUPLE_WIDGET');
  static bool get supported =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          (defaultTargetPlatform == TargetPlatform.iOS && iosEnabled));
  @override
  Future<int> beginSession(String? scope) async {
    final generation = await channel.invokeMethod<int>('beginSession', {
      'accountScope': scope,
    });
    if (generation == null || generation < 1) {
      throw StateError('Invalid native generation');
    }
    return generation;
  }

  @override
  Future<void> replace(Map<String, dynamic> snapshot) async {
    await channel.invokeMethod<void>('replace', {'snapshot': snapshot});
  }
}
