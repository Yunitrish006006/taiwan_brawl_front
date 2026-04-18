import 'dart:js_interop';
import 'dart:js_interop_unsafe';

@JS('window')
external JSObject get _window;

JSObject? _bridge() {
  final bridge = _window.getProperty<JSAny?>('taiwanBrawlPush'.toJS);
  if (bridge == null) {
    return null;
  }
  return bridge as JSObject;
}

Map<String, dynamic>? _mapFromJs(JSAny? raw) {
  final dartified = raw.dartify();
  if (dartified is Map) {
    return Map<String, dynamic>.from(dartified);
  }
  return null;
}

int? _intFromJs(JSAny? raw) {
  final dartified = raw.dartify();
  if (dartified is num) {
    return dartified.toInt();
  }
  if (dartified is String) {
    return int.tryParse(dartified);
  }
  return null;
}

Future<Map<String, dynamic>?> registerWebPush({
  required String publicKey,
  required String serviceWorkerPath,
  required String serviceWorkerScope,
}) async {
  final bridge = _bridge();
  if (bridge == null) {
    return null;
  }

  final promise = bridge.callMethod<JSPromise<JSAny?>>(
    'register'.toJS,
    <String, String>{
      'publicKey': publicKey,
      'serviceWorkerPath': serviceWorkerPath,
      'serviceWorkerScope': serviceWorkerScope,
    }.jsify(),
  );
  final result = await promise.toDart;
  return _mapFromJs(result);
}

Future<void> unregisterWebPush() async {
  final bridge = _bridge();
  if (bridge == null) {
    return;
  }

  final promise = bridge.callMethod<JSPromise<JSAny?>>('unregister'.toJS);
  await promise.toDart;
}

Future<int?> consumePendingConversationUserId() async {
  final bridge = _bridge();
  if (bridge == null) {
    return null;
  }

  final result = bridge.callMethod<JSAny?>('consumePendingConversationUserId'.toJS);
  return _intFromJs(result);
}

String getNotificationPermission() {
  final bridge = _bridge();
  if (bridge == null) {
    return 'unsupported';
  }
  final result = bridge.callMethod<JSAny?>('getPermissionState'.toJS);
  return (result.dartify() as String?) ?? 'unsupported';
}

({bool isStandalone, bool isMobile}) getDisplayContext() {
  final bridge = _bridge();
  if (bridge == null) {
    return (isStandalone: false, isMobile: false);
  }
  final raw = bridge.callMethod<JSAny?>('getDisplayContext'.toJS);
  final map = raw?.dartify();
  if (map is Map) {
    return (
      isStandalone: map['isStandalone'] == true,
      isMobile: map['isMobile'] == true,
    );
  }
  return (isStandalone: false, isMobile: false);
}
