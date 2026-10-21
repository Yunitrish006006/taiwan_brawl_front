import 'dart:async';
import 'dart:convert';

enum PeerSignalType { offer, answer, iceCandidate, close }

/// Negotiation data only. A signaling adapter must not carry message bodies.
class PeerSignal {
  const PeerSignal({
    required this.sessionId,
    required this.senderDeviceId,
    required this.type,
    required this.payload,
  });

  final String sessionId;
  final String senderDeviceId;
  final PeerSignalType type;
  final String payload;
}

/// The minimal rendezvous boundary for Internet WebRTC.
///
/// Implementations may use a Durable Object, a small hosted service, or a
/// future platform. They must exchange negotiation data only; durable message
/// delivery belongs to [MessageTransport].
abstract interface class PeerSignaling {
  Stream<PeerSignal> get signals;

  Future<void> open(String sessionId, String localDeviceId);

  Future<void> send(PeerSignal signal);

  Future<void> close();
}

/// Application-level signaling channel for a peer identified by product id.
abstract interface class PeerSignalingChannel {
  Stream<Map<String, dynamic>> get signalStream;

  Future<void> connect(int peerId);

  void send(int peerId, Map<String, dynamic> payload);

  void disconnect();

  void dispose();
}

/// Serializable offer/answer/ICE package for an out-of-band signaling path.
class PeerNegotiationBundle {
  const PeerNegotiationBundle({
    required this.sessionId,
    required this.senderDeviceId,
    required this.signals,
  });

  final String sessionId;
  final String senderDeviceId;
  final List<Map<String, dynamic>> signals;

  String encode() {
    return jsonEncode({
      'version': 1,
      'sessionId': sessionId,
      'senderDeviceId': senderDeviceId,
      'signals': signals,
    });
  }

  factory PeerNegotiationBundle.decode(String encoded) {
    final decoded = jsonDecode(encoded);
    if (decoded is! Map) {
      throw const FormatException('Negotiation bundle must be an object');
    }
    if (decoded['version'] != 1) {
      throw const FormatException('Unsupported negotiation bundle version');
    }
    final rawSignals = decoded['signals'];
    if (rawSignals is! List) {
      throw const FormatException('Negotiation bundle signals are missing');
    }
    final signals = rawSignals
        .map((signal) {
          if (signal is! Map) {
            throw const FormatException('Negotiation signal must be an object');
          }
          return _validatedSignal(Map<String, dynamic>.from(signal));
        })
        .toList(growable: false);
    return PeerNegotiationBundle(
      sessionId: _requiredText(decoded['sessionId'], 'sessionId'),
      senderDeviceId: _requiredText(
        decoded['senderDeviceId'],
        'senderDeviceId',
      ),
      signals: signals,
    );
  }

  static Map<String, dynamic> validateSignal(Map<String, dynamic> signal) {
    return _validatedSignal(Map<String, dynamic>.from(signal));
  }

  static Map<String, dynamic> _validatedSignal(Map<String, dynamic> signal) {
    final type = signal['type'];
    if (type != 'offer' && type != 'answer' && type != 'ice_candidate') {
      throw const FormatException('Unsupported negotiation signal type');
    }
    if (type == 'offer' || type == 'answer') {
      final sdp = signal['sdp'];
      if (sdp is! String || sdp.trim().isEmpty) {
        throw const FormatException('SDP is missing from negotiation signal');
      }
      return <String, dynamic>{'type': type, 'sdp': sdp};
    } else if (signal['candidate'] is! Map) {
      throw const FormatException('ICE candidate is missing');
    }
    final candidate = Map<String, dynamic>.from(signal['candidate'] as Map);
    return <String, dynamic>{'type': type, 'candidate': candidate};
  }

  static String _requiredText(Object? value, String field) {
    final text = (value as String?)?.trim();
    if (text == null || text.isEmpty) {
      throw FormatException('$field is missing from negotiation bundle');
    }
    return text;
  }
}

/// Serverless signaling adapter for copy/paste, QR, or another local channel.
class ManualPeerSignaling implements PeerSignalingChannel {
  final StreamController<Map<String, dynamic>> _signals =
      StreamController.broadcast();
  final List<Map<String, dynamic>> _outgoing = <Map<String, dynamic>>[];
  bool _disposed = false;

  @override
  Stream<Map<String, dynamic>> get signalStream => _signals.stream;

  @override
  Future<void> connect(int peerId) async {
    if (_disposed) {
      throw StateError('Manual peer signaling is disposed');
    }
  }

  @override
  void send(int peerId, Map<String, dynamic> payload) {
    if (_disposed) return;
    _outgoing.add(PeerNegotiationBundle.validateSignal(payload));
  }

  List<Map<String, dynamic>> takeOutgoingSignals() {
    final signals = List<Map<String, dynamic>>.from(_outgoing);
    _outgoing.clear();
    return signals;
  }

  void acceptSignals(Iterable<Map<String, dynamic>> signals) {
    if (_disposed) return;
    for (final signal in signals) {
      _signals.add(PeerNegotiationBundle.validateSignal(signal));
    }
  }

  String exportBundle({
    required String sessionId,
    required String senderDeviceId,
  }) {
    return PeerNegotiationBundle(
      sessionId: sessionId,
      senderDeviceId: senderDeviceId,
      signals: takeOutgoingSignals(),
    ).encode();
  }

  void importBundle(
    String encoded, {
    String? expectedSessionId,
    String? expectedSenderDeviceId,
  }) {
    final bundle = PeerNegotiationBundle.decode(encoded);
    if (expectedSessionId != null && bundle.sessionId != expectedSessionId) {
      throw const FormatException('Negotiation bundle session does not match');
    }
    if (expectedSenderDeviceId != null &&
        bundle.senderDeviceId != expectedSenderDeviceId) {
      throw const FormatException('Negotiation bundle sender does not match');
    }
    acceptSignals(bundle.signals);
  }

  @override
  void disconnect() {}

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    unawaited(_signals.close());
    _outgoing.clear();
  }
}
