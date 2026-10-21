/// Durable storage boundary for Mini Royale's optional animation cache.
abstract interface class BattleAnimationCacheStore {
  Future<void> initialize();
  Future<bool> readEnabled();
  Future<void> writeEnabled(bool value);
  bool containsBytes(String cacheKey);
  String? readBytes(String cacheKey);
  Future<void> writeBytes(String cacheKey, String encodedBytes);
  Future<void> deleteBytes(String cacheKey);
  String? readMeta(String identity);
  Future<void> writeMeta(String identity, String encodedMeta);
  Future<void> deleteMeta(String identity);
}
