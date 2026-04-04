part of 'home_page.dart';

extension _HomePageLayout on _HomePageState {
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

  Widget _buildDrawerIconActionButton({
    required IconData icon,
    required Color backgroundColor,
    required Color foregroundColor,
    required VoidCallback? onTap,
    bool isLoading = false,
  }) {
    final isEnabled = onTap != null && !isLoading;
    final effectiveForeground = isEnabled
        ? foregroundColor
        : foregroundColor.withValues(alpha: 0.45);

    return SizedBox(
      width: 32,
      height: 32,
      child: Material(
        color: isEnabled
            ? backgroundColor
            : backgroundColor.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          onTap: isEnabled ? onTap : null,
          borderRadius: BorderRadius.circular(10),
          child: Center(
            child: isLoading
                ? SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        effectiveForeground,
                      ),
                    ),
                  )
                : Icon(icon, size: 17, color: effectiveForeground),
          ),
        ),
      ),
    );
  }

  Widget _buildDrawerTextActionButton({
    required String label,
    required Color backgroundColor,
    required Color foregroundColor,
    required VoidCallback? onTap,
    bool isLoading = false,
  }) {
    final isEnabled = onTap != null && !isLoading;
    final effectiveForeground = isEnabled
        ? foregroundColor
        : foregroundColor.withValues(alpha: 0.45);

    return SizedBox(
      height: 32,
      child: Material(
        color: isEnabled
            ? backgroundColor
            : backgroundColor.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          onTap: isEnabled ? onTap : null,
          borderRadius: BorderRadius.circular(10),
          child: Center(
            child: isLoading
                ? SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        effectiveForeground,
                      ),
                    ),
                  )
                : Text(
                    label,
                    style: TextStyle(
                      color: effectiveForeground,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
          ),
        ),
      ),
    );
  }

  Widget _buildDrawerFriendTileFrame({
    required Widget avatar,
    required String title,
    required String subtitle,
    Widget? trailing,
    double trailingWidth = 0,
    Color? backgroundColor,
    Color? borderColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(16),
        border: borderColor == null ? null : Border.all(color: borderColor),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          avatar,
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          if (trailing != null) ...[
            const SizedBox(width: 12),
            SizedBox(width: trailingWidth, child: trailing),
          ],
        ],
      ),
    );
  }

  Widget _buildDrawerRoomInviteActions(RoomInviteItem invite) {
    final isAcceptBusy = _isBusy('room-accept-${invite.id}');
    final isRejectBusy = _isBusy('room-reject-${invite.id}');
    final isActionLocked = _busyKey != null && !isAcceptBusy && !isRejectBusy;

    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        _buildDrawerIconActionButton(
          icon: Icons.close_rounded,
          backgroundColor: const Color(0xFFFFE1DE),
          foregroundColor: const Color(0xFF9A2F22),
          onTap: isActionLocked ? null : () => _rejectRoomInvite(invite),
          isLoading: isRejectBusy,
        ),
        const SizedBox(width: 8),
        _buildDrawerIconActionButton(
          icon: Icons.check_rounded,
          backgroundColor: const Color(0xFFDDF4E4),
          foregroundColor: const Color(0xFF17663A),
          onTap: isActionLocked ? null : () => _acceptRoomInvite(invite),
          isLoading: isAcceptBusy,
        ),
      ],
    );
  }

  Widget _buildDrawerFriendTile(
    SocialUser friend, {
    RoomInviteItem? roomInvite,
  }) {
    return _buildDrawerFriendTileFrame(
      avatar: Stack(
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
      title: friend.name,
      subtitle: roomInvite != null
          ? '${_t.text('Room')} ${roomInvite.roomCode}'
          : _friendStatusText(friend),
      trailingWidth: roomInvite != null ? 72 : 0,
      trailing: roomInvite != null ? _buildDrawerRoomInviteActions(roomInvite) : null,
      backgroundColor: Theme.of(context).colorScheme.surface,
      borderColor: Theme.of(
        context,
      ).colorScheme.outlineVariant.withValues(alpha: 0.5),
    );
  }

  Widget _buildIncomingRequestTile(FriendRequestItem item) {
    final isAcceptBusy = _isBusy('accept-${item.id}');
    final isRejectBusy = _isBusy('reject-${item.id}');
    final isActionLocked = _busyKey != null && !isAcceptBusy && !isRejectBusy;

    return _buildDrawerFriendTileFrame(
      avatar: _buildUserAvatar(
        label: item.user.name,
        avatarUrl: item.user.avatarUrl,
        radius: 18,
        fallbackBackgroundColor: const Color(0xFF8A5A00),
      ),
      title: item.user.name,
      subtitle: _t.text('They invited you'),
      trailingWidth: 92,
      trailing: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildDrawerTextActionButton(
            label: _t.text('Accept'),
            backgroundColor: const Color(0xFFDDF4E4),
            foregroundColor: const Color(0xFF17663A),
            onTap: isActionLocked ? null : () => _acceptIncomingRequest(item),
            isLoading: isAcceptBusy,
          ),
          const SizedBox(height: 8),
          _buildDrawerTextActionButton(
            label: _t.text('Reject'),
            backgroundColor: const Color(0xFFFFE1DE),
            foregroundColor: const Color(0xFF9A2F22),
            onTap: isActionLocked ? null : () => _rejectIncomingRequest(item),
            isLoading: isRejectBusy,
          ),
        ],
      ),
      backgroundColor: Theme.of(context).colorScheme.surface,
      borderColor: Theme.of(
        context,
      ).colorScheme.outlineVariant.withValues(alpha: 0.5),
    );
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

  Widget _buildDrawerFriendList(
    FriendsOverview? overview, {
    required bool isLoadingFriends,
  }) {
    final roomInvites = overview?.roomInvites ?? const <RoomInviteItem>[];
    final incomingRequests = overview?.incomingRequests ?? const <FriendRequestItem>[];
    final friends = overview?.friends ?? const <SocialUser>[];
    final roomInviteByInviterUserId = <int, RoomInviteItem>{
      for (final invite in roomInvites) invite.inviter.userId: invite,
    };

    if (isLoadingFriends && overview == null) {
      return const Center(child: CircularProgressIndicator());
    }
    if (overview == null) {
      return Center(child: Text(_t.text('Failed to load friend data')));
    }
    if (incomingRequests.isEmpty && friends.isEmpty) {
      return Center(child: Text(_t.text('No friends yet')));
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      children: [
        for (var index = 0; index < incomingRequests.length; index++) ...[
          _buildIncomingRequestTile(incomingRequests[index]),
          const SizedBox(height: 8),
        ],
        for (var index = 0; index < friends.length; index++) ...[
          _buildDrawerFriendTile(
            friends[index],
            roomInvite: roomInviteByInviterUserId[friends[index].userId],
          ),
          if (index < friends.length - 1) const SizedBox(height: 8),
        ],
      ],
    );
  }

  Widget _buildDrawerFriendHeader() {
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
          FilledButton.icon(
            onPressed: _openFriendSearchDialog,
            icon: const Icon(Icons.person_search_rounded, size: 18),
            label: Text(_t.text('Search players')),
            style: FilledButton.styleFrom(
              visualDensity: VisualDensity.compact,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            ),
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
        const SizedBox(height: 24),
        Text(
          t.text('Mini Royale Lobby Battle'),
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 16),
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
        const SizedBox(height: 12),
        ElevatedButton.icon(
          onPressed: () => _openRoute('/archery'),
          icon: const Icon(Icons.architecture),
          label: Text(t.text('Archery Game')),
        ),
        const SizedBox(height: 24),
        const AppVersionText(),
      ],
    );
  }

  Drawer _buildDrawer(
    AppUser user, {
    required FriendsOverview? overview,
    required bool isLoadingFriends,
  }) {
    return Drawer(
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildDrawerHeader(user),
            _buildDrawerNavigationTile(
              icon: Icons.edit_outlined,
              label: _t.text('Edit Profile'),
              onTap: () => _openRoute('/profile', closeDrawer: true),
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
            _buildDrawerFriendHeader(),
            Expanded(
              child: _buildDrawerFriendList(
                overview,
                isLoadingFriends: isLoadingFriends,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
