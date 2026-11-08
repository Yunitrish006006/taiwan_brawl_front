import 'package:audioplayers/audioplayers.dart';

enum StreetScrapAudioCue {
  tap('scrap_tap'),
  pickup('scrap_pickup'),
  success('scrap_success'),
  discovery('scrap_discovery'),
  miss('scrap_miss');

  const StreetScrapAudioCue(this.assetName);

  final String assetName;
}

/// Local, optional feedback sounds. Playback failures never affect gameplay.
class StreetScrapAudio {
  StreetScrapAudio._(this._pools);

  static const _assetPrefix =
      'packages/taiwan_brawl_game_street_scrap/assets/audio/';

  final Map<StreetScrapAudioCue, AudioPool> _pools;
  bool _disposed = false;

  static Future<StreetScrapAudio?> create() async {
    final cache = AudioCache(prefix: _assetPrefix);
    final pools = <StreetScrapAudioCue, AudioPool>{};
    try {
      for (final cue in StreetScrapAudioCue.values) {
        pools[cue] = await AudioPool.createFromAsset(
          path: '${cue.assetName}.wav',
          maxPlayers: 2,
          audioCache: cache,
        );
      }
      return StreetScrapAudio._(pools);
    } on Object {
      for (final pool in pools.values) {
        await pool.dispose();
      }
      return null;
    }
  }

  Future<void> play(StreetScrapAudioCue cue, int volume) async {
    if (_disposed || volume <= 0) return;
    final pool = _pools[cue];
    if (pool == null) return;
    try {
      await pool.start(volume: volume.clamp(0, 100) / 100);
    } on Object {
      // Audio is presentation-only: unsupported devices remain fully playable.
    }
  }

  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    for (final pool in _pools.values) {
      try {
        await pool.dispose();
      } on Object {
        // Dispose best-effort so one platform failure does not leak the rest.
      }
    }
  }
}
