import 'generated/locale_catalog.g.dart';

const String defaultLocaleCode = generatedDefaultLocaleCode;
const String englishLocaleCode = generatedEnglishLocaleCode;

final Map<String, Map<String, String>> localeCatalog = generatedLocaleCatalog;

// Regenerate this catalog after editing assets/i18n/*.json:
// dart run tool/generate_locale_catalog.dart
Map<String, String> translationForLocale(String locale) {
  return localeCatalog[locale] ?? localeCatalog[defaultLocaleCode]!;
}
