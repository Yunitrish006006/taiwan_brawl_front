import 'dart:async';
import 'dart:convert';

import 'package:flutter_webrtc/flutter_webrtc.dart';

import '../models/chat_models.dart';
import 'local_chat_repository.dart';
import 'signaling_service.dart';

/// Manages a single WebRTC DataChannel connection for peer-to-peer chat.
/// Falls back to server relay when the peer is not reachable.
class P2PChatService {
  P2PChatService({
    required this.selfId,
    required this.friendId,
    required this.signalingService,
    required this.localRepo,
    required this.onMessage,
  });

  final int selfId;
  final int friendId;
  final SignalingService signalingService;
  final LocalChatRepository localRepo;

  /// Called whenever a new message arrives via DataChannel.
  final void Function(ChatMessage) onMessage;

  RTCPeerConnection? _pc;
  RTCDataChannel? _dataChannel;
  StreamSubscription<Map<String, dynamic>>? _signalSub;

  bool get isConnected => _dataChannel?.state == RTCDataChannelState.RTCDataChannelOpen;

  static const Map<String, dynamic> _iceConfig = {
    'iceServers': [
      {'urls': 'stun:stun.l.google.com:19302'},
    ]
  };

  /// Initiate connection as the caller (creates offer).
  Future<void> startAsCaller() async {
    await _init(isCaller: true);
  }

  /// Wait for an incoming offer (answerer side).
  Future<void> startAsAnswerer() async {
    await _init(isCaller: false);
  }

  Future<void> _init({required bool isCaller}) async {
    _pc = await createPeerConnection(_iceConfig);

    _pc!.onIceCandidate = (candidate) {
      signalingService.send(friendId, {
        'type': 'ice_candidate',
        'candidate': candidate.toMap(),
      });
    };

    _pc!.onDataChannel = (channel) {
      _setupDataChannel(channel);
    };

    _signalSub = signalingService.signalStream.listen(_handleSignal);

    if (isCaller) {
      final dc = await _pc!.createDataChannel(
        'chat',
        RTCDataChannelInit()..ordered = true,
      );
      _setupDataChannel(dc);

      final offer = await _pc!.createOffer();
      await _pc!.setLocalDescription(offer);
      signalingService.send(friendId, {
        'type': 'offer',
        'sdp': offer.sdp,
      });
    }
  }

  void _setupDataChannel(RTCDataChannel channel) {
    _dataChannel = channel;
    channel.onDataChannelState = (state) {};
    channel.onMessage = (RTCDataChannelMessage msg) {
      try {
        final map = jsonDecode(msg.text) as Map<String, dynamic>;
        final chatMsg = ChatMessage(
          senderId: friendId,
          receiverId: selfId,
          text: map['text'] as String? ?? '',
          createdAt: map['createdAt'] as String? ?? DateTime.now().toIso8601String(),
        );
        localRepo.saveMessage(selfId, chatMsg);
        onMessage(chatMsg);
      } catch (_) {}
    };
  }

  Future<void> _handleSignal(Map<String, dynamic> payload) async {
    final type = payload['type'] as String?;
    if (type == null || _pc == null) return;

    switch (type) {
      case 'offer':
        await _pc!.setRemoteDescription(
          RTCSessionDescription(payload['sdp'] as String, 'offer'),
        );
        final answer = await _pc!.createAnswer();
        await _pc!.setLocalDescription(answer);
        signalingService.send(friendId, {
          'type': 'answer',
          'sdp': answer.sdp,
        });

      case 'answer':
        await _pc!.setRemoteDescription(
          RTCSessionDescription(payload['sdp'] as String, 'answer'),
        );

      case 'ice_candidate':
        final raw = payload['candidate'];
        if (raw is Map) {
          await _pc!.addCandidate(RTCIceCandidate(
            raw['candidate'] as String?,
            raw['sdpMid'] as String?,
            raw['sdpMLineIndex'] as int?,
          ));
        }
    }
  }

  /// Send a message over DataChannel. Returns false if channel not open.
  bool sendMessage(String text) {
    if (!isConnected) return false;
    final createdAt = DateTime.now().toIso8601String();
    _dataChannel!.send(RTCDataChannelMessage(jsonEncode({
      'text': text,
      'createdAt': createdAt,
    })));

    // Save outgoing message locally
    final msg = ChatMessage(
      senderId: selfId,
      receiverId: friendId,
      text: text,
      createdAt: createdAt,
    );
    localRepo.saveMessage(selfId, msg);
    onMessage(msg);
    return true;
  }

  Future<void> dispose() async {
    await _signalSub?.cancel();
    await _dataChannel?.close();
    await _pc?.close();
    _dataChannel = null;
    _pc = null;
  }
}
