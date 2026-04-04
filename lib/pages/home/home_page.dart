import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/app_user.dart';
import '../../models/friends_models.dart';
import '../../models/royale_models.dart';
import '../../services/api_client.dart';
import '../../services/auth_service.dart';
import '../../services/friends_service.dart';
import '../../services/locale_provider.dart';
import '../../services/royale_service.dart';
import '../../constants/app_constants.dart';
import '../../utils/snackbar.dart';
import '../../widgets/app_version_text.dart';
import '../game/royale_arena_page.dart';

part 'home_page_layout.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late final FriendsService _friendsService;
  late final RoyaleService _royaleService;
  FriendsOverview? _friendsOverview;
  int? _loadedUserId;
  bool _isLoadingFriends = false;
  String? _busyKey;

  Map<String, String> get _t => context.read<LocaleProvider>().translation;

  @override
  void initState() {
    super.initState();
    final apiClient = ApiClient();
    _friendsService = FriendsService(apiClient);
    _royaleService = RoyaleService(apiClient);
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

  bool _isBusy(String key) => _busyKey == key;

  void _showSnackBar(String message) {
    showAppSnackBar(context, message);
  }

  Future<void> _runDrawerFriendAction(
    String busyKey,
    Future<void> Function() action, {
    String? successMessage,
  }) async {
    if (_busyKey != null) {
      return;
    }

    setState(() {
      _busyKey = busyKey;
    });

    try {
      await action();
      await _loadFriends();
      if (!mounted) {
        return;
      }
      if (successMessage != null) {
        _showSnackBar(successMessage);
      }
    } on ApiException catch (e) {
      if (!mounted) {
        return;
      }
      _showSnackBar(e.message);
    } finally {
      if (mounted) {
        setState(() {
          _busyKey = null;
        });
      }
    }
  }

  Future<void> _acceptIncomingRequest(FriendRequestItem item) async {
    await _runDrawerFriendAction(
      'accept-${item.id}',
      () => _friendsService.acceptFriendRequest(item.id),
      successMessage: _t.text('You are now friends'),
    );
  }

  Future<void> _rejectIncomingRequest(FriendRequestItem item) async {
    await _runDrawerFriendAction(
      'reject-${item.id}',
      () => _friendsService.rejectFriendRequest(item.id),
    );
  }

  Future<RoyaleDeck?> _pickDeck() async {
    final decks = await _royaleService.fetchDecks();
    if (decks.isEmpty) {
      throw ApiException(_t.text('Please create a deck first'));
    }
    if (decks.length == 1) {
      return decks.first;
    }

    RoyaleDeck selected = decks.first;
    if (!mounted) {
      return null;
    }
    return showDialog<RoyaleDeck>(
      context: context,
      builder: (context) {
        final t = context.watch<LocaleProvider>().translation;
        return AlertDialog(
          title: Text(t.text('Choose a deck to battle with')),
          content: StatefulBuilder(
            builder: (context, setState) {
              return DropdownButtonFormField<RoyaleDeck>(
                initialValue: selected,
                items: decks
                    .map(
                      (deck) => DropdownMenuItem<RoyaleDeck>(
                        value: deck,
                        child: Text(deck.name),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  if (value == null) {
                    return;
                  }
                  setState(() {
                    selected = value;
                  });
                },
              );
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(t.text('Cancel')),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(selected),
              child: Text(t.text('Confirm')),
            ),
          ],
        );
      },
    );
  }

  Future<void> _acceptRoomInvite(RoomInviteItem invite) async {
    await _runDrawerFriendAction('room-accept-${invite.id}', () async {
      final deck = await _pickDeck();
      if (deck == null) {
        return;
      }
      final result = await _friendsService.acceptRoomInvite(invite.id);
      final room = await _royaleService.joinRoom(
        roomCode: result.roomCode,
        deckId: deck.id,
      );
      if (!mounted) {
        return;
      }
      final navigator = Navigator.of(context);
      navigator.pop();
      navigator.push(
        MaterialPageRoute(builder: (_) => RoyaleArenaPage(roomCode: room.code)),
      );
    });
  }

  Future<void> _rejectRoomInvite(RoomInviteItem invite) async {
    await _runDrawerFriendAction(
      'room-reject-${invite.id}',
      () => _friendsService.rejectRoomInvite(invite.id),
    );
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
