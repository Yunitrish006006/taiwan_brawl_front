import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/friends_models.dart';
import '../services/api_client.dart';
import '../services/friends_service.dart';
import '../services/locale_provider.dart';

Future<void> showFriendSearchDialog({
  required BuildContext context,
  required FriendsService friendsService,
  required Future<void> Function() onRefreshFriends,
  required void Function(String message) onMessage,
}) {
  return showDialog<void>(
    context: context,
    builder: (_) => _FriendSearchDialog(
      friendsService: friendsService,
      onRefreshFriends: onRefreshFriends,
      onMessage: onMessage,
    ),
  );
}

class _FriendSearchDialog extends StatefulWidget {
  const _FriendSearchDialog({
    required this.friendsService,
    required this.onRefreshFriends,
    required this.onMessage,
  });

  final FriendsService friendsService;
  final Future<void> Function() onRefreshFriends;
  final void Function(String message) onMessage;

  @override
  State<_FriendSearchDialog> createState() => _FriendSearchDialogState();
}

class _FriendSearchDialogState extends State<_FriendSearchDialog> {
  final TextEditingController _searchController = TextEditingController();
  List<FriendSearchResult> _searchResults = const [];
  bool _isSearching = false;
  int? _sendingUserId;
  bool _hasSubmittedSearch = false;

  Map<String, String> get _t => context.read<LocaleProvider>().translation;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _searchByName() async {
    final input = _searchController.text.trim();
    if (input.isEmpty) {
      setState(() {
        _searchResults = const [];
        _hasSubmittedSearch = false;
      });
      return;
    }

    setState(() {
      _isSearching = true;
      _hasSubmittedSearch = true;
    });

    try {
      final results = await widget.friendsService.searchByName(input);
      if (!mounted) {
        return;
      }
      setState(() {
        _searchResults = results;
      });
    } on ApiException catch (e) {
      widget.onMessage(e.message);
    } finally {
      if (mounted) {
        setState(() {
          _isSearching = false;
        });
      }
    }
  }

  Future<void> _sendFriendRequest(FriendSearchResult result) async {
    if (_sendingUserId != null || result.relationshipStatus != 'none') {
      return;
    }

    setState(() {
      _sendingUserId = result.user.userId;
    });

    try {
      final successMessage = _t.text('Friend request sent');
      await widget.friendsService.sendFriendRequest(result.user.userId);
      if (!mounted) {
        return;
      }
      setState(() {
        _searchResults = _searchResults
            .map(
              (item) => item.user.userId == result.user.userId
                  ? FriendSearchResult(
                      user: item.user,
                      relationshipStatus: 'outgoing_pending',
                    )
                  : item,
            )
            .toList(growable: false);
      });
      await widget.onRefreshFriends();
      widget.onMessage(successMessage);
    } on ApiException catch (e) {
      widget.onMessage(e.message);
    } finally {
      if (mounted) {
        setState(() {
          _sendingUserId = null;
        });
      }
    }
  }

  String _relationshipLabel(String status) {
    switch (status) {
      case 'friend':
        return _t.text('Already friends');
      case 'outgoing_pending':
        return _t.text('Invitation already sent');
      case 'incoming_pending':
        return _t.text('They invited you');
      case 'blocked':
        return _t.text('You blocked them');
      case 'blocked_by_them':
        return _t.text('Unable to join');
      case 'self':
        return _t.text('This is you');
      default:
        return _t.text('Not friends yet');
    }
  }

  Widget _buildResultAction(FriendSearchResult result) {
    if (result.relationshipStatus == 'none') {
      final isSending = _sendingUserId == result.user.userId;
      return FilledButton.icon(
        onPressed: isSending ? null : () => _sendFriendRequest(result),
        icon: isSending
            ? const SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.person_add_alt_1_rounded, size: 18),
        label: Text(_t.text('Add Friend')),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        _relationshipLabel(result.relationshipStatus),
        style: TextStyle(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildResultTile(FriendSearchResult result) {
    final user = result.user;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Theme.of(
            context,
          ).colorScheme.outlineVariant.withValues(alpha: 0.6),
        ),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final stacked = constraints.maxWidth < 360;
          final info = Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 20,
                backgroundImage:
                    user.avatarUrl != null && user.avatarUrl!.isNotEmpty
                    ? NetworkImage(user.avatarUrl!)
                    : null,
                child: user.avatarUrl != null && user.avatarUrl!.isNotEmpty
                    ? null
                    : Text(user.name.isEmpty ? '?' : user.name.characters.first),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      user.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                      ),
                    ),
                    if (user.bio.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        user.bio,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                          fontSize: 12,
                        ),
                      ),
                    ],
                    const SizedBox(height: 6),
                    Text(
                      '${_t.text('Relationship Status')}: ${_relationshipLabel(result.relationshipStatus)}',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
          final action = _buildResultAction(result);

          if (stacked) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                info,
                const SizedBox(height: 10),
                Align(alignment: Alignment.centerRight, child: action),
              ],
            );
          }

          return Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(child: info),
              const SizedBox(width: 12),
              action,
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final showEmptyState =
        _hasSubmittedSearch && !_isSearching && _searchResults.isEmpty;

    return AlertDialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      title: Text(_t.text('Search Players by Name')),
      content: SizedBox(
        width: 520,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _searchController,
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                labelText: _t.text('Enter Player Name'),
                border: const OutlineInputBorder(),
              ),
              onSubmitted: (_) => _searchByName(),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _isSearching ? null : _searchByName,
                icon: _isSearching
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.search_rounded),
                label: Text(
                  _isSearching ? _t.text('Searching...') : _t.text('Search'),
                ),
              ),
            ),
            if (showEmptyState) ...[
              const SizedBox(height: 16),
              Text(_t.text('No matching players found')),
            ],
            if (_searchResults.isNotEmpty) ...[
              const SizedBox(height: 16),
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 360),
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: _searchResults.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (context, index) =>
                      _buildResultTile(_searchResults[index]),
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(_t.text('Cancel')),
        ),
      ],
    );
  }
}
