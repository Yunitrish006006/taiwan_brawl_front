import 'package:crypto/crypto.dart';
import 'package:taiwan_brawl_messaging/taiwan_brawl_messaging.dart';

import 'conversation_key_agreement.dart';

typedef SendConversationControl =
    Future<void> Function(Map<String, Object?> message);

typedef ConversationKeyEstablished =
    Future<void> Function({required String keyId, required List<int> key});

typedef VerifyConversationKeyOffer =
    Future<bool> Function(ConversationKeyOffer offer);

/// Coordinates the two-sided key exchange after a P2P DataChannel is open.
///
/// The caller must authenticate [ConversationKeyOffer.deviceId] and its public
/// key through the existing trusted-device flow before calling [handleControl].
/// Raw key bytes are never placed in a control message.
class ConversationKeyExchangeCoordinator {
  ConversationKeyExchangeCoordinator({
    required this.conversationId,
    required this.localDeviceId,
    required SendConversationControl sendControl,
    required ConversationKeyEstablished onEstablished,
    required VerifyConversationKeyOffer verifyRemoteOffer,
    this.localIdentity,
    this.expectedRemoteDeviceId,
  }) : _sendControl = sendControl,
       _onEstablished = onEstablished,
       _verifyRemoteOffer = verifyRemoteOffer;

  static const offerKind = 'conversation-key-offer';
  static const ackKind = 'conversation-key-ack';

  final String conversationId;
  final String localDeviceId;
  final String? expectedRemoteDeviceId;
  final SendConversationControl _sendControl;
  final ConversationKeyEstablished _onEstablished;
  final VerifyConversationKeyOffer _verifyRemoteOffer;
  final DeviceIdentity? localIdentity;
  ConversationKeyAgreement? _agreement;
  String? _establishedKeyId;

  bool get established => _establishedKeyId != null;

  Future<void> start() async {
    _agreement ??= await ConversationKeyAgreement.create(
      conversationId: conversationId,
      localDeviceId: localDeviceId,
    );
    var offer = _agreement!.offer;
    final identity = localIdentity;
    if (identity != null) {
      offer = offer.withSignature(await identity.sign(offer.canonicalPayload));
    }
    await _sendControl({'kind': offerKind, 'offer': offer.toJson()});
  }

  Future<void> handleControl(Map<String, Object?> message) async {
    final kind = message['kind'];
    if (kind == ackKind) return;
    if (kind != offerKind || message['offer'] is! Map) return;

    final offer = ConversationKeyOffer.fromJson(
      Map<String, Object?>.from(message['offer'] as Map),
    );
    if (offer.conversationId != conversationId ||
        offer.deviceId == localDeviceId ||
        (expectedRemoteDeviceId != null &&
            offer.deviceId != expectedRemoteDeviceId)) {
      throw const FormatException('Conversation key offer peer mismatch');
    }
    if (!await _verifyRemoteOffer(offer)) {
      throw const FormatException('Conversation key offer is not trusted');
    }
    _agreement ??= await ConversationKeyAgreement.create(
      conversationId: conversationId,
      localDeviceId: localDeviceId,
    );
    final key = await _agreement!.deriveKey(offer);
    final keyId = _keyIdFor(_agreement!.offer.publicKey, offer.publicKey);
    if (_establishedKeyId == keyId) return;
    _establishedKeyId = keyId;
    await _onEstablished(keyId: keyId, key: key);
    await _sendControl({'kind': ackKind, 'keyId': keyId});
  }

  String _keyIdFor(String localPublicKey, String remotePublicKey) {
    final keys = [localPublicKey, remotePublicKey]..sort();
    return 'conversation-key-${sha256.convert('$conversationId:${keys.join(':')}'.codeUnits).toString().substring(0, 24)}';
  }
}
