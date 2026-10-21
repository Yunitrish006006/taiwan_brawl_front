import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:taiwan_brawl_messaging/taiwan_brawl_messaging.dart';

import '../config/app_configuration.dart';
import '../services/platform_credential_store.dart';
import '../services/preview_runtime.dart';

class PreviewModeBanner extends StatelessWidget {
  const PreviewModeBanner({super.key});

  @override
  Widget build(BuildContext context) {
    if (!context.read<AppConfiguration>().previewMode) {
      return const SizedBox.shrink();
    }
    return Container(
      width: double.infinity,
      color: Theme.of(context).colorScheme.secondaryContainer,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: const Row(
        children: [
          Icon(Icons.offline_bolt_outlined, size: 18),
          SizedBox(width: 8),
          Expanded(child: Text('本地預覽模式：資料保存在此瀏覽器，不會連線到伺服器。')),
        ],
      ),
    );
  }
}

class PreviewResetButton extends StatelessWidget {
  const PreviewResetButton({super.key});

  Future<void> _reset(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('重置本地預覽？'),
        content: const Text('會清除本地訊息與舊版聊天資料，重新整理後會重新建立示範資料。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('重置'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    await resetPreviewStorage(context.read<PlatformCredentialStore>());
    if (!context.mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('已清除本地資料，請重新整理頁面以重新建立示範資料。')));
  }

  @override
  Widget build(BuildContext context) {
    if (!context.read<AppConfiguration>().previewMode) {
      return const SizedBox.shrink();
    }
    return IconButton(
      onPressed: () => _reset(context),
      icon: const Icon(Icons.restart_alt),
      tooltip: '重置本地預覽',
    );
  }
}

/// Same-page two-peer proof using the shared in-memory transport.
/// WebRTC remains a separate runtime capability; this widget proves the
/// transport-neutral event and sync contracts without a server.
class PreviewP2pDemo extends StatefulWidget {
  const PreviewP2pDemo({super.key});

  @override
  State<PreviewP2pDemo> createState() => _PreviewP2pDemoState();
}

class _PreviewP2pDemoState extends State<PreviewP2pDemo> {
  late final MessageRepository _leftRepository;
  late final MessageRepository _rightRepository;
  late final InMemoryMessageTransport _leftTransport;
  late final InMemoryMessageTransport _rightTransport;
  late final MessageSyncEngine _leftSync;
  late final MessageSyncEngine _rightSync;
  bool _ready = false;
  String? _lastMessage;

  @override
  void initState() {
    super.initState();
    _leftRepository = MessageRepository();
    _rightRepository = MessageRepository();
    final transports = InMemoryMessageTransport.pair();
    _leftTransport = transports.$1;
    _rightTransport = transports.$2;
    _leftSync = MessageSyncEngine(
      repository: _leftRepository,
      transport: _leftTransport,
    );
    _rightSync = MessageSyncEngine(
      repository: _rightRepository,
      transport: _rightTransport,
    );
    unawaited(_start());
  }

  Future<void> _start() async {
    await Future.wait([_leftSync.start(), _rightSync.start()]);
    if (mounted) setState(() => _ready = true);
  }

  Future<void> _send() async {
    if (!_ready) return;
    final event = await MessageCommandService(
      repository: _leftRepository,
      actorId: 'preview-left',
      conversationId: 'preview-p2p',
    ).create('左側 peer 的事件已同步到右側');
    await _leftSync.syncNow();
    await Future<void>.delayed(Duration.zero);
    if (!mounted) return;
    final projection = _rightRepository.projectionFor(event.messageId);
    setState(() => _lastMessage = projection?.visibleBody);
  }

  @override
  void dispose() {
    unawaited(_leftSync.stop());
    unawaited(_rightSync.stop());
    unawaited(_leftRepository.dispose());
    unawaited(_rightRepository.dispose());
    unawaited(_leftTransport.dispose());
    unawaited(_rightTransport.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!context.read<AppConfiguration>().previewMode) {
      return const SizedBox.shrink();
    }
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'P2P 雙 peer 本地示範',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 6),
            const Text('使用共享的 InMemoryMessageTransport，模擬兩個沒有伺服器的裝置同步事件。'),
            const SizedBox(height: 12),
            Row(
              children: [
                Chip(label: Text(_ready ? '兩端已連線' : '初始化中')),
                const SizedBox(width: 8),
                FilledButton.icon(
                  onPressed: _ready ? _send : null,
                  icon: const Icon(Icons.sync),
                  label: const Text('送出測試事件'),
                ),
              ],
            ),
            if (_lastMessage != null) ...[
              const SizedBox(height: 8),
              Text('右側 peer 收到：$_lastMessage'),
            ],
          ],
        ),
      ),
    );
  }
}
