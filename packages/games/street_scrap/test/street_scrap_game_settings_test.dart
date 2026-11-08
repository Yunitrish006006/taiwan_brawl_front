import 'package:flutter_test/flutter_test.dart';
import 'package:taiwan_brawl_game_street_scrap/src/street_scrap_game_settings.dart';

void main() {
  test('settings default safely and round-trip per-game preferences', () {
    expect(StreetScrapGameSettings.fromJson(null).toJson(), {
      'textScale': 1.0,
      'reduceMotion': false,
      'assistedControls': false,
      'soundVolume': 100,
    });
    const settings = StreetScrapGameSettings(
      textScale: 1.5,
      reduceMotion: true,
      assistedControls: true,
      soundVolume: 35,
    );
    expect(
      StreetScrapGameSettings.fromJson(settings.toJson()).toJson(),
      settings.toJson(),
    );
  });

  test('invalid or unsupported preference values fail closed', () {
    expect(
      () => StreetScrapGameSettings.fromJson({
        'textScale': 2.25,
        'reduceMotion': false,
        'assistedControls': false,
        'soundVolume': 100,
      }),
      throwsFormatException,
    );
    expect(
      () => StreetScrapGameSettings.fromJson({
        'textScale': 1,
        'reduceMotion': false,
        'assistedControls': false,
        'soundVolume': 101,
      }),
      throwsFormatException,
    );
  });
}
