import 'locale_en.dart';
import 'locale_ja.dart';
import 'locale_zh_hant.dart';

const String defaultLocaleCode = 'zh-Hant';
const String englishLocaleCode = 'en';

const Map<String, Map<String, String>> localeCatalog = {
  'en': enUS,
  'ja': jaJP,
  'zh-Hant': zhHant,
};

Map<String, String> translationForLocale(String locale) {
  return localeCatalog[locale] ?? localeCatalog[defaultLocaleCode]!;
}
