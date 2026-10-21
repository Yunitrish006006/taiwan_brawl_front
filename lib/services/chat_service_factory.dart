import 'package:taiwan_brawl_messaging/taiwan_brawl_messaging.dart';

import 'api_client.dart';
import 'chat_service.dart';
import 'legacy_chat_remote_source.dart';
import 'legacy_chat_store.dart';
import 'messaging_core_service.dart';
import 'p2p_message_transport.dart';

/// Composition-root factory for the legacy-compatible chat application API.
///
/// Pages receive a ready application service and do not assemble storage,
/// identity, signaling, or transport adapters themselves.
class ChatServiceFactory {
  ChatServiceFactory({
    required ApiClient apiClient,
    required this.messagingCore,
    this.localRepository,
    this.remoteSource,
    this.authenticator,
    this.remoteAuthenticator,
    this.deviceId,
    this.transportFactory,
    this.manualSignaling,
    this.manualTransportFactory,
    this.p2pIceConfiguration = P2PMessageTransport.defaultIceConfiguration,
  }) : _apiClient = apiClient;

  final ApiClient _apiClient;
  final MessagingCoreService messagingCore;
  final LegacyChatStore? localRepository;
  final LegacyChatRemoteSource? remoteSource;
  final EventAuthenticator? authenticator;
  final EventAuthenticator? remoteAuthenticator;
  final String? deviceId;
  final ChatMessageTransportFactory? transportFactory;
  final PeerSignalingChannel? manualSignaling;
  final P2PMessageTransportFactory? manualTransportFactory;
  final Map<String, dynamic> p2pIceConfiguration;

  ChatService create() {
    return ChatService(
      _apiClient,
      messagingCore: messagingCore,
      localRepository: localRepository,
      remoteSource: remoteSource,
      authenticator: authenticator,
      remoteAuthenticator: remoteAuthenticator,
      deviceId: deviceId,
      transportFactory: transportFactory,
      manualSignaling: manualSignaling,
      manualTransportFactory: manualTransportFactory,
      p2pIceConfiguration: p2pIceConfiguration,
    );
  }
}
