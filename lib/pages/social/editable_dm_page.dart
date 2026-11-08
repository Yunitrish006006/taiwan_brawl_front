import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:taiwan_brawl_messaging/taiwan_brawl_messaging.dart';
import 'package:user_basic_system/user_basic_system.dart' as ubs;

import '../../models/direct_message.dart';
import '../../models/message_history_page.dart';
import '../../services/dm_peer_role.dart';
import '../../services/chat_device_management_service.dart';
import '../../services/direct_message_service.dart';
import '../../services/direct_message_sync_service.dart';
import '../../services/manual_p2p_dm_service.dart';
import '../../services/p2p_retry_backoff.dart';
import '../../services/peer_trust_service.dart';
import '../../services/retryable_dm_service.dart';
import '../../services/relay_fallback_dm_service.dart';
import '../../services/secure_device_identity.dart';
import '../../widgets/peer_trust_dialog.dart';

/// Frontend-owned DM page backed by the app's direct-message service port.
class EditableDmPage extends StatefulWidget {
  const EditableDmPage({
    super.key,
    required this.service,
    required this.friendId,
    required this.friendName,
    required this.currentUserId,
    this.retryService,
    this.manualP2pService,
    this.relayFallbackService,
    this.syncService,
    this.strings = const ubs.DmStrings(),
    this.onActiveConversationChanged,
    this.connectionConnectingLabel = 'Connecting P2P',
    this.connectionP2pLabel = 'P2P connected',
    this.connectionRelayLabel = 'Using server relay',
    this.allowServerRelay = true,
    this.deviceManagementService,
    this.currentDeviceId,
    this.deviceLabels = const {},
    this.connectionActiveLabel = 'Connection active',
    this.connectionWaitingLabel = 'Waiting for connection choice',
    this.connectionFailedLabel = 'Connection failed',
  });

  final DirectMessageService service;
  final int friendId;
  final String friendName;
  final int currentUserId;
  final RetryableDmService? retryService;
  final ManualP2pDmService? manualP2pService;
  final RelayFallbackDmService? relayFallbackService;
  final DirectMessageSyncService? syncService;
  final ubs.DmStrings strings;
  final void Function(int? friendId)? onActiveConversationChanged;
  final String connectionConnectingLabel;
  final String connectionP2pLabel;
  final String connectionRelayLabel;
  final bool allowServerRelay;
  final ChatDeviceManagementService? deviceManagementService;
  final String? currentDeviceId;
  final Map<String, String> deviceLabels;
  final String connectionActiveLabel;
  final String connectionWaitingLabel;
  final String connectionFailedLabel;

  @override
  State<EditableDmPage> createState() => _EditableDmPageState();
}

class _EditableDmPageState extends State<EditableDmPage> {
  final _messages = <DirectMessage>[];
  final _textController = TextEditingController();
  final _scrollController = ScrollController();
  StreamSubscription<DirectMessage>? _subscription;
  StreamSubscription<void>? _connectionStateSubscription;
  Timer? _p2pRetryTimer;
  Timer? _deviceHeartbeatTimer;
  int _p2pRetryAttempt = 0;
  bool _deviceRegistrationInFlight = false;
  bool _loading = true;
  bool _loadingOlderHistory = false;
  bool _hasMoreHistory = false;
  bool _syncing = false;
  bool _uploading = false;
  bool _downloading = false;
  bool _sendingMessage = false;
  bool _retryingFailedDraft = false;
  bool _connecting = true;
  bool _waitingForConnectionChoice = false;
  bool _connectionFailed = false;
  bool _connectionChoiceDialogOpen = false;
  String? _error;
  MessageHistoryCursor? _nextHistoryCursor;

