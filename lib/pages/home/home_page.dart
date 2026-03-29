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
    final t = context.watch<LocaleProvider>().translation;
    final subtitle = friend.isOnline
        ? t.text('Online')
        : friend.lastActiveAt == null || friend.lastActiveAt!.isEmpty
        ? t.text('Offline')
        : '${t.text('Last online')} ${friend.lastActiveAt}';

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
    final t = context.watch<LocaleProvider>().translation;
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
                    '${t.text('Player ID')} ${user.id}',
                    style: const TextStyle(color: Colors.white70),
                  ),
                ],
              ),
            ),
            ListTile(
              leading: const Icon(Icons.group_outlined),
              title: Text(t.text('Friends')),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                Navigator.of(context).pop();
                Navigator.of(context).pushNamed('/friends');
              },
            ),
            if (user.role == 'admin')
              ListTile(
                leading: const Icon(Icons.admin_panel_settings_outlined),
                title: Text(t.text('Role Management')),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  Navigator.of(context).pop();
                  Navigator.of(context).pushNamed('/admin/roles');
                },
              ),
            ListTile(
              leading: const Icon(Icons.refresh_rounded),
              title: Text(t.text('Refresh Friends List')),
              onTap: _loadFriends,
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 10),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      t.text('Friend List'),
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
                      child: Text('${friends.length} ${t.text('people')}'),
                    ),
                ],
              ),
            ),
            Expanded(
              child: _isLoadingFriends && overview == null
                  ? const Center(child: CircularProgressIndicator())
                  : overview == null
                  ? Center(child: Text(t.text('Failed to load friend data')))
                  : friends.isEmpty
                  ? Center(child: Text(t.text('No friends yet')))
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
      return Scaffold(body: Center(child: Text(t.text('Please log in first'))));
    }

    return Scaffold(
      drawer: _buildDrawer(user),
      appBar: AppBar(
        title: Text(t.text('Taiwan Brawl Portal')),
        actions: [
          IconButton(
            onPressed: () => Navigator.of(context).pushNamed('/profile'),
            icon: const Icon(Icons.person),
            tooltip: t.text('Profile'),
          ),
          IconButton(
            onPressed: () async {
              await context.read<AuthService>().logout();
              if (!context.mounted) return;
              Navigator.of(context).pushReplacementNamed('/login');
            },
            icon: const Icon(Icons.logout),
            tooltip: t.text('Logout'),
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
                '${t.text('Welcome back')}，${user.name}',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 8),
              const SizedBox(height: 16),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () => Navigator.of(context).pushNamed('/profile'),
                icon: const Icon(Icons.edit),
                label: Text(t.text('Edit Profile')),
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: () => Navigator.of(context).pushNamed('/friends'),
                icon: const Icon(Icons.group_outlined),
                label: Text(t.text('Friends')),
              ),
              if (user.role == 'admin') ...[
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: () =>
                      Navigator.of(context).pushNamed('/admin/roles'),
                  icon: const Icon(Icons.admin_panel_settings_outlined),
                  label: Text(t.text('Role Management')),
                ),
              ],
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: () => Navigator.of(context).pushNamed('/archery'),
                icon: const Icon(Icons.architecture),
                label: Text(t.text('Archery Game')),
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: () =>
                    Navigator.of(context).pushNamed('/royale-deck'),
                icon: const Icon(Icons.style_outlined),
                label: Text(t.text('Mini Royale Deck Builder')),
              ),
              const SizedBox(height: 12),
              ElevatedButton.icon(
                onPressed: () =>
                    Navigator.of(context).pushNamed('/royale-lobby'),
                icon: const Icon(Icons.sports_esports_outlined),
                label: Text(t.text('Mini Royale Lobby Battle')),
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
