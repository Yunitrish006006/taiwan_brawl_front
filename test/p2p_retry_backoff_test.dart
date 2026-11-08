import 'package:flutter_test/flutter_test.dart';
import 'package:taiwan_brawl/services/p2p_retry_backoff.dart';

void main() {
  test('doubles P2P retry delay and caps it at one minute', () {
    final delays = [
      for (var attempt = 0; attempt < 6; attempt++)
        P2PRetryBackoff.delay(
          baseDelay: const Duration(seconds: 5),
          failedAttempts: attempt,
        ),
    ];

    expect(delays, [
      const Duration(seconds: 5),
      const Duration(seconds: 10),
      const Duration(seconds: 20),
      const Duration(seconds: 40),
      const Duration(minutes: 1),
      const Duration(minutes: 1),
    ]);
  });

  test('uses a one-second minimum for a nonpositive base delay', () {
    expect(
      P2PRetryBackoff.delay(baseDelay: Duration.zero, failedAttempts: 0),
      const Duration(seconds: 1),
    );
    expect(
      P2PRetryBackoff.delay(
        baseDelay: const Duration(seconds: 90),
        failedAttempts: 0,
      ),
      const Duration(minutes: 1),
    );
  });
}
