import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../services/auth_service.dart';
import '../../widgets/app_version_text.dart';
import '../../services/locale_provider.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthService>().user;
    final t = context.watch<LocaleProvider>().translation;
    if (user == null) {
      return Scaffold(body: Center(child: Text(t['請先登入'] ?? '請先登入')));
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(t['Taiwan Brawl Portal'] ?? 'Taiwan Brawl Portal'),
        actions: [
          IconButton(
            onPressed: () => Navigator.of(context).pushNamed('/profile'),
            icon: const Icon(Icons.person),
            tooltip: t['個人資料'] ?? '個人資料',
          ),
          IconButton(
            onPressed: () async {
              await context.read<AuthService>().logout();
              if (!context.mounted) return;
              Navigator.of(context).pushReplacementNamed('/login');
            },
            icon: const Icon(Icons.logout),
            tooltip: t['登出'] ?? '登出',
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                '${t['歡迎回來'] ?? '歡迎回來'}，${user.name}',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 8),
              const SizedBox(height: 16),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () => Navigator.of(context).pushNamed('/profile'),
                icon: const Icon(Icons.edit),
                label: Text(t['編輯個人資料'] ?? '編輯個人資料'),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: () => Navigator.of(context).pushNamed('/archery'),
                icon: const Icon(Icons.architecture), // 用現有圖示
                label: const Text('弓箭射擊遊戲'),
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: () =>
                    Navigator.of(context).pushNamed('/royale-deck'),
                icon: const Icon(Icons.style_outlined),
                label: const Text('Mini Royale 牌組編輯'),
              ),
              const SizedBox(height: 12),
              ElevatedButton.icon(
                onPressed: () =>
                    Navigator.of(context).pushNamed('/royale-lobby'),
                icon: const Icon(Icons.sports_esports_outlined),
                label: const Text('Mini Royale 房間對戰'),
              ),
              const SizedBox(height: 24),
              const AppVersionText(),
            ],
          ),
        ),
      ),
    );
  }
}
