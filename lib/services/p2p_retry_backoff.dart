/// Calculates bounded delays between user-approved P2P reconnect attempts.
class P2PRetryBackoff {
  const P2PRetryBackoff._();

  static const minimumDelay = Duration(seconds: 1);
  static const maximumDelay = Duration(minutes: 1);

  /// [failedAttempts] is the number of retries that have already failed.
  static Duration delay({
    required Duration baseDelay,
    required int failedAttempts,
  }) {
    var delay = baseDelay > Duration.zero ? baseDelay : minimumDelay;
    if (delay >= maximumDelay) return maximumDelay;

    for (var attempt = 0; attempt < failedAttempts; attempt++) {
      if (delay.inMicroseconds >= maximumDelay.inMicroseconds ~/ 2) {
        return maximumDelay;
      }
      delay = Duration(microseconds: delay.inMicroseconds * 2);
    }
    return delay > maximumDelay ? maximumDelay : delay;
  }
}
