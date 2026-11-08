import 'dart:js_interop';

@JS('Intl.DateTimeFormat')
extension type _DateTimeFormat._(JSObject _) implements JSObject {
  external factory _DateTimeFormat();
  external _ResolvedOptions resolvedOptions();
}
extension type _ResolvedOptions._(JSObject _) implements JSObject {
  external String get timeZone;
}

Future<String> deviceTimeZone() async {
  final value = _DateTimeFormat().resolvedOptions().timeZone;
  if (value.isEmpty) throw StateError('Time zone unavailable');
  return value;
}
