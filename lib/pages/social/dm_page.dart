import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:user_basic_system/user_basic_system.dart' as ubs;

import '../../services/chat_service.dart';
import '../../services/locale_provider.dart';
import '../../services/notification_service.dart';

/// Thin wrapper that supplies [ChatService], locale strings and
/// [NotificationService] callbacks to the package's [DmPage].
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
  late NotificationService _notificationService;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _notificationService = context.read<NotificationService>();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.watch<LocaleProvider>().translation;
    return ubs.DmPage(
      service: widget.chatService,
      friendId: widget.friendId,
      friendName: widget.friendName,
      currentUserId: widget.currentUserId,
      strings: ubs.DmStrings.fromMap(t),
      onActiveConversationChanged:
          _notificationService.setActiveConversation,
    );
  }
}
