import 'package:flutter_test/flutter_test.dart';
import 'package:taiwan_brawl/services/p2p_connection_status.dart';

void main() {
  test('P2P is ready only while the peer and data channel are both ready', () {
    expect(
      isP2PPathReady(peerConnected: true, dataChannelOpen: true),
      isTrue,
    );
    expect(
      isP2PPathReady(peerConnected: false, dataChannelOpen: true),
      isFalse,
    );
    expect(
      isP2PPathReady(peerConnected: true, dataChannelOpen: false),
      isFalse,
    );
    expect(
      isP2PPathReady(peerConnected: false, dataChannelOpen: false),
      isFalse,
    );
  });
}
