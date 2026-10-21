import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:taiwan_brawl_messaging/taiwan_brawl_messaging.dart';
import 'package:user_basic_system/user_basic_system.dart' as ubs;

import '../../services/chat_service.dart';
import '../../services/editable_dm_service.dart';
import '../../services/messaging_transport_factory.dart';
import '../../services/peer_trust_service.dart';
import '../../services/secure_device_identity.dart';
import '../../widgets/peer_trust_dialog.dart';

/// Frontend-owned DM page. It keeps the external package's service and model
/// contracts while adding edit support for event-based services.
class EditableDmPage extends StatefulWidget {
  const EditableDmPage({
    super.key,
    required this.service,
    required this.friendId,
    required this.friendName,
    required this.currentUserId,
    this.strings = const ubs.DmStrings(),
    this.onActiveConversationChanged,
  });

  final ubs.DmService service;
  final int friendId;
  final String friendName;
  final int currentUserId;
  final ubs.DmStrings strings;
  final void Function(int? friendId)? onActiveConversationChanged;

  @override
  State<EditableDmPage> createState() => _EditableDmPageState();
}

class _EditableDmPageState extends State<EditableDmPage> {
  final _messages = <ubs.ChatMessage>[];
  final _textController = TextEditingController();
  final _scrollController = ScrollController();
  StreamSubscription<ubs.ChatMessage>? _subscription;
  bool _loading = true;
  bool _syncing = false;
  bool _uploading = false;
  bool _downloading = false;
  String? _error;

  ubs.DmStrings get _s => widget.strings;

  @override
  void initState() {
    super.initState();
    widget.onActiveConversationChanged?.call(widget.friendId);
    unawaited(_loadHistory());
    unawaited(
      widget.service.connectToDm(
        widget.currentUserId,
        widget.friendId,
        isCaller: MessagingTransportFactory.isCaller(
          selfId: widget.currentUserId,
          friendId: widget.friendId,
        ),
      ),
    );
    _subscription = widget.service.messageStream.listen(_receiveMessage);
  }

