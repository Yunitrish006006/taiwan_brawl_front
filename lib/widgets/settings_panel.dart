import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/api_client.dart';
import '../services/auth_service.dart';
import '../services/theme_provider.dart';
import '../services/ui_settings_provider.dart';
import '../utils/snackbar.dart';

class SettingsPanel extends StatelessWidget {
  const SettingsPanel({super.key});

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthService>().user;
    final themeProvider = context.watch<ThemeProvider>();
    final uiSettings = context.watch<UiSettingsProvider>();
    if (user == null) {
      return const SizedBox.shrink();
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('顯示設定', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            const Text('主題模式'),
            DropdownButton<String>(
              value: themeProvider.themeModeText,
              items: const [
                DropdownMenuItem(value: 'system', child: Text('跟隨系統')),
                DropdownMenuItem(value: 'light', child: Text('亮色')),
                DropdownMenuItem(value: 'dark', child: Text('暗色')),
              ],
              onChanged: (value) async {
                if (value == null) return;
                try {
                  await context.read<AuthService>().updateThemeMode(value);
                } on ApiException catch (e) {
                  if (!context.mounted) return;
                  showAppSnackBar(context, e.message);
                }
              },
            ),
            const SizedBox(height: 8),
            Text('字體大小 ${uiSettings.fontScale.toStringAsFixed(1)}x'),
            Slider(
              value: uiSettings.fontScale,
              min: 0.8,
              max: 1.6,
              divisions: 8,
              label: uiSettings.fontScale.toStringAsFixed(1),
              onChanged: (_) {},
              onChangeEnd: (value) async {
                try {
                  await context.read<AuthService>().updateFontSizeScale(value);
                } on ApiException catch (e) {
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
