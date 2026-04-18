import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/app_user.dart';
import '../../models/friends_models.dart';
import '../../models/royale_models.dart';
import '../../services/api_client.dart';
import '../../services/auth_service.dart';
import '../../services/friends_service.dart';
import '../../services/friends_overview_sync_service.dart';
import '../../services/locale_provider.dart';
import '../../services/chat_service.dart';
import '../../services/notification_service.dart';
import '../../services/royale_service.dart';
import '../../constants/app_constants.dart';
import '../social/dm_page.dart';
import '../../main.dart';
import '../../utils/snackbar.dart';
import '../../widgets/friend_search_dialog.dart';
import '../../widgets/app_version_text.dart';
import '../game/royale_arena_page.dart';

part 'home_page_layout.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with RouteAware {
  late final FriendsService _friendsService;
  late final RoyaleService _royaleService;
  late final ChatService _chatService;
  String? _busyKey;
  int? _overviewRequestedForUserId;
  PageRoute<dynamic>? _observedRoute;
  int? _openingConversationUserId;

  Map<String, String> get _t => context.read<LocaleProvider>().translation;

  @override
  void initState() {
    super.initState();
    final apiClient = ApiClient();
    _friendsService = FriendsService(apiClient);
    _royaleService = RoyaleService(apiClient);
    _chatService = ChatService(apiClient);
  }

  bool _canManageCards(AppUser user) {
    return user.role == 'admin' || user.role == 'card_manager';
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route is PageRoute<dynamic> && route != _observedRoute) {
      if (_observedRoute != null) {
        appRouteObserver.unsubscribe(this);
      }
      _observedRoute = route;
      appRouteObserver.subscribe(this, route);
    }
    final auth = context.read<AuthService>();
    final userId = auth.user?.id;
    if (userId == null || userId == _overviewRequestedForUserId) {
      return;
    }
    _overviewRequestedForUserId = userId;
    unawaited(
      context.read<FriendsOverviewSyncService>().refreshFor(auth, silent: false),
    );
  }

  bool _isBusy(String key) => _busyKey == key;

  void _showSnackBar(String message) {
    showAppSnackBar(context, message);
  }

  Future<void> _refreshFriendsOverview({bool silent = true}) async {
    await context.read<FriendsOverviewSyncService>().refreshFor(
      context.read<AuthService>(),
      silent: silent,
    );
  }

  @override
  void didPopNext() {
    unawaited(_refreshFriendsOverview(silent: false));
  }

  @override
  void dispose() {
    if (_observedRoute != null) {
      appRouteObserver.unsubscribe(this);
    }
    super.dispose();
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
      if (!mounted) {
        return;
      }
      await _refreshFriendsOverview();
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

  void _openDmPage(SocialUser friend) {
    final currentUserId = context.read<AuthService>().user?.id ?? 0;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => DmPage(
          chatService: _chatService,
          friendId: friend.userId,
          friendName: friend.name,
          currentUserId: currentUserId,
        ),
      ),
    );
  }

  void _maybeOpenConversationFromPush(
    NotificationService notificationService,
    FriendsOverview? overview,
  ) {
    final pendingUserId = notificationService.pendingConversationUserId;
    if (pendingUserId == null || overview == null) {
      return;
    }

    SocialUser? friend;
    for (final item in overview.friends) {
      if (item.userId == pendingUserId) {
        friend = item;
        break;
      }
    }
    if (friend == null || _openingConversationUserId == pendingUserId) {
      return;
    }

    final resolvedFriend = friend;
    _openingConversationUserId = pendingUserId;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      notificationService.clearPendingConversationUserId();
      _openingConversationUserId = null;
      _openDmPage(resolvedFriend);
    });
  }

  Future<void> _openFriendSearchDialog() async {
    await showFriendSearchDialog(
      context: context,
      friendsService: _friendsService,
      onRefreshFriends: _refreshFriendsOverview,
      onMessage: _showSnackBar,
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
    final friendsSync = context.watch<FriendsOverviewSyncService>();
    final notificationService = context.watch<NotificationService>();
    final t = context.watch<LocaleProvider>().translation;
    if (user == null) {
      return Scaffold(body: Center(child: Text(t.text('Please log in first'))));
    }

    _maybeOpenConversationFromPush(notificationService, friendsSync.overview);

    return Scaffold(
      drawer: _buildDrawer(
        user,
        overview: friendsSync.overview,
        isLoadingFriends: friendsSync.isLoading,
      ),
      appBar: AppBar(
        title: const Text(AppConstants.appName),
        actions: [
          if (kIsWeb && notificationService.canRequestWebPushPermission)
            IconButton(
              onPressed: () => notificationService.requestPushPermission(user),
              icon: const Icon(Icons.notifications_outlined),
              tooltip: t.text('Enable Notifications'),
            ),
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
