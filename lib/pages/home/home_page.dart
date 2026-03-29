import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/app_user.dart';
import '../../models/friends_models.dart';
import '../../services/api_client.dart';
import '../../services/auth_service.dart';
import '../../services/friends_service.dart';
import '../../services/locale_provider.dart';
import '../../widgets/app_version_text.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late final FriendsService _friendsService;
  FriendsOverview? _friendsOverview;
  int? _loadedUserId;
  bool _isLoadingFriends = false;

  @override
  void initState() {
    super.initState();
    _friendsService = FriendsService(ApiClient());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final userId = context.read<AuthService>().user?.id;
    if (userId != null && userId != _loadedUserId) {
      _loadedUserId = userId;
      _loadFriends();
    }
  }

  Future<void> _loadFriends() async {
    if (_isLoadingFriends) {
      return;
    }

    setState(() {
      _isLoadingFriends = true;
    });

    try {
      final overview = await _friendsService.fetchOverview();
      if (!mounted) {
        return;
      }
      setState(() {
        _friendsOverview = overview;
      });
    } on ApiException {
      // Ignore transient home drawer load failures.
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingFriends = false;
        });
      }
    }
  }

  Widget _buildDrawerFriendTile(SocialUser friend) {
    final subtitle = friend.isOnline
        ? '在線中'
        : friend.lastActiveAt == null || friend.lastActiveAt!.isEmpty
        ? '目前離線'
        : '最後上線 ${friend.lastActiveAt}';

    return ListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      leading: Stack(
        clipBehavior: Clip.none,
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: const Color(0xFF16324F),
            backgroundImage:
                friend.avatarUrl != null && friend.avatarUrl!.isNotEmpty
                ? NetworkImage(friend.avatarUrl!)
                : null,
            child: friend.avatarUrl == null || friend.avatarUrl!.isEmpty
                ? Text(friend.name.isEmpty ? '?' : friend.name.characters.first)
                : null,
          ),
          Positioned(
            right: -1,
            bottom: -1,
            child: Container(
              width: 11,
              height: 11,
              decoration: BoxDecoration(
                color: friend.isOnline
                    ? const Color(0xFF34C759)
                    : Colors.grey.shade500,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 1.6),
              ),
            ),
          ),
        ],
      ),
      title: Text(
        friend.name,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontWeight: FontWeight.w700),
      ),
      subtitle: Text(
        'ID ${friend.userId} · $subtitle',
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  Drawer _buildDrawer(AppUser user) {
    final overview = _friendsOverview;
    final friends = overview?.friends ?? const <SocialUser>[];

    return Drawer(
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Color(0xFF16324F),
                    Color(0xFF294C60),
                    Color(0xFF3E7C59),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    radius: 28,
                    backgroundColor: Colors.white.withValues(alpha: 0.16),
                    backgroundImage:
                        user.avatarUrl != null && user.avatarUrl!.isNotEmpty
                        ? NetworkImage(user.avatarUrl!)
                        : null,
                    child: user.avatarUrl == null || user.avatarUrl!.isEmpty
                        ? Text(
                            user.name.isEmpty
                                ? '?'
                                : user.name.characters.first,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                            ),
                          )
                        : null,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    user.name,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '玩家 ID ${user.id}',
                    style: const TextStyle(color: Colors.white70),
                  ),
                ],
              ),
            ),
            ListTile(
              leading: const Icon(Icons.group_outlined),
              title: const Text('好友系統'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                Navigator.of(context).pop();
                Navigator.of(context).pushNamed('/friends');
              },
            ),
            if (user.role == 'admin')
              ListTile(
                leading: const Icon(Icons.admin_panel_settings_outlined),
                title: const Text('身份組管理'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  Navigator.of(context).pop();
                  Navigator.of(context).pushNamed('/admin/roles');
                },
              ),
            ListTile(
              leading: const Icon(Icons.refresh_rounded),
              title: const Text('重新整理好友列表'),
              onTap: _loadFriends,
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 10),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      '好友列表',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  if (overview != null)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF16324F).withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text('${friends.length} 人'),
                    ),
                ],
              ),
            ),
            Expanded(
              child: _isLoadingFriends && overview == null
                  ? const Center(child: CircularProgressIndicator())
                  : overview == null
                  ? const Center(child: Text('好友資料載入失敗'))
                  : friends.isEmpty
                  ? const Center(child: Text('目前還沒有好友'))
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      itemCount: friends.length,
                      separatorBuilder: (_, _) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        return _buildDrawerFriendTile(friends[index]);
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthService>().user;
    final t = context.watch<LocaleProvider>().translation;
    if (user == null) {
      return Scaffold(body: Center(child: Text(t['請先登入'] ?? '請先登入')));
    }

    return Scaffold(
      drawer: _buildDrawer(user),
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
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: () => Navigator.of(context).pushNamed('/friends'),
                icon: const Icon(Icons.group_outlined),
                label: const Text('好友系統'),
              ),
              if (user.role == 'admin') ...[
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: () =>
                      Navigator.of(context).pushNamed('/admin/roles'),
                  icon: const Icon(Icons.admin_panel_settings_outlined),
                  label: const Text('身份組管理'),
                ),
              ],
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: () => Navigator.of(context).pushNamed('/archery'),
                icon: const Icon(Icons.architecture),
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
