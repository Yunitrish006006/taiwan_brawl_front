import 'package:flutter/services.dart';

/// Read on every operation so travel and system setting changes are respected.
Future<String> deviceTimeZone() async {
  final value = await const MethodChannel(
    'taiwan_brawl/device_time_zone',
  ).invokeMethod<String>('current');
  if (value == null || value.isEmpty) throw StateError('Time zone unavailable');
  return value;
}
