import 'dart:async';

import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:taiwan_brawl_messaging/taiwan_brawl_messaging.dart';

import 'webrtc_message_transport.dart';

typedef PeerConnectionFactory =
    Future<RTCPeerConnection> Function(Map<String, dynamic> configuration);

typedef P2PMessageTransportFactory =
    P2PMessageTransport Function({
      required int friendId,
      required PeerSignalingChannel signalingService,
      required bool isCaller,
      required Map<String, dynamic> iceConfiguration,
    });

/// Owns the WebRTC peer-connection lifecycle while exposing the shared
/// transport contract used by [MessageSyncEngine].
///
/// This keeps signaling and ICE details out of message commands and lets the
/// same transport be selected by either the legacy P2P facade or ChatService.
class P2PMessageTransport implements MessageTransport {
  P2PMessageTransport({
    required this.friendId,
    required this.signalingService,
    this.isCaller = true,
    this.peerConnectionFactory = createPeerConnection,
    this.iceConfiguration = defaultIceConfiguration,
  });

  final int friendId;
  final PeerSignalingChannel signalingService;
  final bool isCaller;
  final PeerConnectionFactory peerConnectionFactory;
  final Map<String, dynamic> iceConfiguration;

  final StreamController<MessageEvent> _events =
      StreamController<MessageEvent>.broadcast();
  StreamSubscription<Map<String, dynamic>>? _signalSub;
  StreamSubscription<MessageEvent>? _channelSub;
  RTCPeerConnection? _peerConnection;
  WebRtcMessageTransport? _channelTransport;
  Completer<RTCDataChannel>? _channelCompleter;
  Future<void>? _preparing;
  Timer? _offerRetryTimer;
  RTCSessionDescription? _localOffer;
  final List<Map<String, dynamic>> _localIceCandidates = [];
  String? _remoteOfferSdp;
  bool _connected = false;
  bool _disposed = false;

  @override
  Stream<MessageEvent> get events => _events.stream;

  bool get isConnected => _connected;

  @override
  Future<void> connect() async {
    if (_connected) return;
    if (_disposed) throw StateError('P2P message transport is disposed');
    try {
      await prepare();
      final channel = await _channelCompleter!.future.timeout(
        const Duration(seconds: 15),
        onTimeout: () => throw TimeoutException(
          'Timed out waiting for the P2P data channel',
        ),
      );
      final transport = WebRtcMessageTransport(channel);
      _channelTransport = transport;
      _channelSub = transport.events.listen(
        _events.add,
        onError: _events.addError,
      );
      await transport.connect().timeout(
        const Duration(seconds: 15),
        onTimeout: () =>
            throw TimeoutException('Timed out opening the P2P data channel'),
      );
      _connected = true;
      _offerRetryTimer?.cancel();
      _offerRetryTimer = null;
    } catch (_) {
      await disconnect();
      rethrow;
    }
  }

  /// Prepares the peer connection and signaling exchange without waiting for
  /// the remote DataChannel to open.
  ///
  /// This is the explicit phase needed by serverless/manual signaling: the
  /// caller can prepare, export its offer/ICE bundle, import the answer, and
  /// only then call [connect] (or let the service complete the negotiation).
  Future<void> prepare() async {
    if (_disposed) throw StateError('P2P message transport is disposed');
    if (_connected || _channelTransport != null) return;
    if (_preparing != null) return _preparing!;

    final preparation = _prepare();
    _preparing = preparation;
    try {
      await preparation;
    } finally {
      if (identical(_preparing, preparation)) _preparing = null;
    }
  }

  Future<void> _prepare() async {
    try {
      await _prepareConnection();
    } catch (_) {
      await disconnect();
      rethrow;
    }
  }

