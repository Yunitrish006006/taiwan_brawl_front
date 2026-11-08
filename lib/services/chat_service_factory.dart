import 'package:taiwan_brawl_messaging/taiwan_brawl_messaging.dart';

import 'chat_service.dart';
import 'direct_message_session.dart';
import 'legacy_chat_delivery_adapter.dart';
import 'legacy_chat_history_adapter.dart';
import 'legacy_chat_remote_source.dart';
import 'legacy_chat_sync_snapshot_adapter.dart';
import 'legacy_chat_store.dart';
import 'messaging_core_service.dart';

/// Composition-root factory for the legacy-compatible chat application API.
///
/// Pages receive a ready application service and do not assemble storage,
/// identity, signaling, or transport adapters themselves.
class ChatServiceFactory implements DirectMessageSessionFactory {
  ChatServiceFactory({
    required this.messagingCore,
    required this.legacyDeliveryStore,
    required this.legacyHistoryStore,
    required this.legacySnapshotStore,
    required this.legacyDeliveryRemoteSource,
    required this.legacyHistoryRemoteSource,
    required this.legacySnapshotRemoteSource,
    required this.transportFactory,
    this.authenticator,
    this.remoteAuthenticator,
    this.p2pAuthenticator,
    this.deviceId,
    this.manualSignalingFactory,
    this.manualTransportFactory,
  });

  final MessagingCoreService messagingCore;
  final LegacyChatDeliveryStore legacyDeliveryStore;
  final LegacyChatHistoryStore legacyHistoryStore;
  final LegacyChatSnapshotStore legacySnapshotStore;
  final LegacyChatDeliveryRemoteSource legacyDeliveryRemoteSource;
  final LegacyChatHistoryRemoteSource legacyHistoryRemoteSource;
  final LegacyChatSnapshotRemoteSource legacySnapshotRemoteSource;
  final EventAuthenticator? authenticator;
  final EventAuthenticator? remoteAuthenticator;
  final EventAuthenticator? p2pAuthenticator;
  final String? deviceId;
  final DirectMessageTransportFactory transportFactory;
  final PeerSignalingChannel Function()? manualSignalingFactory;
  final ManualP2PTransportFactory? manualTransportFactory;

  @override
  ChatService create() {
    return ChatService(
      messagingCore: messagingCore,
      legacyDelivery: LegacyChatDeliveryAdapter(
        localRepository: legacyDeliveryStore,
        remoteSource: legacyDeliveryRemoteSource,
      ),
      legacyHistory: LegacyChatHistoryAdapter(
        messagingCore: messagingCore,
        localRepository: legacyHistoryStore,
        remoteSource: legacyHistoryRemoteSource,
        remoteAuthenticator: remoteAuthenticator,
      ),
      legacySyncSnapshots: LegacyChatSyncSnapshotAdapter(
        messagingCore: messagingCore,
        localRepository: legacySnapshotStore,
        remoteSource: legacySnapshotRemoteSource,
      ),
      authenticator: authenticator,
      remoteAuthenticator: remoteAuthenticator,
      p2pAuthenticator: p2pAuthenticator,
      deviceId: deviceId,
      transportFactory: transportFactory,
      manualSignaling: manualSignalingFactory?.call(),
      manualTransportFactory: manualTransportFactory,
    );
  }
}
