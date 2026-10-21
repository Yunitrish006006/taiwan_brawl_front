import 'message_event.dart';

abstract interface class MessageTransport {
  Stream<MessageEvent> get events;

  Future<void> connect();

  Future<void> send(MessageEvent event);

  Future<void> disconnect();
}

/// Optional receive acknowledgement boundary for transports with a durable
/// remote queue. The sync engine calls this only after local ingestion has
/// completed (including conflict recording), so a local storage failure leaves
/// the remote event available for retry.
abstract interface class MessageReceiptTransport implements MessageTransport {
  Future<void> acknowledgeReceived(
    MessageEvent event, {
    required bool accepted,
  });
}

abstract interface class EventAuthenticator {
  Future<String> sign(MessageEvent event);

  Future<bool> verify(MessageEvent event);
}
