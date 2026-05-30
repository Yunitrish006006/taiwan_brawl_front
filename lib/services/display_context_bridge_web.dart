import 'dart:js_interop';
import 'dart:js_interop_unsafe';

@JS('window')
external JSObject get _window;

({bool isStandalone, bool isMobile}) getDisplayContext() {
  final bridge = _window.getProperty<JSAny?>('taiwanBrawlDisplay'.toJS);
  if (bridge == null) {
    return (isStandalone: false, isMobile: false);
  }

  final raw = (bridge as JSObject).callMethod<JSAny?>('getDisplayContext'.toJS);
  final map = raw?.dartify();
  if (map is Map) {
    return (
      isStandalone: map['isStandalone'] == true,
      isMobile: map['isMobile'] == true,
    );
  }

  return (isStandalone: false, isMobile: false);
}
