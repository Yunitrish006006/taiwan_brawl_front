/// Optional conversation capability for a player-controlled relay fallback.
abstract interface class RelayFallbackDmService {
  /// Base delay between P2P retries before the UI applies capped backoff.
  Duration get p2pRetryInterval;

  Stream<void> get connectionStateChanges;

  bool get relayFallbackChoiceRequired;

  bool get p2pActive;

  bool get relayFallbackActive;

  Future<bool> retryP2PConnection();

  Future<void> useRelayFallback();
}