  @override
  void dispose() {
    _subscription?.cancel();
    widget.onActiveConversationChanged?.call(null);
    widget.service.disconnect();
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _receiveMessage(ubs.ChatMessage message) {
    if (!mounted) return;
    setState(() {
      final key = '${message.createdAt}_${message.senderId}';
      final index = message.pendingId == null
          ? _messages.indexWhere(
              (item) => '${item.createdAt}_${item.senderId}' == key,
            )
          : _messages.indexWhere((item) => item.pendingId == message.pendingId);
      if (index >= 0) {
        _messages[index] = message;
      } else {
        _messages.add(message);
      }
    });
    final service = widget.service;
    if (service is ChatService && message.senderId == widget.friendId) {
      unawaited(service.markMessageRead(message));
    }
    _scrollToBottom();
  }

  Future<void> _loadHistory() async {
    try {
      final history = await widget.service.fetchHistory(
        widget.currentUserId,
        widget.friendId,
      );
      if (!mounted) return;
      setState(() {
        _messages
          ..clear()
          ..addAll(history);
        _loading = false;
      });
      _markIncomingMessagesRead(history);
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.toString();
        _loading = false;
      });
    }
  }

  Future<void> _syncFromServer() async {
    setState(() => _syncing = true);
    try {
      final history = await widget.service.syncFromServer(
        widget.currentUserId,
        widget.friendId,
      );
      if (!mounted) return;
      setState(() {
        _messages
          ..clear()
          ..addAll(history);
      });
      _markIncomingMessagesRead(history);
      _scrollToBottom();
    } finally {
      if (mounted) setState(() => _syncing = false);
    }
  }

  Future<void> _uploadSync() async {
    setState(() => _uploading = true);
    try {
      await widget.service.uploadSyncData(
        widget.currentUserId,
        widget.friendId,
      );
      if (mounted) _showSnack(_s.uploadSuccess);
    } catch (_) {
      if (mounted) _showSnack(_s.uploadFailed);
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<void> _downloadSync() async {
    setState(() => _downloading = true);
    try {
      await widget.service.downloadAndMergeSyncData(widget.friendId);
      await _syncFromServer();
      if (mounted) _showSnack(_s.syncSuccess);
    } catch (error) {
      if (!mounted) return;
      final noData =
          error.toString().contains('No data') ||
          error.toString().contains('404');
      _showSnack(noData ? _s.downloadNoData : _s.downloadFailed);
    } finally {
      if (mounted) setState(() => _downloading = false);
    }
  }

  void _markIncomingMessagesRead(Iterable<ubs.ChatMessage> messages) {
    final service = widget.service;
    if (service is! ChatService) return;
    for (final message in messages) {
      if (message.senderId == widget.friendId) {
        unawaited(service.markMessageRead(message));
      }
    }
  }

  Future<void> _showManualP2pDialog() async {
    final service = widget.service;
    if (service is! ChatService || !service.manualP2pEnabled) return;

    final low = widget.currentUserId < widget.friendId
        ? widget.currentUserId
        : widget.friendId;
    final high = widget.currentUserId < widget.friendId
        ? widget.friendId
        : widget.currentUserId;
    final sessionId = 'dm:$low:$high';
    final senderDeviceId =
        service.manualDeviceId ?? 'user:${widget.currentUserId}';
    final inputController = TextEditingController();
    String exported = '';
    bool prepared = false;
    bool imported = false;
    bool isCaller = MessagingTransportFactory.isCaller(
      selfId: widget.currentUserId,
      friendId: widget.friendId,
    );

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Serverless P2P connection'),
          content: SizedBox(
            width: 520,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Exchange the bundle with your friend by copy/paste or QR. Only negotiation data is included.',
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: () async {
                      final trustService = context.read<PeerTrustService>();
                      final identity = context.read<DeviceIdentity?>();
                      await showPeerTrustDialog(
                        context,
                        trustService: trustService,
                        localIdentity: identity is SecureDeviceIdentity
                            ? identity
                            : null,
                      );
                    },
                    icon: const Icon(Icons.verified_user),
                    label: const Text('Peer identity trust'),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<bool>(
                    initialValue: isCaller,
                    decoration: const InputDecoration(labelText: 'Role'),
                    items: const [
                      DropdownMenuItem(value: true, child: Text('Caller')),
                      DropdownMenuItem(value: false, child: Text('Answerer')),
                    ],
                    onChanged: prepared
                        ? null
                        : (value) => setDialogState(
                            () => isCaller = value ?? isCaller,
                          ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: inputController,
                    minLines: 3,
                    maxLines: 8,
                    onChanged: (_) => setDialogState(() {}),
                    decoration: const InputDecoration(
                      labelText: 'Paste peer bundle',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      OutlinedButton.icon(
                        onPressed: inputController.text.trim().isEmpty
                            ? null
                            : () {
                                try {
                                  service.importManualP2pBundle(
                                    inputController.text.trim(),
                                    expectedSessionId: sessionId,
                                  );
                                  setDialogState(() => imported = true);
                                } catch (error) {
                                  _showSnack('Import failed: $error');
                                }
                              },
                        icon: const Icon(Icons.input),
                        label: const Text('Import'),
                      ),
                      const SizedBox(width: 8),
                      FilledButton.icon(
                        onPressed: prepared
                            ? null
                            : () async {
                                try {
                                  await service.prepareManualP2p(
                                    isCaller: isCaller,
                                  );
                                  final bundle = service.exportManualP2pBundle(
                                    sessionId: sessionId,
                                    senderDeviceId: senderDeviceId,
                                  );
                                  setDialogState(() {
                                    prepared = true;
                                    exported = bundle;
                                  });
                                } catch (error) {
                                  _showSnack('Prepare failed: $error');
                                }
                              },
                        icon: const Icon(Icons.link),
                        label: const Text('Prepare'),
                      ),
                    ],
                  ),
                  if (exported.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    const Text('Your bundle'),
                    SelectableText(exported),
                    Align(
                      alignment: Alignment.centerRight,
                      child: Wrap(
                        spacing: 8,
                        children: [
                          TextButton.icon(
                            onPressed: prepared
                                ? () {
                                    final bundle = service
                                        .exportManualP2pBundle(
                                          sessionId: sessionId,
                                          senderDeviceId: senderDeviceId,
                                        );
                                    if (bundle.isEmpty) return;
                                    setDialogState(() => exported = bundle);
                                  }
                                : null,
                            icon: const Icon(Icons.refresh),
                            label: const Text('Refresh'),
                          ),
                          TextButton.icon(
                            onPressed: () async {
                              await Clipboard.setData(
                                ClipboardData(text: exported),
                              );
                              _showSnack('Bundle copied');
                            },
                            icon: const Icon(Icons.copy),
                            label: const Text('Copy'),
                          ),
                        ],
                      ),
                    ),
                  ],
                  if (imported)
                    const Text('Peer bundle imported for this session.'),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Close'),
            ),
            FilledButton(
              onPressed: prepared
                  ? () async {
                      try {
                        await service.completeManualP2p();
                        if (dialogContext.mounted) {
                          Navigator.pop(dialogContext);
                        }
                        _showSnack('P2P connection completed');
                      } catch (error) {
                        _showSnack('Complete failed: $error');
                      }
                    }
                  : null,
              child: const Text('Complete connection'),
            ),
          ],
        ),
      ),
    );
    inputController.dispose();
  }

  Future<void> _sendMessage() async {
    final text = _textController.text.trim();
    if (text.isEmpty) return;
    _textController.clear();
    await widget.service.sendMessage(widget.friendId, text);
  }

  Future<void> _showMessageActions(ubs.ChatMessage message) async {
    if (message.senderId != widget.currentUserId || message.isRecalled) return;
    final action = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            if (widget.service is EditableDmService)
              ListTile(
                leading: const Icon(Icons.edit),
                title: const Text('Edit'),
                onTap: () => Navigator.pop(context, 'edit'),
              ),
            ListTile(
              leading: const Icon(Icons.undo),
              title: Text(_s.recall),
              onTap: () => Navigator.pop(context, 'recall'),
            ),
          ],
        ),
      ),
    );
    if (!mounted) return;
    if (action == 'edit') {
      await _editMessage(message);
    } else if (action == 'recall') {
      await widget.service.recallMessage(message);
    }
  }

  Future<void> _editMessage(ubs.ChatMessage message) async {
    final controller = TextEditingController(text: message.text);
    final text = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit message'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLines: 4,
          textInputAction: TextInputAction.done,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(_s.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (!mounted || text == null || text.isEmpty) return;
    final service = widget.service;
    if (service is EditableDmService) {
      await (service as EditableDmService).editMessage(message, text);
    }
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.friendName),
        actions: [
          IconButton(
            tooltip: _s.uploadTooltip,
            onPressed: _uploading || _downloading || _syncing
                ? null
                : _uploadSync,
            icon: const Icon(Icons.upload),
          ),
          IconButton(
            tooltip: _s.downloadTooltip,
            onPressed: _uploading || _downloading || _syncing
                ? null
                : _downloadSync,
            icon: const Icon(Icons.download),
          ),
          IconButton(
            tooltip: _s.syncTooltip,
            onPressed: _syncing ? null : _syncFromServer,
            icon: const Icon(Icons.sync),
          ),
          if (widget.service is ChatService &&
              (widget.service as ChatService).manualP2pEnabled)
            IconButton(
              tooltip: 'Serverless P2P',
              onPressed: _showManualP2pDialog,
              icon: const Icon(Icons.link),
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
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) return Center(child: Text(_error!));
    if (_messages.isEmpty) return Center(child: Text(_s.noMessages));
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      itemCount: _messages.length,
      itemBuilder: (context, index) => _buildBubble(_messages[index]),
    );
  }

  Widget _buildBubble(ubs.ChatMessage message) {
    final isMine = message.senderId == widget.currentUserId;
    final color = isMine
        ? Theme.of(context).colorScheme.primary
        : Theme.of(context).colorScheme.surfaceContainerHighest;
    final foreground = isMine
        ? Theme.of(context).colorScheme.onPrimary
        : Theme.of(context).colorScheme.onSurface;
    final content = message.isRecalled
        ? Text(
            isMine ? _s.youRecalled : _s.theyRecalled,
            style: TextStyle(fontStyle: FontStyle.italic, color: foreground),
          )
        : Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(message.text, style: TextStyle(color: foreground)),
              if (isMine && message.isPending)
                Text(
                  _s.sending,
                  style: TextStyle(fontSize: 10, color: foreground),
                ),
            ],
          );
    final bubble = Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      constraints: BoxConstraints(
        maxWidth: MediaQuery.of(context).size.width * .7,
      ),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(16),
      ),
      child: content,
    );
    return Align(
      alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: isMine
          ? GestureDetector(
              onLongPress: () => _showMessageActions(message),
              child: bubble,
            )
          : bubble,
    );
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
                  hintText: _s.inputHint,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            IconButton.filled(
              onPressed: _sendMessage,
              icon: const Icon(Icons.send),
            ),
          ],
        ),
      ),
    );
  }
}
