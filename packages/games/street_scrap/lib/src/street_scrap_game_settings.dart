/// Per-game accessibility preferences, persisted in this game's local save.
class StreetScrapGameSettings {
  const StreetScrapGameSettings({
    this.textScale = 1,
    this.reduceMotion = false,
    this.assistedControls = false,
    this.soundVolume = 100,
  });

  final double textScale;
  final bool reduceMotion;
  final bool assistedControls;
  final int soundVolume;

  factory StreetScrapGameSettings.fromJson(Object? value) {
    if (value == null) return const StreetScrapGameSettings();
    if (value is! Map) {
      throw const FormatException('街角拾荒設定資料格式錯誤。');
    }
    final scale = value['textScale'];
    final reduceMotion = value['reduceMotion'];
    final assistedControls = value['assistedControls'];
    final soundVolume = value['soundVolume'];
    if (scale is! num ||
        scale < 1 ||
        scale > 2 ||
        ((scale * 4).roundToDouble() - scale * 4).abs() > 0.001 ||
        reduceMotion is! bool ||
        assistedControls is! bool ||
        soundVolume is! int ||
        soundVolume < 0 ||
        soundVolume > 100) {
      throw const FormatException('街角拾荒設定值無效。');
    }
    return StreetScrapGameSettings(
      textScale: scale.toDouble(),
      reduceMotion: reduceMotion,
      assistedControls: assistedControls,
      soundVolume: soundVolume,
    );
  }

  Map<String, Object?> toJson() => {
    'textScale': textScale,
    'reduceMotion': reduceMotion,
    'assistedControls': assistedControls,
    'soundVolume': soundVolume,
  };
}
