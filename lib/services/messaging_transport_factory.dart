import 'package:taiwan_brawl_messaging/taiwan_brawl_messaging.dart';

import 'api_client.dart';
import 'fallback_message_transport.dart';
import 'p2p_message_transport.dart';
import 'server_message_transport.dart';
import 'signaling_service.dart';

typedef P2PSignalingFactory =
    PeerSignalingChannel Function({required int selfId, required int friendId});

typedef MessageSyncCursorStoreFactory =
    MessageSyncCursorStore Function({
      required int selfId,
      required int friendId,
    });

P2PSignalingFactory _hostedSignalingFactory(ApiClient apiClient) {
  return ({required selfId, required friendId}) => SignalingService(apiClient);
}

/// Application-level transport selection.
///
/// Pages depend on this factory rather than importing HTTP, WebRTC, or
/// signaling adapters. The same event repository and command layer can
/// therefore be used by a different product entrypoint or test harness.
class MessagingTransportFactory {
  MessagingTransportFactory(
    this._apiClient, {
    this.p2pEnabled = false,
    P2PSignalingFactory? signalingFactory,
    this.syncCursorStoreFactory,
    this.p2pIceConfiguration = P2PMessageTransport.defaultIceConfiguration,
  }) : _signalingFactory =
           signalingFactory ?? _hostedSignalingFactory(_apiClient);

  /// Selects exactly one deterministic offerer for a peer pair.
  static bool isCaller({required int selfId, required int friendId}) {
    return selfId < friendId;
  }

  final ApiClient _apiClient;
  final bool p2pEnabled;
  final MessageSyncCursorStoreFactory? syncCursorStoreFactory;
  final Map<String, dynamic> p2pIceConfiguration;
  final P2PSignalingFactory _signalingFactory;

  MessageTransport create({
    required int selfId,
    required int friendId,
    required bool isCaller,
  }) {
    final server = ServerMessageTransport(
      apiClient: _apiClient,
      selfId: selfId,
      friendId: friendId,
      syncCursorStore: syncCursorStoreFactory?.call(
        selfId: selfId,
        friendId: friendId,
      ),
    );
    if (!p2pEnabled) return server;

    return FallbackMessageTransport(
      primary: P2PMessageTransport(
        friendId: friendId,
        signalingService: _signalingFactory(selfId: selfId, friendId: friendId),
        isCaller: isCaller,
        iceConfiguration: p2pIceConfiguration,
      ),
      fallback: server,
    );
  }

  P2PMessageTransport createP2P({
    required int friendId,
    required PeerSignalingChannel signalingService,
    required bool isCaller,
    required Map<String, dynamic> iceConfiguration,
  }) {
    return P2PMessageTransport(
      friendId: friendId,
      signalingService: signalingService,
      isCaller: isCaller,
      iceConfiguration: iceConfiguration,
    );
  }
}
