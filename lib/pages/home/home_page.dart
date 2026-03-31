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

  Map<String, String> get _t => context.read<LocaleProvider>().translation;

  @override
  void initState() {
    super.initState();
    _friendsService = FriendsService(ApiClient());
  }

  bool _canManageCards(AppUser user) {
    return user.role == 'admin' || user.role == 'card_manager';
  }

  String _friendStatusText(SocialUser friend) {
    if (friend.isOnline) {
      return _t.text('Online');
    }
    if (friend.lastActiveAt == null || friend.lastActiveAt!.isEmpty) {
      return _t.text('Offline');
    }
    return '${_t.text('Last online')} ${friend.lastActiveAt}';
  }

  Widget _buildUserAvatar({
    required String label,
    String? avatarUrl,
    double radius = 18,
    TextStyle? fallbackStyle,
    Color? fallbackBackgroundColor,
  }) {
    final hasAvatar = avatarUrl != null && avatarUrl.isNotEmpty;
    return CircleAvatar(
      radius: radius,
      backgroundColor: fallbackBackgroundColor,
      backgroundImage: hasAvatar ? NetworkImage(avatarUrl) : null,
      child: hasAvatar
          ? null
          : Text(
              label.isEmpty ? '?' : label.characters.first,
              style: fallbackStyle,
            ),
    );
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
    final subtitle = _friendStatusText(friend);

    return ListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      leading: Stack(
        clipBehavior: Clip.none,
        children: [
          _buildUserAvatar(
            label: friend.name,
            avatarUrl: friend.avatarUrl,
            radius: 18,
            fallbackBackgroundColor: const Color(0xFF16324F),
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
      subtitle: Text(subtitle, maxLines: 2, overflow: TextOverflow.ellipsis),
    );
  }

  void _openRoute(String routeName, {bool closeDrawer = false}) {
    if (closeDrawer) {
      Navigator.of(context).pop();
    }
    Navigator.of(context).pushNamed(routeName);
  }

  Widget _buildDrawerHeader(AppUser user) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF16324F), Color(0xFF294C60), Color(0xFF3E7C59)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildUserAvatar(
            label: user.name,
            avatarUrl: user.avatarUrl,
            radius: 28,
            fallbackBackgroundColor: Colors.white.withValues(alpha: 0.16),
            fallbackStyle: const TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.w800,
            ),
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
            user.email,
            style: const TextStyle(color: Colors.white70),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildDrawerNavigationTile({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Icon(icon),
      title: Text(label),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }

  Widget _buildDrawerFriendList(FriendsOverview? overview) {
    final friends = overview?.friends ?? const <SocialUser>[];

    if (_isLoadingFriends && overview == null) {
      return const Center(child: CircularProgressIndicator());
    }
    if (overview == null) {
      return Center(child: Text(_t.text('Failed to load friend data')));
    }
    if (friends.isEmpty) {
      return Center(child: Text(_t.text('No friends yet')));
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      itemCount: friends.length,
      separatorBuilder: (_, _) => const Divider(height: 1),
      itemBuilder: (context, index) => _buildDrawerFriendTile(friends[index]),
    );
  }

  Widget _buildDrawerFriendHeader(FriendsOverview? overview) {
    final friends = overview?.friends ?? const <SocialUser>[];
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 10),
      child: Row(
        children: [
          Expanded(
            child: Text(
              _t.text('Friend List'),
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
            ),
          ),
          if (overview != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: const Color(0xFF16324F).withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text('${friends.length} ${_t.text('people')}'),
            ),
        ],
      ),
    );
  }

  Widget _buildPrimaryActionList(AppUser user, Map<String, String> t) {
    return ListView(
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
          onPressed: () => _openRoute('/profile'),
          icon: const Icon(Icons.edit),
          label: Text(t.text('Edit Profile')),
        ),
        const SizedBox(height: 12),
        FilledButton.icon(
          onPressed: () => _openRoute('/friends'),
          icon: const Icon(Icons.group_outlined),
          label: Text(t.text('Friends')),
        ),
        if (_canManageCards(user)) ...[
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: () => _openRoute('/admin/cards'),
            icon: const Icon(Icons.style_outlined),
            label: Text(t.text('Card Management')),
          ),
        ],
        if (user.role == 'admin') ...[
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: () => _openRoute('/admin/roles'),
            icon: const Icon(Icons.admin_panel_settings_outlined),
            label: Text(t.text('Role Management')),
          ),
        ],
        const SizedBox(height: 24),
        ElevatedButton.icon(
          onPressed: () => _openRoute('/archery'),
          icon: const Icon(Icons.architecture),
          label: Text(t.text('Archery Game')),
        ),
        const SizedBox(height: 12),
        FilledButton.icon(
          onPressed: () => _openRoute('/royale-deck'),
          icon: const Icon(Icons.style_outlined),
          label: Text(t.text('Mini Royale Deck Builder')),
        ),
        const SizedBox(height: 12),
        ElevatedButton.icon(
          onPressed: () => _openRoute('/royale-lobby'),
          icon: const Icon(Icons.sports_esports_outlined),
          label: Text(t.text('Mini Royale Lobby Battle')),
        ),
        const SizedBox(height: 24),
        const AppVersionText(),
      ],
    );
  }

  Drawer _buildDrawer(AppUser user) {
    final overview = _friendsOverview;

    return Drawer(
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildDrawerHeader(user),
            _buildDrawerNavigationTile(
              icon: Icons.group_outlined,
              label: _t.text('Friends'),
              onTap: () => _openRoute('/friends', closeDrawer: true),
            ),
            if (_canManageCards(user))
              _buildDrawerNavigationTile(
                icon: Icons.style_outlined,
                label: _t.text('Card Management'),
                onTap: () => _openRoute('/admin/cards', closeDrawer: true),
              ),
            if (user.role == 'admin')
              _buildDrawerNavigationTile(
                icon: Icons.admin_panel_settings_outlined,
                label: _t.text('Role Management'),
                onTap: () => _openRoute('/admin/roles', closeDrawer: true),
              ),
            ListTile(
              leading: const Icon(Icons.refresh_rounded),
              title: Text(_t.text('Refresh Friends List')),
              onTap: _loadFriends,
            ),
            _buildDrawerFriendHeader(overview),
            Expanded(child: _buildDrawerFriendList(overview)),
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
          child: _buildPrimaryActionList(user, t),
        ),
      ),
    );
  }
}
