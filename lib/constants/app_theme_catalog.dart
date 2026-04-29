import 'package:flutter/material.dart';
import 'package:user_ui_settings/user_ui_settings.dart';

import 'psn_theme.dart';

const String defaultAppThemeId = 'psn';

final List<UserThemeDefinition> taiwanBrawlThemes = [
  UserThemeDefinition(
    id: 'psn',
    name: 'Taiwan Brawl Blue',
    primary: PsnColors.playstationBlue,
    secondary: PsnColors.playstationCyan,
    lightTheme: PsnTheme.light(),
    darkTheme: PsnTheme.dark(),
  ),
  _paletteTheme(
    id: 'night_market',
    name: 'Night Market',
    primary: const Color(0xFFD84E2F),
    secondary: const Color(0xFFF4B740),
    lightSurface: const Color(0xFFFFFBF7),
    lightScaffold: const Color(0xFFFFF7F0),
    darkSurface: const Color(0xFF17110F),
    darkScaffold: const Color(0xFF0F0B0A),
  ),
  _paletteTheme(
    id: 'island_green',
    name: 'Island Green',
    primary: const Color(0xFF087F5B),
    secondary: const Color(0xFF0BA5A4),
    lightSurface: const Color(0xFFFAFFFC),
    lightScaffold: const Color(0xFFF2FBF7),
    darkSurface: const Color(0xFF0C1713),
    darkScaffold: const Color(0xFF07100D),
  ),
  _paletteTheme(
    id: 'arcade_violet',
    name: 'Arcade Violet',
    primary: const Color(0xFF6D5BD0),
    secondary: const Color(0xFF11A7B5),
    lightSurface: const Color(0xFFFCFBFF),
    lightScaffold: const Color(0xFFF6F4FF),
    darkSurface: const Color(0xFF14121F),
    darkScaffold: const Color(0xFF0D0B17),
  ),
];

UserThemeDefinition _paletteTheme({
  required String id,
  required String name,
  required Color primary,
  required Color secondary,
  required Color lightSurface,
  required Color lightScaffold,
  required Color darkSurface,
  required Color darkScaffold,
}) {
  return UserThemeDefinition(
    id: id,
    name: name,
    primary: primary,
    secondary: secondary,
    lightTheme: _applyPalette(
      PsnTheme.light(),
      brightness: Brightness.light,
      primary: primary,
      secondary: secondary,
      surface: lightSurface,
      scaffold: lightScaffold,
    ),
    darkTheme: _applyPalette(
      PsnTheme.dark(),
      brightness: Brightness.dark,
      primary: primary,
      secondary: secondary,
      surface: darkSurface,
      scaffold: darkScaffold,
    ),
  );
}

ThemeData _applyPalette(
  ThemeData base, {
  required Brightness brightness,
  required Color primary,
  required Color secondary,
  required Color surface,
  required Color scaffold,
}) {
  final isDark = brightness == Brightness.dark;
  final onPrimary = _readableOn(primary);
  final onSecondary = _readableOn(secondary);
  final scheme = base.colorScheme.copyWith(
    brightness: brightness,
    primary: primary,
    onPrimary: onPrimary,
    secondary: secondary,
    onSecondary: onSecondary,
    surface: surface,
    surfaceContainerHighest: Color.alphaBlend(
      primary.withValues(alpha: isDark ? 0.12 : 0.08),
      surface,
    ),
    outlineVariant: Color.alphaBlend(
      primary.withValues(alpha: isDark ? 0.28 : 0.18),
      surface,
    ),
  );

  return base.copyWith(
    colorScheme: scheme,
    scaffoldBackgroundColor: scaffold,
    appBarTheme: base.appBarTheme.copyWith(
      backgroundColor: isDark ? PsnColors.consoleBlack : primary,
      foregroundColor: onPrimary,
      iconTheme: IconThemeData(color: onPrimary),
      actionsIconTheme: IconThemeData(color: onPrimary),
      titleTextStyle: base.appBarTheme.titleTextStyle?.copyWith(
        color: onPrimary,
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: primary,
        foregroundColor: onPrimary,
        shape: const StadiumBorder(),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        textStyle: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w500,
          letterSpacing: 0.4,
        ),
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: surface,
        foregroundColor: primary,
        side: BorderSide(color: scheme.outlineVariant, width: 1.5),
        shape: const StadiumBorder(),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        textStyle: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w500,
          letterSpacing: 0.4,
        ),
        elevation: 0,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: primary,
        side: BorderSide(color: scheme.outlineVariant, width: 1.5),
        shape: const StadiumBorder(),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
      ),
    ),
    listTileTheme: base.listTileTheme.copyWith(iconColor: primary),
    inputDecorationTheme: base.inputDecorationTheme.copyWith(
      fillColor: surface,
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(3),
        borderSide: BorderSide(color: primary, width: 2),
      ),
    ),
    snackBarTheme: base.snackBarTheme.copyWith(
      backgroundColor: isDark ? surface : PsnColors.deepCharcoal,
    ),
  );
}

Color _readableOn(Color color) {
  return color.computeLuminance() > 0.45 ? Colors.black : Colors.white;
}
