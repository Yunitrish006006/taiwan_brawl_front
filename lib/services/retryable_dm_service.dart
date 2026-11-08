/// Optional retry boundary for a message that was durably queued before an
/// immediate transport failure. Implementations must reuse the existing event
/// instead of creating a second message.
abstract interface class RetryableDmService {
  Future<void> retryPendingMessage(int receiverId, String text);
}
