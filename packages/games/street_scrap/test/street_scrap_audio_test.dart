import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:taiwan_brawl_game_street_scrap/src/street_scrap_audio.dart';

void main() {
  test('all sound cues have small, valid local PCM wave assets', () {
    for (final cue in StreetScrapAudioCue.values) {
      final file = File('assets/audio/${cue.assetName}.wav');
      expect(file.existsSync(), isTrue, reason: cue.name);
      final bytes = file.readAsBytesSync();
      expect(bytes.length, greaterThan(44), reason: cue.name);
      expect(bytes.length, lessThan(64 * 1024), reason: cue.name);
      expect(String.fromCharCodes(bytes.sublist(0, 4)), 'RIFF');
      expect(String.fromCharCodes(bytes.sublist(8, 12)), 'WAVE');
      expect(String.fromCharCodes(bytes.sublist(12, 16)), 'fmt ');
      expect(String.fromCharCodes(bytes.sublist(36, 40)), 'data');
      expect(bytes[20], 1, reason: 'PCM encoding for ${cue.name}');
      expect(bytes[22], 1, reason: 'mono audio for ${cue.name}');
      expect(bytes[24], 0x22, reason: '22050 Hz for ${cue.name}');
      expect(bytes[25], 0x56, reason: '22050 Hz for ${cue.name}');
      expect(bytes.sublist(44).any((sample) => sample != 0), isTrue);
    }
  });
}
