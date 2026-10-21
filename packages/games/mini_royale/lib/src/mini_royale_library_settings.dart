import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:user_ui_settings/user_ui_settings.dart';

import 'battle_animation_cache_service.dart';

/// Mini Royale's optional local asset-cache preference, shown from its
/// Game Library entry rather than the shell's account settings.
class MiniRoyaleLibrarySettingsSection extends StatelessWidget {
  const MiniRoyaleLibrarySettingsSection({super.key});

  @override
  Widget build(BuildContext context) {
    final cacheService = context.watch<BattleAnimationCacheService>();
    final t = context.watch<LocaleProvider>().translation;
    return SwitchListTile.adaptive(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16),
      secondary: const Icon(Icons.animation_outlined),
      title: Text(t.text('Preload and keep battle animations')),
      subtitle: Text(
        t.text(
          'Stores battle character animations locally and reuses them until the server version changes.',
        ),
      ),
      value: cacheService.enabled,
      onChanged: cacheService.setEnabled,
    );
  }
}
