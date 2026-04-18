import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/api_client.dart';
import '../services/auth_service.dart';
import '../services/chat_service.dart';
import '../services/friends_overview_sync_service.dart';
import '../services/locale_provider.dart';
import '../utils/snackbar.dart';

/// Settings card that lets the user push their local chat history to the
/// server (one-time, 1-hour TTL) so another device can pull it down.
class ChatSyncPanel extends StatefulWidget {
  const ChatSyncPanel({super.key});

  @override
  State<ChatSyncPanel> createState() => _ChatSyncPanelState();
}

class _ChatSyncPanelState extends State<ChatSyncPanel> {
  late final ChatService _chatService;
  bool _uploading = false;
  bool _downloading = false;

  @override
  void initState() {
    super.initState();
    _chatService = ChatService(context.read<ApiClient>());
  }

  @override
  void dispose() {
    _chatService.disconnect();
    super.dispose();
  }

  Future<void> _upload() async {
    final user = context.read<AuthService>().user;
    if (user == null) return;
    final overview = context.read<FriendsOverviewSyncService>().overview;
    if (overview == null) {
      showAppSnackBar(context, '尚未載入好友清單，請稍後再試');
      return;
    }
    final friendIds = overview.friends.map((f) => f.userId).toList();
    setState(() => _uploading = true);
    try {
      await _chatService.uploadSyncData(user.id, friendIds);
      if (!mounted) return;
      showAppSnackBar(context, '聊天記錄已上傳，請在 1 小時內於另一台裝置下載');
    } on ApiException catch (e) {
      if (!mounted) return;
      showAppSnackBar(context, '上傳失敗：${e.message}');
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<void> _download() async {
    setState(() => _downloading = true);
    try {
      await _chatService.downloadAndMergeSyncData();
      if (!mounted) return;
      showAppSnackBar(context, '聊天記錄同步完成');
    } on ApiException catch (e) {
      if (!mounted) return;
      if (e.statusCode == 404) {
        showAppSnackBar(context, '沒有可下載的同步資料（請先從另一台裝置上傳）');
      } else {
        showAppSnackBar(context, '下載失敗：${e.message}');
      }
    } finally {
      if (mounted) setState(() => _downloading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.read<LocaleProvider>().translation;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              t.text('Chat History Sync'),
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              t.text('Chat Sync Upload Description'),
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _uploading ? null : _upload,
                    icon: _uploading
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.upload),
                    label: Text(t.text('Upload Chat History')),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _downloading ? null : _download,
                    icon: _downloading
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.download),
                    label: Text(t.text('Download Chat History')),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
