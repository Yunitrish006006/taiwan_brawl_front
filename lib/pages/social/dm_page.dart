import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:taiwan_brawl_messaging/taiwan_brawl_messaging.dart';
import 'package:user_basic_system/user_basic_system.dart' as ubs;

import '../../services/direct_message_session.dart';
import '../../services/direct_message_sync_service.dart';
import '../../services/api_client.dart';
import '../../services/chat_device_management_service.dart';
import '../../services/locale_provider.dart';
import '../../services/manual_p2p_dm_service.dart';
import '../../services/notification_service.dart';
import '../../services/retryable_dm_service.dart';
import '../../services/relay_fallback_dm_service.dart';
import 'editable_dm_page.dart';

/// Thin wrapper that supplies DM application ports, locale strings and
/// [NotificationService] callbacks to the local editable DM page.
class DmPage extends StatefulWidget {
  const DmPage({
    super.key,
    required this.service,
    this.retryService,
    this.manualP2pService,
    this.relayFallbackService,
    this.syncService,
    required this.friendId,
    required this.friendName,
    required this.currentUserId,
  });

  final DirectMessageSession service;
  final RetryableDmService? retryService;
  final ManualP2pDmService? manualP2pService;
  final RelayFallbackDmService? relayFallbackService;
  final DirectMessageSyncService? syncService;
  final int friendId;
  final String friendName;
  final int currentUserId;

  @override
  State<DmPage> createState() => _DmPageState();
}

class _DmPageState extends State<DmPage> {
  late NotificationService _notificationService;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _notificationService = context.read<NotificationService>();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.watch<LocaleProvider>().translation;
    final identity = context.read<DeviceIdentity?>();
    return EditableDmPage(
      service: widget.service,
      retryService: widget.retryService,
      manualP2pService: widget.manualP2pService,
      relayFallbackService: widget.relayFallbackService,
      syncService: widget.syncService,
      friendId: widget.friendId,
      friendName: widget.friendName,
      currentUserId: widget.currentUserId,
      currentDeviceId: identity?.deviceId,
      deviceLabels: {
        for (final label in const [
          'Chat devices',
          'No active devices',
          'This device',
          'Device',
          'Current',
          'Last active',
          'Last active time unavailable',
          'Revoke relay access',
          'Revoke this device?',
          'It will stop receiving relay messages. This does not erase chat history already stored on that device.',
          'Cancel',
          'Revoke',
          'Done',
          'Could not revoke device.',
          'Could not load chat devices.',
        ])
          label: t[label] ?? label,
      },
      deviceManagementService: identity == null
          ? null
          : ServerChatDeviceManagementService(context.read<ApiClient>()),
      strings: ubs.DmStrings.fromMap(t),
      connectionConnectingLabel: t['Connecting P2P'] ?? 'Connecting P2P',
      connectionP2pLabel: t['P2P connected'] ?? 'P2P connected',
      connectionRelayLabel: t['Using server relay'] ?? 'Using server relay',
      allowServerRelay: false,
      connectionActiveLabel: t['Connection active'] ?? 'Connection active',
      connectionWaitingLabel:
          t['Waiting for connection choice'] ?? 'Waiting for connection choice',
      connectionFailedLabel: t['Connection failed'] ?? 'Connection failed',
      onActiveConversationChanged: _notificationService.setActiveConversation,
    );
  }

  @override
  void dispose() {
    widget.service.dispose();
    super.dispose();
  }
}
