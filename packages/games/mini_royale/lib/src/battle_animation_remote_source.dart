import 'dart:typed_data';

abstract interface class BattleAnimationRemoteSource {
  Future<Uint8List?> download(Uri uri);
  void dispose();
}
