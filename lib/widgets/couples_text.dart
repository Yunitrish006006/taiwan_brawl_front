import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';
import '../constants/generated/locale_catalog.g.dart';
import '../services/locale_provider.dart';

String couplesText(
  BuildContext context,
  String key, [
  Map<String, String> values = const {},
]) {
  final locale = context.read<LocaleProvider?>()?.locale ?? 'zh-Hant';
  var text =
      (generatedLocaleCatalog[locale] ?? generatedLocaleCatalog['en']!)[key] ??
      key;
  for (final entry in values.entries) {
    text = text.replaceAll('{${entry.key}}', entry.value);
  }
  return text;
}
