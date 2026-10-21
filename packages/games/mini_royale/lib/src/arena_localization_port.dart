import 'package:flutter/foundation.dart';

/// Host-provided translations and active locale consumed by Mini Royale UI.
abstract class MiniRoyaleLocalizationPort extends ChangeNotifier {
  String get locale;
  String text(String key);
}
