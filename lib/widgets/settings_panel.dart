import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/app_user.dart';
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
            const SizedBox(height: 16),
            _LlmBotSettingsSection(user: user),
          ],
        ),
      ),
    );
  }
}

class _LlmBotSettingsSection extends StatefulWidget {
  const _LlmBotSettingsSection({required this.user});

  final AppUser user;

  @override
  State<_LlmBotSettingsSection> createState() => _LlmBotSettingsSectionState();
}

class _LlmBotSettingsSectionState extends State<_LlmBotSettingsSection> {
  final TextEditingController _baseUrlController = TextEditingController();
  final TextEditingController _modelController = TextEditingController();
  final TextEditingController _apiKeyController = TextEditingController();
  int? _seededUserId;
  bool _apiKeyDirty = false;
  bool _isSaving = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _seedIfNeeded();
  }

  @override
  void didUpdateWidget(covariant _LlmBotSettingsSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    _seedIfNeeded(
      force:
          oldWidget.user.id != widget.user.id ||
          oldWidget.user.llmBaseUrl != widget.user.llmBaseUrl ||
          oldWidget.user.llmModel != widget.user.llmModel ||
          oldWidget.user.hasLlmApiKey != widget.user.hasLlmApiKey,
    );
  }

  @override
  void dispose() {
    _baseUrlController.dispose();
    _modelController.dispose();
    _apiKeyController.dispose();
    super.dispose();
  }

  void _seedIfNeeded({bool force = false}) {
    if (!force && _seededUserId == widget.user.id) {
      return;
    }
    _seededUserId = widget.user.id;
    _baseUrlController.text = widget.user.llmBaseUrl;
    _modelController.text = widget.user.llmModel;
    _apiKeyController.clear();
    _apiKeyDirty = false;
  }

  Future<void> _save() async {
    final auth = context.read<AuthService>();
    final t = context.read<LocaleProvider>().translation;
    setState(() {
      _isSaving = true;
    });
    try {
      await auth.updateLlmBotSettings(
        baseUrl: _baseUrlController.text.trim(),
        model: _modelController.text.trim(),
        apiKey: _apiKeyDirty ? _apiKeyController.text.trim() : null,
      );
      if (!mounted) {
        return;
      }
      showAppSnackBar(context, t.text('LLM bot settings saved'));
      setState(() {
        _apiKeyDirty = false;
        _apiKeyController.clear();
      });
    } on ApiException catch (e) {
      if (!mounted) {
        return;
      }
      showAppSnackBar(context, e.message);
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  Future<void> _clearSavedApiKey() async {
    _apiKeyController.clear();
    _apiKeyDirty = true;
    await _save();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.watch<LocaleProvider>().translation;
    final user = context.watch<AuthService>().user ?? widget.user;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          t.text('LLM Bot Settings'),
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Text(
          t.text(
            'Use an OpenAI-compatible chat completions endpoint for the LLM bot opponent. API keys are stored on your player profile and used only when you create an LLM bot match.',
          ),
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _baseUrlController,
          decoration: InputDecoration(
            labelText: t.text('LLM Base URL'),
            hintText: 'https://api.openai.com/v1',
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _modelController,
          decoration: InputDecoration(
            labelText: t.text('LLM Model'),
            hintText: 'gpt-4o-mini',
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _apiKeyController,
          obscureText: true,
          decoration: InputDecoration(
            labelText: t.text('LLM API Key'),
            hintText: user.hasLlmApiKey
                ? t.text('Leave blank to keep the saved key')
                : 'sk-...',
            helperText: user.hasLlmApiKey
                ? t.text('A saved API key is already configured')
                : t.text('No API key saved yet'),
          ),
          onChanged: (_) {
            _apiKeyDirty = true;
          },
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            FilledButton.icon(
              onPressed: _isSaving ? null : _save,
              icon: _isSaving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.smart_toy_outlined),
              label: Text(t.text('Save LLM Settings')),
            ),
            OutlinedButton.icon(
              onPressed: _isSaving || !user.hasLlmApiKey
                  ? null
                  : _clearSavedApiKey,
              icon: const Icon(Icons.key_off_outlined),
              label: Text(t.text('Clear Saved API Key')),
            ),
          ],
        ),
      ],
    );
  }
}
