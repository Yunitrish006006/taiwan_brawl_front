import 'package:hive_flutter/hive_flutter.dart';

/// Platform storage bootstrap boundary owned by the composition root.
abstract interface class LocalStorageRuntime {
  Future<void> initialize();
}

/// Initializes Hive for the existing local-storage adapters.
class HiveStorageRuntime implements LocalStorageRuntime {
  @override
  Future<void> initialize() async {
    await Hive.initFlutter();
  }
}
