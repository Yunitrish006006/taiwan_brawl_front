import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/friends_models.dart';
import '../../services/couples_service.dart';
import '../../services/locale_provider.dart';
import '../../widgets/couples_text.dart';
import '../../services/friends_service.dart';
import '../../services/friends_overview_sync_service.dart';
import 'couples_page.dart';

class FriendDetailPage extends StatefulWidget {
  const FriendDetailPage({
    super.key,
    required this.friend,
    required this.accountId,
  });
  final SocialUser friend;
  final int accountId;
  @override
  State<FriendDetailPage> createState() => _FriendDetailPageState();
}

class _FriendDetailPageState extends State<FriendDetailPage> {
  bool _busy = false;
  String _text(String key, [Map<String, String> values = const {}]) =>
      couplesText(context, key, values);
  String? _error;
  Future<void> _remove({required bool block}) async {
    final couples = context.read<CouplesService>();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(block ? _text('couples.block') : _text('couples.remove')),
        // Always warn: even a freshly fetched snapshot can race with an accepted invitation.
        content: Text(_text('couples.friendWarning')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(_text('couples.cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(_text('couples.confirm')),
          ),
        ],
      ),
    );
    if (confirmed != true ||
        !mounted ||
        couples.accountId != widget.accountId) {
      return;
    }
    final friends = context.read<FriendsService>();
    final sync = context.read<FriendsOverviewSyncService>();
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      if (block) {
        await friends.blockUser(widget.friend.userId);
      } else {
        await friends.removeFriend(widget.friend.userId);
      }
      // Invalidate old confirmed couple state, even if the next network read fails.
      await couples.invalidateAfterFriendChange(widget.accountId);
      await sync.refreshNow(silent: false);
      if (mounted) Navigator.pop(context);
    } catch (_) {
      if (mounted) setState(() => _error = 'couples.friendFailed');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    context.watch<LocaleProvider?>();
    final couples = context.watch<CouplesService>();
    if (couples.accountId != widget.accountId) {
      return Scaffold(
        appBar: AppBar(),
        body: Center(child: Text(_text('couples.accountChanged'))),
      );
    }
    final relation = couples.snapshot?.relationship;
    final partner = relation?.partnerUserId == widget.friend.userId;
    return Scaffold(
      appBar: AppBar(title: Text(widget.friend.name)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (_busy) const LinearProgressIndicator(),
          Text(widget.friend.bio),
          if (_error != null) Text(_text(_error!)),
          if (partner)
            Text(
              _text('couples.dayCount', {
                'days': '${relation!.dayCount(DateTime.now())}',
              }),
            ),
          TextButton(
            onPressed: _busy
                ? null
                : () => Navigator.push(
                    context,
                    MaterialPageRoute<void>(
                      builder: (_) => CouplesPage(friends: [widget.friend]),
                    ),
                  ),
            child: Text(_text('couples.details')),
          ),
          TextButton(
            onPressed: _busy ? null : () => _remove(block: false),
            child: Text(_text('couples.remove')),
          ),
          TextButton(
            onPressed: _busy ? null : () => _remove(block: true),
            child: Text(_text('couples.block')),
          ),
        ],
      ),
    );
  }
}
