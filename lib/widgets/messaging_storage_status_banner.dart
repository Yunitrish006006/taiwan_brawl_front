import 'package:flutter/material.dart';

import '../services/messaging_core_service.dart';

/// Makes a non-durable messaging runtime visible instead of silently letting
/// the user assume that messages will survive an app restart.
class MessagingStorageStatusBanner extends StatelessWidget {
  const MessagingStorageStatusBanner({super.key, required this.status});

  final MessagingStorageStatus status;

  @override
  Widget build(BuildContext context) {
    if (status.mode != MessagingStorageMode.degraded) {
      return const SizedBox.shrink();
    }

    return MaterialBanner(
      leading: const Icon(Icons.warning_amber_rounded),
      content: Text(
        '訊息目前只保存在暫存記憶體中，重啟 App 前請先修復本地儲存。'
        '${status.failureDescription == null ? '' : '\n${status.failureDescription}'}',
      ),
      actions: const [SizedBox.shrink()],
    );
  }
}
