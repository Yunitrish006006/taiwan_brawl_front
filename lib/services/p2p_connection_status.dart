/// Reports a usable P2P route only when both the peer and data channel are up.
bool isP2PPathReady({
  required bool peerConnected,
  required bool dataChannelOpen,
}) =>
    peerConnected && dataChannelOpen;
