import 'dart:convert';

import 'package:hive_flutter/hive_flutter.dart';

abstract interface class CouplesCache {
  Future<Map<String, dynamic>?> read(int accountId);
  Future<void> write(int accountId, Map<String, dynamic> value);
  Future<void> remove(int accountId);
}

class HiveCouplesCache implements CouplesCache {
  HiveCouplesCache({this.boxName = 'couples_overview_v1'});
  final String boxName;
  Future<Box<String>> _box() => Hive.openBox<String>(boxName);

  @override
  Future<Map<String, dynamic>?> read(int accountId) async {
    final raw = (await _box()).get('account:$accountId');
    if (raw == null) return null;
    return jsonDecode(raw) as Map<String, dynamic>;
  }

  @override
  Future<void> write(int accountId, Map<String, dynamic> value) async {
    await (await _box()).put('account:$accountId', jsonEncode(value));
  }

  @override
  Future<void> remove(int accountId) async {
    await (await _box()).delete('account:$accountId');
  }
}
