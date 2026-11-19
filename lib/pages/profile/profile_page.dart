import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:user_account_core/user_account_core.dart' as account;

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
    return account.ProfilePage(
      service: service,
      strings: account.ProfileStrings.fromMap(t),
      extraContent: const SettingsPanel(),
    );
  }
}