  ubs.DmStrings get _s => widget.strings;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_handleHistoryScroll);
    widget.onActiveConversationChanged?.call(widget.friendId);
    _connectionStateSubscription = widget
        .relayFallbackService
        ?.connectionStateChanges
        .listen(_handleConnectionStateChange);
    unawaited(_loadHistory());
    _startDeviceHeartbeat();
    unawaited(_connectToConversation());
    _subscription = widget.service.directMessageStream.listen(_receiveMessage);
  }

  Future<void> _connectToConversation() async {
    try {
      await widget.service.connectToDm(
        widget.currentUserId,
        widget.friendId,
        isCaller: isDirectMessageCaller(
          selfId: widget.currentUserId,
          friendId: widget.friendId,
        ),
      );
      if (!mounted) return;
      setState(() {
        _connecting = false;
        _waitingForConnectionChoice = false;
        _connectionFailed = false;
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _connecting = false;
          _waitingForConnectionChoice =
              widget.relayFallbackService?.relayFallbackChoiceRequired ?? false;
          _connectionFailed = !_waitingForConnectionChoice;
        });
      }
      await _showRelayFallbackChoiceIfRequired();
    }
  }

  Future<void> _registerCurrentDevice() async {
    final service = widget.deviceManagementService;
    final deviceId = widget.currentDeviceId;
    if (service == null ||
        deviceId == null ||
        deviceId.isEmpty ||
        _deviceRegistrationInFlight) {
      return;
    }
    _deviceRegistrationInFlight = true;
    try {
      await service.registerCurrentDevice(deviceId);
    } catch (_) {
      // Registration is retried on the next chat open; local and P2P chat
      // remain available while the account is offline.
    } finally {
      _deviceRegistrationInFlight = false;
    }
  }

  void _startDeviceHeartbeat() {
    unawaited(_registerCurrentDevice());
    _deviceHeartbeatTimer = Timer.periodic(
      const Duration(minutes: 5),
      (_) => unawaited(_registerCurrentDevice()),
    );
  }

  Future<void> _manageChatDevices() async {
    final service = widget.deviceManagementService;
    final currentDeviceId = widget.currentDeviceId;
    if (service == null || currentDeviceId == null) return;
    List<ChatDeviceInfo> devices;
    try {
      await service.registerCurrentDevice(currentDeviceId);
      devices = await service.loadActiveDevices();
    } catch (error) {
      if (mounted) {
        _showSnack('${_deviceText('Could not load chat devices.')} $error');
      }
      return;
    }
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(_deviceText('Chat devices')),
          content: SizedBox(
            width: 420,
            child: devices.isEmpty
                ? Text(_deviceText('No active devices'))
                : ListView.separated(
                    shrinkWrap: true,
                    itemCount: devices.length,
                    separatorBuilder: (_, _) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final device = devices[index];
                      final isCurrent = device.deviceId == currentDeviceId;
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(
                          isCurrent ? Icons.phone_iphone : Icons.devices_other,
                        ),
                        title: Text(
                          isCurrent
                              ? _deviceText('This device')
                              : '${_deviceText('Device')} ${device.deviceId.substring(0, device.deviceId.length > 8 ? 8 : device.deviceId.length)}',
                        ),
                        subtitle: Text(
                          _lastSeenLabel(device.lastSeenAt),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        trailing: isCurrent
                            ? Chip(label: Text(_deviceText('Current')))
                            : IconButton(
                                tooltip: _deviceText('Revoke relay access'),
                                icon: const Icon(Icons.link_off),
                                onPressed: () async {
                                  final confirmed = await showDialog<bool>(
                                    context: context,
                                    builder: (context) => AlertDialog(
                                      title: Text(
                                        _deviceText('Revoke this device?'),
                                      ),
                                      content: Text(
                                        _deviceText(
                                          'It will stop receiving relay messages. This does not erase chat history already stored on that device.',
                                        ),
                                      ),
                                      actions: [
                                        TextButton(
                                          onPressed: () =>
                                              Navigator.pop(context, false),
                                          child: Text(_deviceText('Cancel')),
                                        ),
                                        FilledButton(
                                          onPressed: () =>
                                              Navigator.pop(context, true),
                                          child: Text(_deviceText('Revoke')),
                                        ),
                                      ],
                                    ),
                                  );
                                  if (confirmed != true) return;
                                  try {
                                    await service.revokeDevice(device.deviceId);
                                    devices = await service.loadActiveDevices();
                                    if (dialogContext.mounted) {
                                      setDialogState(() {});
                                    }
                                  } catch (error) {
                                    if (dialogContext.mounted) {
                                      _showSnack(
                                        '${_deviceText('Could not revoke device.')} $error',
                                      );
                                    }
                                  }
                                },
                              ),
                      );
                    },
                  ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text(_deviceText('Done')),
            ),
          ],
        ),
      ),
    );
  }

  String _lastSeenLabel(DateTime? lastSeenAt) {
    if (lastSeenAt == null) return _deviceText('Last active time unavailable');
    return '${_deviceText('Last active')} ${lastSeenAt.toLocal().toString().substring(0, 16)}';
  }

  String _deviceText(String key) => widget.deviceLabels[key] ?? key;

  @override
  void dispose() {
    _subscription?.cancel();
    _connectionStateSubscription?.cancel();
    _p2pRetryTimer?.cancel();
    _deviceHeartbeatTimer?.cancel();
    widget.onActiveConversationChanged?.call(null);
    widget.service.disconnect();
    _textController.dispose();
    _scrollController.removeListener(_handleHistoryScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _handleConnectionStateChange(void _) {
    final relayService = widget.relayFallbackService;
    if (!mounted || relayService == null) return;
    if (relayService.p2pActive) {
      _p2pRetryTimer?.cancel();
      _p2pRetryTimer = null;
      _p2pRetryAttempt = 0;
      setState(() {
        _connecting = false;
        _waitingForConnectionChoice = false;
        _connectionFailed = false;
      });
      if (_connectionChoiceDialogOpen) {
        unawaited(Navigator.of(context, rootNavigator: true).maybePop(false));
      }
      return;
    }
    if (relayService.relayFallbackChoiceRequired) {
      final shouldPrompt =
          !_waitingForConnectionChoice && !_connectionChoiceDialogOpen;
      setState(() {
        _connecting = false;
        _waitingForConnectionChoice = true;
        _connectionFailed = false;
      });
      if (shouldPrompt) unawaited(_showRelayFallbackChoiceIfRequired());
      return;
    }
    setState(() {});
  }

  void _receiveMessage(DirectMessage message) {
    if (!mounted) return;
    setState(() {
      final index = _messages.indexWhere((item) => item.id == message.id);
      if (index >= 0) {
        _messages[index] = message;
      } else {
        _messages.add(message);
      }
    });
    if (message.authorId == widget.friendId.toString()) {
      unawaited(widget.service.markProjectedMessageRead(message.id));
    }
    _scrollToBottom();
  }

  Future<void> _loadHistory() async {
    try {
      final page = await widget.service.loadConversationPage(
        widget.currentUserId,
        widget.friendId,
      );
      if (!mounted) return;
      setState(() {
        _messages
          ..clear()
          ..addAll(page.messages);
        _loading = false;
        _hasMoreHistory = page.hasMore;
        _nextHistoryCursor = page.nextCursor;
      });
      _markIncomingMessagesRead(page.messages);
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.toString();
        _loading = false;
      });
    }
  }

  void _handleHistoryScroll() {
    if (!_scrollController.hasClients ||
        _loading ||
        _loadingOlderHistory ||
        !_hasMoreHistory ||
        _nextHistoryCursor == null ||
        _messages.isEmpty) {
      return;
    }
    if (_scrollController.position.pixels <= 120) {
      unawaited(_loadOlderHistory());
    }
  }

  Future<void> _loadOlderHistory() async {
    if (_loadingOlderHistory || !_hasMoreHistory) return;
    final cursor = _nextHistoryCursor;
    if (cursor == null || !_scrollController.hasClients) return;
    final position = _scrollController.position;
    final previousOffset = position.pixels;
    final previousMaxExtent = position.maxScrollExtent;
    setState(() => _loadingOlderHistory = true);

    try {
      final page = await widget.service.loadConversationPage(
        widget.currentUserId,
        widget.friendId,
        before: cursor,
      );
      if (!mounted) return;
      final canContinue = page.hasMore && page.nextCursor != cursor;
      setState(() {
        final byId = {for (final message in _messages) message.id: message};
        for (final message in page.messages) {
          byId[message.id] = message;
        }
        _messages
          ..clear()
          ..addAll(byId.values)
          ..sort(_compareMessages);
        _hasMoreHistory = canContinue;
        _nextHistoryCursor = canContinue ? page.nextCursor : null;
        _loadingOlderHistory = false;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!_scrollController.hasClients) return;
        final nextPosition = _scrollController.position;
        final addedExtent = nextPosition.maxScrollExtent - previousMaxExtent;
        final preservedOffset = (previousOffset + addedExtent)
            .clamp(0.0, nextPosition.maxScrollExtent)
            .toDouble();
        _scrollController.jumpTo(preservedOffset);
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadingOlderHistory = false);
      _showSnack(_s.downloadFailed);
    }
  }

  static int _compareMessages(DirectMessage left, DirectMessage right) {
    final byTime = left.createdAt.compareTo(right.createdAt);
    return byTime != 0 ? byTime : left.id.compareTo(right.id);
  }

  Future<void> _syncFromServer() async {
    setState(() => _syncing = true);
    try {
      final history = await widget.service.refreshConversation(
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
    final service = widget.syncService;
    if (service == null) return;
    setState(() => _uploading = true);
    try {
      await service.uploadSyncData(widget.currentUserId, widget.friendId);
      if (mounted) _showSnack(_s.uploadSuccess);
    } catch (_) {
      if (mounted) _showSnack(_s.uploadFailed);
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<void> _downloadSync() async {
    final service = widget.syncService;
    if (service == null) return;
    setState(() => _downloading = true);
    try {
      await service.downloadAndMergeSyncData(widget.friendId);
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

  void _markIncomingMessagesRead(Iterable<DirectMessage> messages) {
    for (final message in messages) {
      if (message.authorId == widget.friendId.toString()) {
        unawaited(widget.service.markProjectedMessageRead(message.id));
      }
    }
  }

  Future<void> _showManualP2pDialog() async {
    final service = widget.manualP2pService;
    if (service == null || !service.enabled) return;

    final low = widget.currentUserId < widget.friendId
        ? widget.currentUserId
        : widget.friendId;
    final high = widget.currentUserId < widget.friendId
        ? widget.friendId
        : widget.currentUserId;
    final sessionId = 'dm:$low:$high';
    final senderDeviceId =
        service.localDeviceId ?? 'user:${widget.currentUserId}';
    final inputController = TextEditingController();
    String exported = '';
    bool prepared = false;
    bool imported = false;
    final isCaller = isDirectMessageCaller(
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
                    'Copy your connection bundle and send it to your friend. Paste their bundle here. The bundle contains connection data only.',
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
                            : () async {
                                try {
                                  await service.importBundle(
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
                                  await service.prepare(isCaller: isCaller);
                                  final bundle = await service.exportBundle(
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
                                ? () async {
                                    try {
                                      final bundle = await service.exportBundle(
                                        sessionId: sessionId,
                                        senderDeviceId: senderDeviceId,
                                      );
                                      if (bundle.isEmpty) return;
                                      setDialogState(() => exported = bundle);
                                    } catch (error) {
                                      _showSnack('Refresh failed: $error');
                                    }
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
                        await service.complete();
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
    if (_sendingMessage) return;
    final text = _textController.text.trim();
    if (text.isEmpty) return;
    setState(() => _sendingMessage = true);
    _textController.clear();
    try {
      final retryService = widget.retryService;
      if (_retryingFailedDraft && retryService != null) {
        await retryService.retryPendingMessage(widget.friendId, text);
      } else {
        await widget.service.sendText(widget.friendId, text);
      }
      if (mounted) setState(() => _retryingFailedDraft = false);
    } catch (error) {
      if (mounted) {
        _textController.value = TextEditingValue(
          text: text,
          selection: TextSelection.collapsed(offset: text.length),
        );
        setState(() => _retryingFailedDraft = widget.retryService != null);
        _showSnack('Message send failed. Draft preserved. $error');
        unawaited(_showRelayFallbackChoiceIfRequired());
      }
    } finally {
      if (mounted) setState(() => _sendingMessage = false);
    }
  }

  Future<void> _showRelayFallbackChoiceIfRequired() async {
    final relayService = widget.relayFallbackService;
    if (!mounted ||
        relayService?.relayFallbackChoiceRequired != true ||
        _connectionChoiceDialogOpen) {
      return;
    }
    _connectionChoiceDialogOpen = true;
    setState(() {
      _connecting = false;
      _waitingForConnectionChoice = true;
      _connectionFailed = false;
    });
    final bool? useRelay;
    try {
      useRelay = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Connection unavailable'),
          content: Text(
            widget.allowServerRelay
                ? 'Your message stays on this device. Use or retry the server relay? The relay can process message content.'
                : 'Your message stays on this device. Server relay is unavailable until end-to-end encryption is ready. Keep waiting and retry P2P.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Keep waiting'),
            ),
            if (widget.allowServerRelay)
              FilledButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                child: const Text('Use server relay'),
              ),
          ],
        ),
      );
    } finally {
      _connectionChoiceDialogOpen = false;
    }
    if (!mounted) return;
    if (useRelay != true) {
      _startP2PRetryLoop();
      return;
    }
    _p2pRetryTimer?.cancel();
    _p2pRetryTimer = null;
    try {
      setState(() {
        _connecting = true;
        _waitingForConnectionChoice = false;
      });
      await relayService!.useRelayFallback();
      if (mounted) {
        setState(() {
          _connecting = false;
          _waitingForConnectionChoice = false;
          _connectionFailed = false;
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _connecting = false;
          _waitingForConnectionChoice = true;
        });
        _showSnack('Relay connection failed. Message kept locally. $error');
        unawaited(_showRelayFallbackChoiceIfRequired());
      }
    }
  }

  void _startP2PRetryLoop() {
    final relayService = widget.relayFallbackService;
    if (relayService == null || _p2pRetryTimer != null) return;
    _p2pRetryAttempt = 0;
    unawaited(_retryP2PConnection());
  }

  void _scheduleP2PRetry() {
    final relayService = widget.relayFallbackService;
    if (!mounted || relayService == null || _p2pRetryTimer != null) return;
    final delay = P2PRetryBackoff.delay(
      baseDelay: relayService.p2pRetryInterval,
      failedAttempts: _p2pRetryAttempt,
    );
    _p2pRetryAttempt++;
    _p2pRetryTimer = Timer(delay, () {
      _p2pRetryTimer = null;
      unawaited(_retryP2PConnection());
    });
  }

  Future<void> _retryP2PConnection() async {
    final relayService = widget.relayFallbackService;
    if (!mounted || relayService == null || _connecting) return;
    setState(() => _connecting = true);
    var connected = false;
    try {
      connected = await relayService.retryP2PConnection();
    } catch (_) {
      connected = false;
    }
    if (!mounted) return;
    if (connected) {
      _p2pRetryTimer?.cancel();
      _p2pRetryTimer = null;
      _p2pRetryAttempt = 0;
      setState(() {
        _connecting = false;
        _waitingForConnectionChoice = false;
        _connectionFailed = false;
      });
    } else {
      setState(() {
        _connecting = false;
        _waitingForConnectionChoice = true;
        _connectionFailed = false;
      });
      _scheduleP2PRetry();
    }
  }

  Future<void> _showMessageActions(DirectMessage message) async {
    if (message.authorId != widget.currentUserId.toString() ||
        message.isRecalled) {
      return;
    }
    final action = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
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
      try {
        await widget.service.recallProjectedMessage(message.id);
      } catch (error) {
        if (mounted) {
          _showSnack('Recall was not delivered to the other device: $error');
          unawaited(_showRelayFallbackChoiceIfRequired());
        }
      }
    }
  }

  Future<void> _editMessage(DirectMessage message) async {
    final text = await showDialog<String>(
      context: context,
      builder: (context) =>
          _EditMessageDialog(initialText: message.text, cancelLabel: _s.cancel),
    );
    if (!mounted || text == null || text.isEmpty) return;
    try {
      await widget.service.editProjectedMessage(message.id, text);
    } catch (error) {
      if (mounted) {
        _showSnack('Edit was not delivered to the other device: $error');
        unawaited(_showRelayFallbackChoiceIfRequired());
      }
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
        title: Row(
          children: [
            Flexible(
              child: Text(widget.friendName, overflow: TextOverflow.ellipsis),
            ),
            if (widget.relayFallbackService case final relayService?) ...[
              const SizedBox(width: 8),
              Tooltip(
                message: _connectionStatusLabel(relayService),
                child: Icon(
                  _connectionStatusIcon(relayService),
                  color: _connectionStatusColor(context, relayService),
                  size: 19,
                ),
              ),
            ],
          ],
        ),
        actions: [
          if (widget.deviceManagementService != null)
            IconButton(
              tooltip: _deviceText('Chat devices'),
              onPressed: _manageChatDevices,
              icon: const Icon(Icons.devices_other),
            ),
          if (widget.syncService != null) ...[
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
          ],
          IconButton(
            tooltip: _s.syncTooltip,
            onPressed: _syncing ? null : _syncFromServer,
            icon: const Icon(Icons.sync),
          ),
          if (widget.manualP2pService?.enabled == true)
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

  String _connectionStatusLabel(RelayFallbackDmService service) {
    if (_connecting) return widget.connectionConnectingLabel;
    if (_waitingForConnectionChoice || service.relayFallbackChoiceRequired) {
      return widget.connectionWaitingLabel;
    }
    if (_connectionFailed) return widget.connectionFailedLabel;
    if (service.relayFallbackActive) return widget.connectionRelayLabel;
    if (service.p2pActive) return widget.connectionP2pLabel;
    return widget.connectionActiveLabel;
  }

  IconData _connectionStatusIcon(RelayFallbackDmService service) {
    if (_connecting) return Icons.sync;
    if (_waitingForConnectionChoice || service.relayFallbackChoiceRequired) {
      return Icons.wifi_off;
    }
    if (_connectionFailed) return Icons.error_outline;
    if (service.relayFallbackActive) return Icons.cloud_done;
    if (service.p2pActive) return Icons.link;
    return Icons.cloud_done;
  }

  Color _connectionStatusColor(
    BuildContext context,
    RelayFallbackDmService service,
  ) {
    if (_waitingForConnectionChoice ||
        service.relayFallbackChoiceRequired ||
        _connectionFailed) {
      return Theme.of(context).colorScheme.error;
    }
    return Theme.of(context).colorScheme.primary;
  }

  Widget _buildMessageList() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) return Center(child: Text(_error!));
    if (_messages.isEmpty) return Center(child: Text(_s.noMessages));
    return Stack(
      children: [
        ListView.builder(
          controller: _scrollController,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          itemCount: _messages.length,
          itemBuilder: (context, index) => _buildBubble(_messages[index]),
        ),
        if (_loadingOlderHistory)
          const Positioned(
            top: 8,
            left: 0,
            right: 0,
            child: Center(
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildBubble(DirectMessage message) {
    final isMine = message.authorId == widget.currentUserId.toString();
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
              onPressed: _sendingMessage ? null : _sendMessage,
              icon: _sendingMessage
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.send),
            ),
          ],
        ),
      ),
    );
  }
}

class _EditMessageDialog extends StatefulWidget {
  const _EditMessageDialog({
    required this.initialText,
    required this.cancelLabel,
  });

  final String initialText;
  final String cancelLabel;

  @override
  State<_EditMessageDialog> createState() => _EditMessageDialogState();
}

class _EditMessageDialogState extends State<_EditMessageDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialText);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Edit message'),
    content: TextField(
      controller: _controller,
      autofocus: true,
      maxLines: 4,
      textInputAction: TextInputAction.done,
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: Text(widget.cancelLabel),
      ),
      FilledButton(
        onPressed: () => Navigator.pop(context, _controller.text.trim()),
        child: const Text('Save'),
      ),
    ],
  );
}
