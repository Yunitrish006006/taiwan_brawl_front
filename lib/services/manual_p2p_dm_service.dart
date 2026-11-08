/// Optional application port for the explicit, serverless DM handshake UI.
///
/// The page can offer manual peer setup without depending on ChatService or
/// transport/signaling implementations.
abstract interface class ManualP2pDmService {
  bool get enabled;

  String? get localDeviceId;

  Future<void> prepare({required bool isCaller});

  Future<String> exportBundle({
    required String sessionId,
    required String senderDeviceId,
  });

  Future<void> importBundle(
    String encoded, {
    String? expectedSessionId,
    String? expectedSenderDeviceId,
  });

  Future<void> complete();
}
