import 'package:hive_flutter/hive_flutter.dart';
import 'package:taiwan_brawl_game_archery/taiwan_brawl_game_archery.dart';

/// App-owned Hive adapter for the Archery package's player-data contract.
class HiveArcheryPlayerDataBackend implements ArcheryPlayerDataBackend {
  HiveArcheryPlayerDataBackend({this.boxName = 'archery_player_data_v1'});

  final String boxName;
  Future<Box<dynamic>> get _box => Hive.openBox<dynamic>(boxName);

  @override
  Future<Object?> read(String key) async => (await _box).get(key);

  @override
  Future<void> write(String key, Object value) async =>
      (await _box).put(key, value);

  @override
  Future<void> delete(String key) async => (await _box).delete(key);
}
