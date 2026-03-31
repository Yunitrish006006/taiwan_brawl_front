import 'dart:convert';
import 'dart:io';

const supportedLocales = <String>['en', 'ja', 'zh-Hant'];
const defaultLocaleCode = 'zh-Hant';
const englishLocaleCode = 'en';

void main() {
  final sourceDir = Directory('assets/i18n');
  if (!sourceDir.existsSync()) {
    stderr.writeln('Missing assets/i18n directory.');
    exitCode = 1;
    return;
  }

  final localeSources = <String, Map<String, String>>{};
  for (final locale in supportedLocales) {
    final file = File('${sourceDir.path}/$locale.json');
    if (!file.existsSync()) {
      stderr.writeln('Missing locale source: ${file.path}');
      exitCode = 1;
      return;
    }

    final decoded = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
    localeSources[locale] = decoded.map(
      (key, value) => MapEntry(key, value?.toString() ?? ''),
    );
  }

  final englishKeys = localeSources[englishLocaleCode]!.keys.toSet();
  for (final locale in supportedLocales.where(
    (locale) => locale != englishLocaleCode,
  )) {
    final unknownKeys = localeSources[locale]!.keys.toSet().difference(
      englishKeys,
    );
    if (unknownKeys.isNotEmpty) {
      stderr.writeln(
        'Locale $locale contains keys missing from $englishLocaleCode: '
        '${unknownKeys.toList()..sort()}',
      );
      exitCode = 1;
      return;
    }
  }

  final outputFile = File('lib/constants/generated/locale_catalog.g.dart');
  outputFile.parent.createSync(recursive: true);
  outputFile.writeAsStringSync(_buildGeneratedFile(localeSources));
}

String _buildGeneratedFile(Map<String, Map<String, String>> sources) {
  final buffer = StringBuffer()
    ..writeln('// GENERATED CODE - DO NOT MODIFY BY HAND.')
    ..writeln('// Source: assets/i18n/*.json')
    ..writeln()
    ..writeln("const String generatedDefaultLocaleCode = '$defaultLocaleCode';")
    ..writeln("const String generatedEnglishLocaleCode = '$englishLocaleCode';")
    ..writeln();

  for (final locale in supportedLocales) {
    buffer
      ..writeln(
        'const Map<String, String> ${_constName(locale)} = <String, String>{',
      )
      ..write(_mapEntries(sources[locale]!))
      ..writeln('};')
      ..writeln();
  }

  buffer
    ..writeln('final Map<String, Map<String, String>> generatedLocaleCatalog =')
    ..writeln('    <String, Map<String, String>>{');

  for (final locale in supportedLocales) {
    final sourceName = _constName(locale);
    if (locale == englishLocaleCode) {
      buffer.writeln(
        "      '$locale': Map<String, String>.unmodifiable($sourceName),",
      );
      continue;
    }

    buffer.writeln(
      "      '$locale': Map<String, String>.unmodifiable(<String, String>{"
      "...${_constName(englishLocaleCode)}, ...$sourceName}),",
    );
  }

  buffer
    ..writeln('    };')
    ..writeln();

  return buffer.toString();
}

String _constName(String locale) {
  final parts = locale
      .replaceAll(RegExp(r'[^A-Za-z0-9]+'), '_')
      .split('_')
      .where((part) => part.isNotEmpty)
      .toList();

  final suffix = parts
      .map(
        (part) =>
            part[0].toUpperCase() + (part.length > 1 ? part.substring(1) : ''),
      )
      .join();

  return 'locale$suffix';
}

String _mapEntries(Map<String, String> source) {
  final keys = source.keys.toList()..sort();
  return keys
          .map((key) => "  ${jsonEncode(key)}: ${jsonEncode(source[key])},")
          .join('\n') +
      (keys.isEmpty ? '' : '\n');
}
