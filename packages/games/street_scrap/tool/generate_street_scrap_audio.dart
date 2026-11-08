import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

const _sampleRate = 22050;

void main() {
  final output = Directory('assets/audio')..createSync(recursive: true);
  for (final cue in _cues) {
    final samples = _synthesize(cue);
    File('${output.path}/${cue.name}.wav').writeAsBytesSync(_wave(samples));
  }
  stdout.writeln('Generated ${_cues.length} offline Street Scrap sound cues.');
}

const _cues = <_Cue>[
  _Cue('scrap_tap', 70, [1500], noise: true),
  _Cue('scrap_pickup', 130, [710, 1065]),
  _Cue('scrap_success', 340, [523.25, 659.25, 783.99]),
  _Cue('scrap_discovery', 300, [587.33, 880]),
  _Cue('scrap_miss', 240, [392, 293.66]),
];

class _Cue {
  const _Cue(
    this.name,
    this.durationMs,
    this.frequencies, {
    this.noise = false,
  });

  final String name;
  final int durationMs;
  final List<double> frequencies;
  final bool noise;
}

List<int> _synthesize(_Cue cue) {
  final length = (_sampleRate * cue.durationMs / 1000).round();
  var noiseState = 0x2f6e2b1;
  return List<int>.generate(length, (index) {
    final t = index / _sampleRate;
    final progress = t / (cue.durationMs / 1000);
    final envelope = math.pow(math.max(0, 1 - progress), cue.noise ? 7 : 2.4);
    var value = 0.0;
    for (var note = 0; note < cue.frequencies.length; note++) {
      final onset = cue.frequencies.length == 1 ? 0.0 : note * 0.075;
      final localTime = math.max(0, t - onset);
      final noteEnvelope = math.exp(-localTime * (cue.noise ? 40 : 5.2));
      value +=
          math.sin(2 * math.pi * cue.frequencies[note] * localTime) *
          noteEnvelope;
    }
    if (cue.noise) {
      noiseState = (noiseState * 1103515245 + 12345) & 0x7fffffff;
      final noise = noiseState / 0x3fffffff - 1;
      value = value * 0.25 + noise * 0.75;
    }
    final amplitude = (value * envelope * 0.32).clamp(-0.85, 0.85);
    return (amplitude * 32767).round();
  });
}

Uint8List _wave(List<int> samples) {
  final bytes = ByteData(44 + samples.length * 2);
  void writeAscii(int offset, String value) {
    for (var i = 0; i < value.length; i++) {
      bytes.setUint8(offset + i, value.codeUnitAt(i));
    }
  }

  writeAscii(0, 'RIFF');
  bytes.setUint32(4, 36 + samples.length * 2, Endian.little);
  writeAscii(8, 'WAVE');
  writeAscii(12, 'fmt ');
  bytes.setUint32(16, 16, Endian.little);
  bytes.setUint16(20, 1, Endian.little);
  bytes.setUint16(22, 1, Endian.little);
  bytes.setUint32(24, _sampleRate, Endian.little);
  bytes.setUint32(28, _sampleRate * 2, Endian.little);
  bytes.setUint16(32, 2, Endian.little);
  bytes.setUint16(34, 16, Endian.little);
  writeAscii(36, 'data');
  bytes.setUint32(40, samples.length * 2, Endian.little);
  for (var i = 0; i < samples.length; i++) {
    bytes.setInt16(44 + i * 2, samples[i], Endian.little);
  }
  return bytes.buffer.asUint8List();
}
