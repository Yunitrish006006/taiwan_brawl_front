import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:user_basic_system/user_basic_system.dart' as ubs;

import '../../services/locale_provider.dart';
import '../../services/taiwan_brawl_profile_service.dart';
import '../../widgets/settings_panel.dart';

/// Thin wrapper that supplies [TaiwanBrawlProfileService] and the
/// app-specific [SettingsPanel] to the package's [ProfilePage].
class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    final service = context.read<TaiwanBrawlProfileService>();
    final t = context.watch<LocaleProvider>().translation;
    return ubs.ProfilePage(
      service: service,
      strings: ubs.ProfileStrings.fromMap(t),
      extraContent: const SettingsPanel(),
    );
  }
}
