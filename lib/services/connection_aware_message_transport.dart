/// Optional transport capability for reporting real connection state changes.
abstract interface class ConnectionAwareMessageTransport {
  bool get isTransportConnected;

  Stream<bool> get connectionStateChanges;
}
