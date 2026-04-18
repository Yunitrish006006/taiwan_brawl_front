part of 'home_page.dart';

extension _HomePageLayout on _HomePageState {
  bool _shouldShowInstallBanner() {
    final ctx = web_push_bridge.getDisplayContext();
    return ctx.isMobile && !ctx.isStandalone;
  }

  Widget _buildInstallBanner(Map<String, String> t) {
    return Material(
      color: PsnColors.playstationBlue.withValues(alpha: 0.15),
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            const Icon(
              Icons.install_mobile_outlined,
              size: 22,
              color: PsnColors.playstationBlue,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                t.text('Install the app for the best experience'),
                style: const TextStyle(
                  color: PsnColors.inverseWhite,
                  fontSize: 14,
                ),
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              onPressed: _dismissInstallBanner,
              icon: const Icon(
                Icons.close,
                size: 18,
                color: PsnColors.inverseWhite,
              ),
              visualDensity: VisualDensity.compact,
              tooltip: t.text('Dismiss'),
            ),
          ],
        ),
      ),
    );
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
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          onTap: isEnabled ? onTap : null,
          borderRadius: BorderRadius.circular(8),
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
        borderRadius: BorderRadius.circular(999),
        child: InkWell(
          onTap: isEnabled ? onTap : null,
          borderRadius: BorderRadius.circular(999),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
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
        color: backgroundColor ?? const Color(0xFF1A1D1F),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor ?? const Color(0xFF2A2A2A)),
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
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    color: PsnColors.inverseWhite,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF888888),
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
          backgroundColor: const Color(0xFF3D1A17),
          foregroundColor: const Color(0xFFFF6B5B),
          onTap: isActionLocked ? null : () => _rejectRoomInvite(invite),
          isLoading: isRejectBusy,
        ),
        const SizedBox(width: 8),
        _buildDrawerIconActionButton(
          icon: Icons.check_rounded,
          backgroundColor: const Color(0xFF0B3320),
          foregroundColor: const Color(0xFF34C759),
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
      trailingWidth: roomInvite != null ? 72 : 32,
      trailing: roomInvite != null
          ? _buildDrawerRoomInviteActions(roomInvite)
          : _buildDrawerIconActionButton(
              icon: Icons.chat_bubble_outline_rounded,
              backgroundColor: PsnColors.playstationBlue.withValues(alpha: 0.2),
              foregroundColor: PsnColors.playstationBlue,
              onTap: () => _openDmPage(friend),
            ),
      backgroundColor: const Color(0xFF1A1D1F),
      borderColor: const Color(0xFF2A2A2A),
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
            backgroundColor: const Color(0xFF0B3320),
            foregroundColor: const Color(0xFF34C759),
            onTap: isActionLocked ? null : () => _acceptIncomingRequest(item),
            isLoading: isAcceptBusy,
          ),
          const SizedBox(height: 8),
          _buildDrawerTextActionButton(
            label: _t.text('Reject'),
            backgroundColor: const Color(0xFF3D1A17),
            foregroundColor: const Color(0xFFFF6B5B),
            onTap: isActionLocked ? null : () => _rejectIncomingRequest(item),
            isLoading: isRejectBusy,
          ),
        ],
      ),
      backgroundColor: const Color(0xFF1A1D1F),
      borderColor: const Color(0xFF2A2A2A),
    );
  }

  Widget _buildDrawerHeader(AppUser user) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF003F7A), PsnColors.playstationBlue],
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
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            user.name,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w300,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            user.email,
            style: const TextStyle(color: Colors.white70, fontSize: 13),
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
      leading: Icon(icon, color: PsnColors.playstationBlue, size: 20),
      title: Text(
        label,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: PsnColors.deepCharcoal,
        ),
      ),
      trailing: const Icon(
        Icons.chevron_right,
        size: 18,
        color: Color(0xFFAAAAAA),
      ),
      onTap: onTap,
      minLeadingWidth: 20,
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 2),
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
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 10),
      child: Row(
        children: [
          Expanded(
            child: Text(
              _t.text('Friend List'),
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: PsnColors.deepCharcoal,
                letterSpacing: 0.4,
              ),
            ),
          ),
          FilledButton.icon(
            onPressed: _openFriendSearchDialog,
            icon: const Icon(Icons.person_search_rounded, size: 16),
            label: Text(_t.text('Search players')),
            style: FilledButton.styleFrom(
              backgroundColor: PsnColors.playstationBlue,
              foregroundColor: PsnColors.inverseWhite,
              visualDensity: VisualDensity.compact,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              textStyle: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
              shape: const StadiumBorder(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGameModeCard({
    required String title,
    required String subtitle,
    required String tag,
    required IconData icon,
    required Color accentColor,
    required VoidCallback onTap,
    bool isPrimary = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        decoration: BoxDecoration(
          color: isPrimary
              ? accentColor.withValues(alpha: 0.12)
              : const Color(0xFF111214),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isPrimary
                ? accentColor.withValues(alpha: 0.5)
                : const Color(0xFF2A2A2A),
            width: isPrimary ? 1.5 : 1,
          ),
        ),
        child: Stack(
          children: [
            // Background glow for primary card
            if (isPrimary)
              Positioned(
                top: -30,
                right: -30,
                child: Container(
                  width: 140,
                  height: 140,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        accentColor.withValues(alpha: 0.15),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                          color: accentColor.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: accentColor.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Icon(icon, color: accentColor, size: 26),
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: accentColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(
                            color: accentColor.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Text(
                          tag,
                          style: TextStyle(
                            color: accentColor,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.6,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Text(
                    title,
                    style: const TextStyle(
                      color: PsnColors.inverseWhite,
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: Color(0xFF888888),
                      fontSize: 13,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Text(
                        _t.text('Play now'),
                        style: TextStyle(
                          color: accentColor,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.3,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Icon(
                        Icons.arrow_forward_rounded,
                        color: accentColor,
                        size: 16,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDeckBuilderCard(Map<String, String> t) {
    return GestureDetector(
      onTap: () => _openRoute('/royale-deck'),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF111214),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFF2A2A2A)),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: const Color(0xFF1A1D22),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF333333)),
              ),
              child: const Icon(
                Icons.style_outlined,
                color: Color(0xFFAAAAAA),
                size: 22,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    t.text('Mini Royale Deck Builder'),
                    style: const TextStyle(
                      color: PsnColors.inverseWhite,
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    t.text('Build and manage your decks'),
                    style: const TextStyle(
                      color: Color(0xFF666666),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right_rounded,
              color: Color(0xFF444444),
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPrimaryActionList(
    AppUser user,
    Map<String, String> t, {
    required bool installBannerDismissed,
  }) {
    final showInstallBanner =
        kIsWeb && !installBannerDismissed && _shouldShowInstallBanner();
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 48),
      children: [
        if (showInstallBanner) _buildInstallBanner(t),
        if (showInstallBanner) const SizedBox(height: 16),

        // Hero greeting
        Text(
          '${t.text('Welcome back')}',
          style: const TextStyle(
            color: Color(0xFF888888),
            fontSize: 13,
            fontWeight: FontWeight.w500,
            letterSpacing: 0.4,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          user.name,
          style: const TextStyle(
            color: PsnColors.inverseWhite,
            fontSize: 32,
            fontWeight: FontWeight.w300,
            letterSpacing: 0.1,
          ),
        ),
        const SizedBox(height: 32),

        // Section label
        const Text(
          'GAME MODES',
          style: TextStyle(
            color: Color(0xFF555555),
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 12),

        // Mini Royale — primary hero card
        _buildGameModeCard(
          title: t.text('Mini Royale Lobby Battle'),
          subtitle: t.text(
            'Join a lobby, build your strategy and fight to the top.',
          ),
          tag: 'MULTIPLAYER',
          icon: Icons.sports_esports_outlined,
          accentColor: PsnColors.playstationBlue,
          isPrimary: true,
          onTap: () => _openRoute('/royale-lobby'),
        ),
        const SizedBox(height: 12),

        // Archery — secondary card
        _buildGameModeCard(
          title: t.text('Archery Game'),
          subtitle: t.text(
            'Test your precision in this single-player archery challenge.',
          ),
          tag: 'SOLO',
          icon: Icons.architecture,
          accentColor: const Color(0xFF34C759),
          onTap: () => _openRoute('/archery'),
        ),
        const SizedBox(height: 28),

        // Section label
        const Text(
          'COLLECTION',
          style: TextStyle(
            color: Color(0xFF555555),
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 12),

        // Deck Builder — compact row
        _buildDeckBuilderCard(t),
        const SizedBox(height: 48),
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
      backgroundColor: PsnColors.paperWhite,
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
