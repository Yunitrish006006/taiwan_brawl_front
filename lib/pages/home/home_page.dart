import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/app_user.dart';
import '../../models/friends_models.dart';
import '../../services/api_client.dart';
import '../../services/auth_service.dart';
import '../../services/friends_service.dart';
import '../../services/locale_provider.dart';
import '../../constants/app_constants.dart';
import '../../widgets/app_version_text.dart';

part 'home_page_layout.dart';

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

  void _openRoute(String routeName, {bool closeDrawer = false}) {
    if (closeDrawer) {
      Navigator.of(context).pop();
    }
    Navigator.of(context).pushNamed(routeName);
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
        title: const Text(AppConstants.appName),
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
