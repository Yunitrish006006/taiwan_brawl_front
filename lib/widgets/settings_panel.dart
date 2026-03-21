
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
            Text(t['顯示設定'] ?? '顯示設定', style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(t['主題模式'] ?? '主題模式'),
            DropdownButton<String>(
              value: themeProvider.themeModeText,
              items: [
                DropdownMenuItem(value: 'system', child: Text(t['跟隨系統'] ?? '跟隨系統')),
                DropdownMenuItem(value: 'light', child: Text(t['亮色'] ?? '亮色')),
                DropdownMenuItem(value: 'dark', child: Text(t['暗色'] ?? '暗色')),
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
            Text(t['介面語言'] ?? '介面語言'),
            DropdownButton<String>(
              value: localeProvider.locale,
              items: [
                DropdownMenuItem(value: 'zh-Hant', child: Text(t['繁體中文'] ?? '繁體中文')),
                DropdownMenuItem(value: 'en', child: Text(t['English'] ?? 'English')),
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
            Text('${t['字體大小'] ?? '字體大小'} ${uiSettings.fontScale.toStringAsFixed(1)}x'),
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
