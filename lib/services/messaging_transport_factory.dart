import 'dart:async';

import 'package:taiwan_brawl_messaging/taiwan_brawl_messaging.dart';
import 'conversation_key_agreement.dart';
import 'conversation_key_exchange_coordinator.dart';

import 'api_client.dart';
import 'dm_peer_role.dart';
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

typedef ConversationEncryptorFactory =
    ConversationEncryptor? Function({
      required int selfId,
      required int friendId,
    });

typedef ConversationKeyIdFactory =
    String? Function({required int selfId, required int friendId});

typedef ConversationKeyOfferVerifierFactory =
    Future<bool> Function({
      required int selfId,
      required int friendId,
      required ConversationKeyOffer offer,
    });

typedef ConversationKeyEstablishedFactory =
    Future<void> Function({
      required int selfId,
      required int friendId,
      required String keyId,
      required List<int> key,
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
    this.p2pEnabled = true,
    P2PSignalingFactory? signalingFactory,
    this.syncCursorStoreFactory,
    this.p2pIceConfiguration = P2PMessageTransport.defaultIceConfiguration,
    this.deviceId,
    this.relayEncryptionReady = false,
    this.conversationEncryptorFactory,
    this.conversationKeyIdFactory,
    this.conversationKeyResolver,
    this.conversationKeyOfferVerifierFactory,
    this.conversationKeyEstablishedFactory,
    this.localDeviceIdentity,
  }) : _signalingFactory =
           signalingFactory ?? _hostedSignalingFactory(_apiClient);

  /// Selects exactly one deterministic offerer for a peer pair.
  static bool isCaller({required int selfId, required int friendId}) {
    return isDirectMessageCaller(selfId: selfId, friendId: friendId);
  }

  final ApiClient _apiClient;
  final bool p2pEnabled;
  final String? deviceId;
  final bool relayEncryptionReady;
  final ConversationEncryptorFactory? conversationEncryptorFactory;
  final ConversationKeyIdFactory? conversationKeyIdFactory;
  final ConversationKeyResolver? conversationKeyResolver;
  final ConversationKeyOfferVerifierFactory?
  conversationKeyOfferVerifierFactory;
  final ConversationKeyEstablishedFactory? conversationKeyEstablishedFactory;
  final DeviceIdentity? localDeviceIdentity;
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
      deviceId: deviceId,
      relayEncryptionReady: relayEncryptionReady,
      conversationKeyResolver: conversationKeyResolver,
      conversationEncryptor: conversationEncryptorFactory?.call(
        selfId: selfId,
        friendId: friendId,
      ),
      conversationKeyId: conversationKeyIdFactory?.call(
        selfId: selfId,
        friendId: friendId,
      ),
      syncCursorStore: syncCursorStoreFactory?.call(
        selfId: selfId,
        friendId: friendId,
      ),
    );
    if (!p2pEnabled) return server;

    return FallbackMessageTransport(
      primary: _createP2p(
        selfId: selfId,
        friendId: friendId,
        isCaller: isCaller,
      ),
      fallback: server,
    );
  }

  P2PMessageTransport _createP2p({
    required int selfId,
    required int friendId,
    required bool isCaller,
  }) {
    late final P2PMessageTransport transport;
    StreamSubscription<Map<String, Object?>>? pairingSubscription;
    final verifier = conversationKeyOfferVerifierFactory;
    final established = conversationKeyEstablishedFactory;
    transport = P2PMessageTransport(
      friendId: friendId,
      signalingService: _signalingFactory(selfId: selfId, friendId: friendId),
      isCaller: isCaller,
      iceConfiguration: p2pIceConfiguration,
      onConnected: (connectedTransport) async {
        if (verifier == null || established == null) return;
        await pairingSubscription?.cancel();
        final coordinator = ConversationKeyExchangeCoordinator(
          conversationId:
              '${selfId < friendId ? selfId : friendId}:${selfId < friendId ? friendId : selfId}',
          localDeviceId:
              localDeviceIdentity?.deviceId ?? deviceId ?? 'user:$selfId',
          localIdentity: localDeviceIdentity,
          sendControl: connectedTransport.sendControl,
          verifyRemoteOffer: (offer) =>
              verifier(selfId: selfId, friendId: friendId, offer: offer),
          onEstablished: ({required keyId, required key}) => established(
            selfId: selfId,
            friendId: friendId,
            keyId: keyId,
            key: key,
          ),
        );
        pairingSubscription = connectedTransport.controlMessages.listen(
          coordinator.handleControl,
        );
        await coordinator.start();
      },
    );
    return transport;
  }

  P2PMessageTransport createP2P({
    required int friendId,
    required PeerSignalingChannel signalingService,
    required bool isCaller,
  }) {
    return P2PMessageTransport(
      friendId: friendId,
      signalingService: signalingService,
      isCaller: isCaller,
      iceConfiguration: p2pIceConfiguration,
    );
  }
}
