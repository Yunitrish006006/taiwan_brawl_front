import 'package:flutter/material.dart';

/// PlayStation-inspired design system tokens.
/// Based on DESIGN.md — "three-surface channel layout" with quiet-authority typography.
abstract final class PsnColors {
  // Brand Anchor
  static const playstationBlue = Color(0xFF0070CC);
  static const consoleBlack = Color(0xFF000000);

  // Interaction / Hover
  static const playstationCyan = Color(0xFF1EAEDB);

  // Commerce
  static const commerceOrange = Color(0xFFD53B00);
  static const commerceOrangeActive = Color(0xFFAA2F00);

  // Surfaces
  static const paperWhite = Color(0xFFFFFFFF);
  static const iceMist = Color(0xFFF5F7FA);
  static const shadowBlack = Color(0xFF121314);

  // Text
  static const deepCharcoal = Color(0xFF1F1F1F);
  static const bodyGray = Color(0xFF6B6B6B);
  static const muteGray = Color(0xFFCCCCCC);
  static const inverseWhite = Color(0xFFFFFFFF);

  // Semantic
  static const warningRed = Color(0xFFC81B3A);
  static const onlineGreen = Color(0xFF34C759);
}

abstract final class PsnTheme {
  static ThemeData light() {
    return ThemeData(
      brightness: Brightness.light,
      useMaterial3: true,
      colorScheme: const ColorScheme.light(
        primary: PsnColors.playstationBlue,
        onPrimary: PsnColors.inverseWhite,
        secondary: PsnColors.playstationCyan,
        onSecondary: PsnColors.inverseWhite,
        error: PsnColors.warningRed,
        surface: PsnColors.paperWhite,
        onSurface: PsnColors.deepCharcoal,
        surfaceContainerHighest: PsnColors.iceMist,
        outline: PsnColors.muteGray,
        outlineVariant: Color(0xFFDEDEDE),
      ),
      scaffoldBackgroundColor: PsnColors.paperWhite,
      appBarTheme: const AppBarTheme(
        backgroundColor: PsnColors.consoleBlack,
        foregroundColor: PsnColors.inverseWhite,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: PsnColors.inverseWhite,
          fontSize: 22,
          fontWeight: FontWeight.w300,
          letterSpacing: 0.1,
        ),
        iconTheme: IconThemeData(color: PsnColors.inverseWhite),
        actionsIconTheme: IconThemeData(color: PsnColors.inverseWhite),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: PsnColors.playstationBlue,
          foregroundColor: PsnColors.inverseWhite,
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
          backgroundColor: PsnColors.paperWhite,
          foregroundColor: PsnColors.playstationBlue,
          side: const BorderSide(color: Color(0xFFDEDEDE), width: 1.5),
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
          foregroundColor: PsnColors.playstationBlue,
          side: const BorderSide(color: Color(0xFFDEDEDE), width: 1.5),
          shape: const StadiumBorder(),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Color(0xFFF3F3F3)),
        ),
        color: PsnColors.paperWhite,
        shadowColor: Colors.black,
      ),
      textTheme: const TextTheme(
        displayLarge: TextStyle(
          fontSize: 54,
          fontWeight: FontWeight.w300,
          letterSpacing: -0.1,
          color: PsnColors.deepCharcoal,
        ),
        displayMedium: TextStyle(
          fontSize: 44,
          fontWeight: FontWeight.w300,
          letterSpacing: 0.1,
          color: PsnColors.deepCharcoal,
        ),
        displaySmall: TextStyle(
          fontSize: 35,
          fontWeight: FontWeight.w300,
          color: PsnColors.deepCharcoal,
        ),
        headlineLarge: TextStyle(
          fontSize: 28,
          fontWeight: FontWeight.w300,
          letterSpacing: 0.1,
          color: PsnColors.deepCharcoal,
        ),
        headlineMedium: TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.w300,
          letterSpacing: 0.1,
          color: PsnColors.deepCharcoal,
        ),
        headlineSmall: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: PsnColors.deepCharcoal,
        ),
        titleLarge: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w500,
          letterSpacing: 0.4,
          color: PsnColors.deepCharcoal,
        ),
        titleMedium: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w500,
          color: PsnColors.deepCharcoal,
        ),
        titleSmall: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.324,
          color: PsnColors.deepCharcoal,
        ),
        bodyLarge: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w400,
          letterSpacing: 0.1,
          color: PsnColors.deepCharcoal,
        ),
        bodyMedium: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w400,
          color: PsnColors.bodyGray,
        ),
        bodySmall: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w400,
          color: PsnColors.bodyGray,
        ),
        labelLarge: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.324,
        ),
        labelSmall: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: PsnColors.bodyGray,
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: Color(0xFFF3F3F3),
        thickness: 1,
        space: 0,
      ),
      drawerTheme: const DrawerThemeData(
        backgroundColor: PsnColors.paperWhite,
        elevation: 0,
      ),
      listTileTheme: const ListTileThemeData(
        iconColor: PsnColors.playstationBlue,
        titleTextStyle: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w500,
          color: PsnColors.deepCharcoal,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: PsnColors.paperWhite,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(3),
          borderSide: const BorderSide(color: PsnColors.muteGray),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(3),
          borderSide: const BorderSide(color: PsnColors.playstationBlue, width: 2),
        ),
      ),
      snackBarTheme: const SnackBarThemeData(
        backgroundColor: PsnColors.deepCharcoal,
        contentTextStyle: TextStyle(color: PsnColors.inverseWhite),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(8)),
        ),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  static ThemeData dark() {
    return ThemeData(
      brightness: Brightness.dark,
      useMaterial3: true,
      colorScheme: const ColorScheme.dark(
        primary: PsnColors.playstationBlue,
        onPrimary: PsnColors.inverseWhite,
        secondary: PsnColors.playstationCyan,
        onSecondary: PsnColors.consoleBlack,
        error: PsnColors.warningRed,
        surface: PsnColors.shadowBlack,
        onSurface: PsnColors.inverseWhite,
        surfaceContainerHighest: Color(0xFF1A1D1F),
        outline: Color(0xFF444444),
        outlineVariant: Color(0xFF2A2A2A),
      ),
      scaffoldBackgroundColor: PsnColors.consoleBlack,
      appBarTheme: const AppBarTheme(
        backgroundColor: PsnColors.consoleBlack,
        foregroundColor: PsnColors.inverseWhite,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: PsnColors.inverseWhite,
          fontSize: 22,
          fontWeight: FontWeight.w300,
          letterSpacing: 0.1,
        ),
        iconTheme: IconThemeData(color: PsnColors.inverseWhite),
        actionsIconTheme: IconThemeData(color: PsnColors.inverseWhite),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: PsnColors.playstationBlue,
          foregroundColor: PsnColors.inverseWhite,
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
          backgroundColor: PsnColors.shadowBlack,
          foregroundColor: PsnColors.inverseWhite,
          side: const BorderSide(color: Color(0xFF444444), width: 1.5),
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
          foregroundColor: PsnColors.inverseWhite,
          side: const BorderSide(color: Color(0xFF444444), width: 1.5),
          shape: const StadiumBorder(),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Color(0xFF2A2A2A)),
        ),
        color: PsnColors.shadowBlack,
      ),
      textTheme: const TextTheme(
        displayLarge: TextStyle(
          fontSize: 54,
          fontWeight: FontWeight.w300,
          letterSpacing: -0.1,
          color: PsnColors.inverseWhite,
        ),
        displayMedium: TextStyle(
          fontSize: 44,
          fontWeight: FontWeight.w300,
          letterSpacing: 0.1,
          color: PsnColors.inverseWhite,
        ),
        displaySmall: TextStyle(
          fontSize: 35,
          fontWeight: FontWeight.w300,
          color: PsnColors.inverseWhite,
        ),
        headlineLarge: TextStyle(
          fontSize: 28,
          fontWeight: FontWeight.w300,
          letterSpacing: 0.1,
          color: PsnColors.inverseWhite,
        ),
        headlineMedium: TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.w300,
          letterSpacing: 0.1,
          color: PsnColors.inverseWhite,
        ),
        headlineSmall: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: PsnColors.inverseWhite,
        ),
        titleLarge: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w500,
          letterSpacing: 0.4,
          color: PsnColors.inverseWhite,
        ),
        titleMedium: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w500,
          color: PsnColors.inverseWhite,
        ),
        titleSmall: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.324,
          color: PsnColors.inverseWhite,
        ),
        bodyLarge: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w400,
          letterSpacing: 0.1,
          color: PsnColors.inverseWhite,
        ),
        bodyMedium: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w400,
          color: Color(0xFFAAAAAA),
        ),
        bodySmall: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w400,
          color: Color(0xFF888888),
        ),
        labelLarge: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.324,
          color: PsnColors.inverseWhite,
        ),
        labelSmall: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: Color(0xFF888888),
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: Color(0xFF2A2A2A),
        thickness: 1,
        space: 0,
      ),
      drawerTheme: const DrawerThemeData(
        backgroundColor: PsnColors.shadowBlack,
        elevation: 0,
      ),
      listTileTheme: const ListTileThemeData(
        iconColor: PsnColors.playstationBlue,
        titleTextStyle: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w500,
          color: PsnColors.inverseWhite,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: PsnColors.shadowBlack,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(3),
          borderSide: const BorderSide(color: Color(0xFF444444)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(3),
          borderSide: const BorderSide(color: PsnColors.playstationBlue, width: 2),
        ),
      ),
      snackBarTheme: const SnackBarThemeData(
        backgroundColor: Color(0xFF1A1D1F),
        contentTextStyle: TextStyle(color: PsnColors.inverseWhite),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(8)),
        ),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}