  Future<void> _prepareConnection() async {
    if (_connected || _channelTransport != null) return;

    _peerConnection = await peerConnectionFactory(iceConfiguration);
    _channelCompleter = Completer<RTCDataChannel>();
    _peerConnection!.onIceCandidate = (candidate) {
      final payload = <String, dynamic>{
        'type': 'ice_candidate',
        'candidate': candidate.toMap(),
      };
      _localIceCandidates.add(payload);
      signalingService.send(friendId, payload);
    };
    _peerConnection!.onDataChannel = (channel) {
      _completeChannel(channel);
    };
    _signalSub = signalingService.signalStream.listen(_handleSignal);

    // Install the listener before connecting so an eager offer/ICE message is
    // not lost during the signaling handshake.
    await signalingService.connect(friendId);

    if (isCaller) {
      final channel = await _peerConnection!.createDataChannel(
        'chat',
        RTCDataChannelInit()..ordered = true,
      );
      _completeChannel(channel);
      final offer = await _peerConnection!.createOffer();
      await _peerConnection!.setLocalDescription(offer);
      _localOffer = offer;
      _sendOffer();
      _offerRetryTimer = Timer.periodic(const Duration(seconds: 2), (_) {
        if (!_connected) _sendOffer();
      });
    }
  }

  @override
  Future<void> send(MessageEvent event) async {
    final transport = _channelTransport;
    if (!_connected || transport == null) {
      throw StateError('P2P message transport is not connected');
    }
    await transport.send(event);
  }

  @override
  Future<void> disconnect() async {
    if (_disposed) return;
    _connected = false;
    _offerRetryTimer?.cancel();
    _offerRetryTimer = null;
    _localOffer = null;
    _localIceCandidates.clear();
    _remoteOfferSdp = null;
    await _signalSub?.cancel();
    _signalSub = null;
    await _channelSub?.cancel();
    _channelSub = null;
    await _channelTransport?.dispose();
    _channelTransport = null;
    await _peerConnection?.close();
    _peerConnection = null;
    _channelCompleter = null;
    _preparing = null;
    signalingService.disconnect();
  }

  Future<void> dispose() async {
    if (_disposed) return;
    await disconnect();
    _disposed = true;
    await _events.close();
    signalingService.dispose();
  }

  void _completeChannel(RTCDataChannel channel) {
    final completer = _channelCompleter;
    if (completer != null && !completer.isCompleted) {
      completer.complete(channel);
    }
  }

  void _sendOffer() {
    final offer = _localOffer;
    if (offer == null) return;
    signalingService.send(friendId, {'type': 'offer', 'sdp': offer.sdp});
    for (final candidate in _localIceCandidates) {
      signalingService.send(friendId, candidate);
    }
  }

  Future<void> _handleSignal(Map<String, dynamic> payload) async {
    final peerConnection = _peerConnection;
    final type = payload['type'] as String?;
    if (peerConnection == null || type == null) return;

    switch (type) {
      case 'offer':
        final sdp = payload['sdp'] as String?;
        if (sdp == null || sdp == _remoteOfferSdp) return;
        _remoteOfferSdp = sdp;
        await peerConnection.setRemoteDescription(
          RTCSessionDescription(sdp, 'offer'),
        );
        final answer = await peerConnection.createAnswer();
        await peerConnection.setLocalDescription(answer);
        signalingService.send(friendId, {'type': 'answer', 'sdp': answer.sdp});
      case 'answer':
        await peerConnection.setRemoteDescription(
          RTCSessionDescription(payload['sdp'] as String, 'answer'),
        );
      case 'ice_candidate':
        final raw = payload['candidate'];
        if (raw is Map) {
          await peerConnection.addCandidate(
            RTCIceCandidate(
              raw['candidate'] as String?,
              raw['sdpMid'] as String?,
              raw['sdpMLineIndex'] as int?,
            ),
          );
        }
    }
  }

  static const Map<String, dynamic> defaultIceConfiguration = {
    'iceServers': [
      {'urls': 'stun:stun.l.google.com:19302'},
    ],
  };
}
