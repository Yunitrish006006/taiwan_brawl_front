import 'dart:async';

import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:taiwan_brawl_messaging/taiwan_brawl_messaging.dart';

import 'connection_aware_message_transport.dart';
import 'p2p_connection_status.dart';
import 'webrtc_message_transport.dart';

typedef PeerConnectionFactory =
    Future<RTCPeerConnection> Function(Map<String, dynamic> configuration);

/// Owns the WebRTC peer-connection lifecycle while exposing the shared
/// transport contract used by [MessageSyncEngine] through ChatService.
///
/// This keeps signaling and ICE details out of message commands and lets the
/// same transport be selected by either the legacy P2P facade or ChatService.
class P2PMessageTransport
    implements NegotiatingMessageTransport, ConnectionAwareMessageTransport {
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
  final StreamController<bool> _connectionStates =
      StreamController<bool>.broadcast();
  StreamSubscription<Map<String, dynamic>>? _signalSub;
  StreamSubscription<MessageEvent>? _channelSub;
  StreamSubscription<bool>? _channelStateSub;
  Future<void> _signalTail = Future<void>.value();
  RTCPeerConnection? _peerConnection;
  WebRtcMessageTransport? _channelTransport;
  Completer<RTCDataChannel>? _channelCompleter;
  Future<void>? _preparing;
  Timer? _offerRetryTimer;
  RTCSessionDescription? _localOffer;
  final List<Map<String, dynamic>> _localIceCandidates = [];
  final List<Map<String, dynamic>> _pendingRemoteIceCandidates = [];
  String? _remoteOfferSdp;
  bool _remoteDescriptionSet = false;
  bool _prepared = false;
  bool _connected = false;
  bool _disposed = false;

  @override
  Stream<MessageEvent> get events => _events.stream;

  @override
  Stream<bool> get connectionStateChanges => _connectionStates.stream;

  @override
  bool get isTransportConnected =>
      _connected && (_channelTransport?.isTransportConnected ?? false);

  bool get isConnected => isTransportConnected;

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
      await _attachDataChannel(channel);
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
  @override
  Future<void> prepare() async {
    if (_disposed) throw StateError('P2P message transport is disposed');
    if (_connected || _channelTransport != null || _prepared) return;
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
    if (_connected || _channelTransport != null || _prepared) return;

    _peerConnection = await peerConnectionFactory(iceConfiguration);
    _peerConnection!.onConnectionState = (state) {
      final peerConnected =
          state == RTCPeerConnectionState.RTCPeerConnectionStateConnected;
      final channelConnected =
          _channelTransport?.isTransportConnected ?? false;
      _setConnected(
        isP2PPathReady(
          peerConnected: peerConnected,
          dataChannelOpen: channelConnected,
        ),
      );
    };
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
    _signalSub = signalingService.signalStream.listen(_enqueueSignal);

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
    _prepared = true;
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
    _setConnected(false);
    _offerRetryTimer?.cancel();
    _offerRetryTimer = null;
    _prepared = false;
    _localOffer = null;
    _localIceCandidates.clear();
    _pendingRemoteIceCandidates.clear();
    _remoteOfferSdp = null;
    _remoteDescriptionSet = false;
    await _signalSub?.cancel();
    _signalSub = null;
    await _channelSub?.cancel();
    _channelSub = null;
    await _channelStateSub?.cancel();
    _channelStateSub = null;
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
    await _connectionStates.close();
    signalingService.dispose();
  }

  void _setConnected(bool connected) {
    if (_connected == connected) return;
    _connected = connected;
    if (!_connectionStates.isClosed) _connectionStates.add(connected);
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
    var peerConnection = _peerConnection;
    final type = payload['type'] as String?;
    if (peerConnection == null || type == null) return;

    switch (type) {
      case 'offer':
        final sdp = payload['sdp'] as String?;
        if (sdp == null || sdp == _remoteOfferSdp) return;
        final isNewPeerSession = _remoteOfferSdp != null;
        if (isNewPeerSession) {
          // A new SDP from the same peer means the offerer rebuilt its peer
          // connection. Rebuild our side too so the new DataChannel is bound
          // to the long-lived message event stream.
          await disconnect();
          await prepare();
          peerConnection = _peerConnection;
          if (peerConnection == null) return;
        }
        _remoteOfferSdp = sdp;
        await peerConnection.setRemoteDescription(
          RTCSessionDescription(sdp, 'offer'),
        );
        await _acceptRemoteDescription(peerConnection);
        final answer = await peerConnection.createAnswer();
        await peerConnection.setLocalDescription(answer);
        signalingService.send(friendId, {'type': 'answer', 'sdp': answer.sdp});
        if (isNewPeerSession) {
          final channel = await _channelCompleter!.future.timeout(
            const Duration(seconds: 15),
            onTimeout: () => throw TimeoutException(
              'Timed out waiting for the replacement P2P data channel',
            ),
          );
          await _attachDataChannel(channel);
        }
      case 'answer':
        await peerConnection.setRemoteDescription(
          RTCSessionDescription(payload['sdp'] as String, 'answer'),
        );
        await _acceptRemoteDescription(peerConnection);
      case 'ice_candidate':
        final raw = payload['candidate'];
        if (raw is Map) {
          final candidate = Map<String, dynamic>.from(raw);
          if (!_remoteDescriptionSet) {
            _pendingRemoteIceCandidates.add(candidate);
          } else {
            await _addRemoteIceCandidate(peerConnection, candidate);
          }
        }
    }
  }

  void _enqueueSignal(Map<String, dynamic> payload) {
    final operation = _signalTail.then((_) => _handleSignal(payload));
    _signalTail = operation.catchError((Object _) {
      // A failed negotiation step must surface as a lost P2P route so the
      // player can retry or choose relay; it must not become an unhandled
      // asynchronous stream error.
      _setConnected(false);
    });
  }

  Future<void> _attachDataChannel(RTCDataChannel channel) async {
    await _channelSub?.cancel();
    _channelSub = null;
    await _channelStateSub?.cancel();
    _channelStateSub = null;
    await _channelTransport?.dispose();

    final transport = WebRtcMessageTransport(channel);
    _channelTransport = transport;
    _channelStateSub = transport.connectionStateChanges.listen((connected) {
      _setConnected(connected);
    });
    _channelSub = transport.events.listen(
      _events.add,
      onError: _events.addError,
    );
    await transport.connect().timeout(
      const Duration(seconds: 15),
      onTimeout: () =>
          throw TimeoutException('Timed out opening the P2P data channel'),
    );
    _setConnected(true);
  }

  Future<void> _acceptRemoteDescription(
    RTCPeerConnection peerConnection,
  ) async {
    _remoteDescriptionSet = true;
    final candidates = List<Map<String, dynamic>>.from(
      _pendingRemoteIceCandidates,
    );
    _pendingRemoteIceCandidates.clear();
    for (final candidate in candidates) {
      await _addRemoteIceCandidate(peerConnection, candidate);
    }
  }

  Future<void> _addRemoteIceCandidate(
    RTCPeerConnection peerConnection,
    Map<String, dynamic> raw,
  ) => peerConnection.addCandidate(
    RTCIceCandidate(
      raw['candidate'] as String?,
      raw['sdpMid'] as String?,
      raw['sdpMLineIndex'] as int?,
    ),
  );

  static const Map<String, dynamic> defaultIceConfiguration = {
    'iceServers': [
      {'urls': 'stun:stun.l.google.com:19302'},
    ],
  };
}
