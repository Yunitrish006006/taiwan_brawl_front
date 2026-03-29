import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/api_client.dart';
import '../services/auth_service.dart';
import '../services/theme_provider.dart';
import '../services/ui_settings_provider.dart';
import '../services/locale_provider.dart';
import '../utils/snackbar.dart';

class SettingsPanel extends StatelessWidget {
  const SettingsPanel({super.key});

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthService>().user;
    final themeProvider = context.watch<ThemeProvider>();
    final uiSettings = context.watch<UiSettingsProvider>();
    final localeProvider = context.watch<LocaleProvider>();
    if (user == null) {
      return const SizedBox.shrink();
    }

    final t = localeProvider.translation;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              t.text('Display Settings'),
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(t.text('Theme Mode')),
            DropdownButton<String>(
              value: themeProvider.themeModeText,
              items: [
                DropdownMenuItem(
                  value: 'system',
                  child: Text(t.text('Follow System')),
                ),
                DropdownMenuItem(value: 'light', child: Text(t.text('Light'))),
                DropdownMenuItem(value: 'dark', child: Text(t.text('Dark'))),
              ],
              onChanged: (value) async {
                if (value == null) return;
                final themeProvider = context.read<ThemeProvider>();
                themeProvider.rememberCurrent();
                themeProvider.setThemeModeText(value);
                final auth = context.read<AuthService>();
                try {
                  await auth.updateThemeMode(value);
                } on ApiException catch (e) {
                  themeProvider.restoreRemembered();
                  if (!context.mounted) return;
                  showAppSnackBar(context, e.message);
                }
              },
            ),
            const SizedBox(height: 8),
            Text(t.text('Language')),
            DropdownButton<String>(
              value: localeProvider.locale,
              items: [
                DropdownMenuItem(
                  value: 'zh-Hant',
                  child: Text(t.text('Traditional Chinese')),
                ),
                DropdownMenuItem(value: 'en', child: Text(t.text('English'))),
                DropdownMenuItem(value: 'ja', child: Text(t.text('Japanese'))),
              ],
              onChanged: (value) async {
                if (value == null) return;
                final localeProvider = context.read<LocaleProvider>();
                localeProvider.rememberCurrent();
                localeProvider.setLocale(value);
                final auth = context.read<AuthService>();
                try {
                  await auth.updateLocale(value);
                } on ApiException catch (e) {
                  localeProvider.restoreRemembered();
                  if (!context.mounted) return;
                  showAppSnackBar(context, e.message);
                }
              },
            ),
            const SizedBox(height: 8),
            Text(
              '${t.text('Font Size')} ${uiSettings.fontScale.toStringAsFixed(1)}x',
            ),
            Slider(
              value: uiSettings.fontScale,
              min: 0.8,
              max: 1.6,
              divisions: 8,
              label: uiSettings.fontScale.toStringAsFixed(1),
              onChanged: (value) {
                context.read<UiSettingsProvider>().setFontScale(value);
              },
              onChangeStart: (value) {
                context.read<UiSettingsProvider>().rememberCurrent();
              },
              onChangeEnd: (value) async {
                final auth = context.read<AuthService>();
                final uiSettings = context.read<UiSettingsProvider>();
                try {
                  await auth.updateFontSizeScale(value);
                } on ApiException catch (e) {
                  uiSettings.restoreRemembered();
                  if (!context.mounted) return;
                  showAppSnackBar(context, e.message);
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}
