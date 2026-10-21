import 'message_event.dart';
import 'message_transport.dart';
import 'platform_ports.dart';

/// Adapts device identity/key resolution to the shared event authenticator.
/// Without a directory this can only verify events from [localIdentity].
class DeviceEventAuthenticator implements EventAuthenticator {
  DeviceEventAuthenticator({required this.localIdentity, this.directory});

  final DeviceIdentity localIdentity;
  final DeviceIdentityDirectory? directory;

  @override
  Future<String> sign(MessageEvent event) {
    if (event.deviceId != localIdentity.deviceId) {
      throw StateError('Signed events must carry the local device identity');
    }
    return localIdentity.sign(event.canonicalPayload);
  }

  @override
  Future<bool> verify(MessageEvent event) async {
    final deviceId = event.deviceId;
    final signature = event.signature;
    if (deviceId == null || signature == null || signature.isEmpty) {
      return false;
    }
    final identity = deviceId == localIdentity.deviceId
        ? localIdentity
        : await directory?.resolve(deviceId);
    if (identity == null) return false;
    return identity.verify(event.canonicalPayload, signature, deviceId);
  }
}
