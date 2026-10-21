import 'dart:async';

import 'package:taiwan_brawl_messaging/taiwan_brawl_messaging.dart';

import '../models/chat_models.dart';
import 'local_chat_repository.dart';
import 'p2p_message_session.dart';
import 'p2p_message_transport.dart';

/// Manages one WebRTC DataChannel connection for P2P chat.
///
/// The public facade remains compatible with the previous service, while the
/// actual peer connection is now a reusable shared [MessageTransport].
class P2PChatService {
  P2PChatService({
    required this.selfId,
    required this.friendId,
    required this.signalingService,
    required this.localRepo,
    required this.onMessage,
    MessageRepository? eventRepository,
    EventAuthenticator? authenticator,
    String? deviceId,
    P2PMessageTransportFactory? transportFactory,
    this.iceConfiguration = P2PMessageTransport.defaultIceConfiguration,
  }) : _eventRepository = eventRepository ?? MessageRepository(),
       _ownsEventRepository = eventRepository == null,
       _transportFactory = transportFactory {
    _session = P2PMessageSession(
      selfId: selfId,
      friendId: friendId,
      repository: _eventRepository,
      onMessage: onMessage,
      authenticator: authenticator,
      deviceId: deviceId,
    );
  }

  final int selfId;
  final int friendId;
  final PeerSignalingChannel signalingService;
  final Map<String, dynamic> iceConfiguration;
  final P2PMessageTransportFactory? _transportFactory;
  @Deprecated('P2P event state is stored by the shared MessageRepository')
  final LocalChatRepository localRepo;
  final void Function(ChatMessage) onMessage;

  final MessageRepository _eventRepository;
  final bool _ownsEventRepository;
  late final P2PMessageSession _session;
  P2PMessageTransport? _transport;

  bool get isConnected => _transport?.isConnected == true;

  Future<void> startAsCaller() async => _init(isCaller: true);

  Future<void> startAsAnswerer() async => _init(isCaller: false);

  /// Starts the manual, serverless negotiation phase without waiting for a
  /// DataChannel. Exchange the exported bundle with the other device, then
  /// call [completeManualNegotiation].
  Future<void> prepareManualNegotiation({required bool isCaller}) async {
    if (signalingService is! ManualPeerSignaling) {
      throw StateError('Manual negotiation requires ManualPeerSignaling');
    }
    await _transport?.disconnect();
    final transport = _newTransport(isCaller: isCaller);
    _transport = transport;
    await transport.prepare();
  }

  /// Completes a manual negotiation after the exchanged bundles have been
  /// imported through [importNegotiationBundle].
  Future<void> completeManualNegotiation() async {
    final transport = _transport;
    if (transport == null) {
      throw StateError('Manual negotiation has not been prepared');
    }
    await _session.attach(transport);
  }

  Future<void> _init({required bool isCaller}) async {
    await _transport?.disconnect();
    final transport = _newTransport(isCaller: isCaller);
    _transport = transport;
    await _session.attach(transport);
  }

  P2PMessageTransport _newTransport({required bool isCaller}) {
    return _transportFactory?.call(
          friendId: friendId,
          signalingService: signalingService,
          isCaller: isCaller,
          iceConfiguration: iceConfiguration,
        ) ??
        P2PMessageTransport(
          friendId: friendId,
          signalingService: signalingService,
          isCaller: isCaller,
          iceConfiguration: iceConfiguration,
        );
  }

  /// Sends a created event using the shared envelope.
  ///
  /// Events are durable in the shared repository even while the peer is
  /// temporarily disconnected; the session flushes them after attachment.
  bool sendMessage(String text) {
    unawaited(_session.send(text));
    return true;
  }

  /// Queues an edit for a locally authored P2P message.
  Future<bool> editMessage(String messageId, String text) {
    return _session.edit(messageId, text);
  }

  /// Queues a recall for a locally authored P2P message.
  Future<bool> recallMessage(String messageId) {
    return _session.recall(messageId);
  }

  /// Exports the current manual signaling queue for copy/paste, QR, or a
  /// local rendezvous channel. Hosted signaling deliberately has no such
  /// export surface because its negotiation is already live.
  String exportNegotiationBundle({
    required String sessionId,
    required String senderDeviceId,
  }) {
    final manual = signalingService;
    if (manual is! ManualPeerSignaling) {
      throw StateError(
        'Negotiation bundle export requires ManualPeerSignaling',
      );
    }
    return manual.exportBundle(
      sessionId: sessionId,
      senderDeviceId: senderDeviceId,
    );
  }

  /// Imports a bundle produced by another manual peer after checking the
  /// expected session and sender device identity.
  void importNegotiationBundle(
    String encoded, {
    String? expectedSessionId,
    String? expectedSenderDeviceId,
  }) {
    final manual = signalingService;
    if (manual is! ManualPeerSignaling) {
      throw StateError(
        'Negotiation bundle import requires ManualPeerSignaling',
      );
    }
    manual.importBundle(
      encoded,
      expectedSessionId: expectedSessionId,
      expectedSenderDeviceId: expectedSenderDeviceId,
    );
  }

  Future<void> dispose() async {
    await _session.dispose();
    _transport = null;
    if (_ownsEventRepository) await _eventRepository.dispose();
  }
}
