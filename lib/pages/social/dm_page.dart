import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/chat_models.dart';
import '../../services/chat_service.dart';
import '../../services/notification_service.dart';

class DmPage extends StatefulWidget {
  const DmPage({
    super.key,
    required this.chatService,
    required this.friendId,
    required this.friendName,
    required this.currentUserId,
  });

  final ChatService chatService;
  final int friendId;
  final String friendName;
  final int currentUserId;

  @override
  State<DmPage> createState() => _DmPageState();
}

class _DmPageState extends State<DmPage> {
  final List<ChatMessage> _messages = [];
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  StreamSubscription<ChatMessage>? _subscription;
  late final NotificationService _notificationService;
  bool _loading = true;
  bool _syncing = false;
  bool _uploading = false;
  bool _downloading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _notificationService = context.read<NotificationService>();
    _notificationService.setActiveConversation(widget.friendId);
    _loadHistory();
    widget.chatService.connectToDm(
      widget.currentUserId,
      widget.friendId,
      isCaller: true,
    );
    _subscription = widget.chatService.messageStream.listen((msg) {
      setState(() {
        // 1. Try to find by pendingId (pending → delivered with different createdAt)
        int idx = -1;
        if (msg.pendingId != null) {
          idx = _messages.indexWhere((m) => m.pendingId == msg.pendingId);
        }
        // 2. Fall back to createdAt+senderId key (recalls, re-deliveries)
        if (idx < 0) {
          final key = '${msg.createdAt}_${msg.senderId}';
          idx = _messages.indexWhere(
            (m) => '${m.createdAt}_${m.senderId}' == key,
          );
        }
        if (idx >= 0) {
          _messages[idx] = msg;
        } else {
          _messages.add(msg);
        }
      });
      _scrollToBottom();
    });
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _notificationService.setActiveConversation(null);
    widget.chatService.disconnect();
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadHistory() async {
    try {
      final history = await widget.chatService.fetchHistory(
        widget.currentUserId,
        widget.friendId,
      );
      setState(() {
        _messages.addAll(history);
        _loading = false;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    }
  }

  Future<void> _syncFromServer() async {
    setState(() => _syncing = true);
    try {
      final history = await widget.chatService.syncFromServer(
        widget.currentUserId,
        widget.friendId,
      );
      setState(() {
        _messages
          ..clear()
          ..addAll(history);
      });
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
    } finally {
      setState(() => _syncing = false);
    }
  }

  Future<void> _sendMessage() async {
    final text = _textController.text.trim();
    if (text.isEmpty) return;
    _textController.clear();
    await widget.chatService.sendMessage(widget.friendId, text);
  }

  Future<void> _uploadSync() async {
    setState(() => _uploading = true);
    try {
      await widget.chatService.uploadSyncData(
        widget.currentUserId,
        widget.friendId,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('已上傳，請在 1 小時內於另一台裝置下載')));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('上傳失敗')));
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<void> _downloadSync() async {
    setState(() => _downloading = true);
    try {
      await widget.chatService.downloadAndMergeSyncData(widget.friendId);
      // Reload messages from local after merge
      final history = await widget.chatService.syncFromServer(
        widget.currentUserId,
        widget.friendId,
      );
      if (!mounted) return;
      setState(() {
        _messages
          ..clear()
          ..addAll(history);
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('聊天記錄已同步')));
    } catch (e) {
      if (!mounted) return;
      final msg =
          e.toString().contains('No data') || e.toString().contains('404')
          ? '沒有可下載的資料（請先從另一台裝置上傳）'
          : '下載失敗';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    } finally {
      if (mounted) setState(() => _downloading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.friendName),
        actions: [
          IconButton(
            icon: _uploading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.upload),
            tooltip: '上傳記錄到伺服器',
            onPressed: (_uploading || _downloading || _syncing)
                ? null
                : _uploadSync,
          ),
          IconButton(
            icon: _downloading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.download),
            tooltip: '從伺服器下載記錄',
            onPressed: (_uploading || _downloading || _syncing)
                ? null
                : _downloadSync,
          ),
          IconButton(
            icon: const Icon(Icons.sync),
            tooltip: '從伺服器同步',
            onPressed: _syncing ? null : _syncFromServer,
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(child: _buildMessageList()),
          _buildInputBar(),
        ],
      ),
    );
  }

  Widget _buildMessageList() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(child: Text(_error!));
    }
    if (_messages.isEmpty) {
      return const Center(child: Text('還沒有訊息，說聲 Hi 吧！'));
    }
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      itemCount: _messages.length,
      itemBuilder: (context, index) => _buildBubble(_messages[index]),
    );
  }

  Widget _buildBubble(ChatMessage msg) {
    final isMine = msg.senderId == widget.currentUserId;

    // Recalled bubble — show placeholder regardless of sender
    if (msg.isRecalled) {
      return Align(
        alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 4),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: Theme.of(
                context,
              ).colorScheme.outline.withValues(alpha: 0.4),
            ),
          ),
          child: Text(
            isMine ? '你收回了一則訊息' : '對方收回了一則訊息',
            style: TextStyle(
              fontStyle: FontStyle.italic,
              fontSize: 13,
              color: Theme.of(
                context,
              ).colorScheme.onSurface.withValues(alpha: 0.5),
            ),
          ),
        ),
      );
    }

    final bubble = Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      constraints: BoxConstraints(
        maxWidth: MediaQuery.of(context).size.width * 0.7,
      ),
      decoration: BoxDecoration(
        color: isMine
            ? Theme.of(context).colorScheme.primary
            : Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: isMine
            ? CrossAxisAlignment.end
            : CrossAxisAlignment.start,
        children: [
          Text(
            msg.text,
            style: TextStyle(
              color: isMine
                  ? Theme.of(context).colorScheme.onPrimary
                  : Theme.of(context).colorScheme.onSurface,
            ),
          ),
          if (isMine && msg.isPending)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                '傳送中…',
                style: TextStyle(
                  fontSize: 10,
                  color: Theme.of(
                    context,
                  ).colorScheme.onPrimary.withValues(alpha: 0.6),
                ),
              ),
            ),
        ],
      ),
    );

    if (!isMine) {
      return Align(alignment: Alignment.centerLeft, child: bubble);
    }

    // Own messages: long-press to recall
    return Align(
      alignment: Alignment.centerRight,
      child: GestureDetector(
        onLongPress: () => _confirmRecall(msg),
        child: bubble,
      ),
    );
  }

  Future<void> _confirmRecall(ChatMessage msg) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('收回訊息'),
        content: const Text('確定要收回這則訊息嗎？對方將看到「已收回」。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('收回'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await widget.chatService.recallMessage(msg);
    }
  }

  Widget _buildInputBar() {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 4, 8, 8),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _textController,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _sendMessage(),
                decoration: InputDecoration(
                  hintText: '輸入訊息…',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                  ),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                ),
              ),
            ),
            const SizedBox(width: 8),
            IconButton.filled(
              icon: const Icon(Icons.send),
              onPressed: _sendMessage,
            ),
          ],
        ),
      ),
    );
  }
}
