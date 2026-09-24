import 'dart:math' as math;
import 'dart:typed_data';

import 'dsp.dart';

/// Klatt-style cascade formant synthesiser. Produces child-like vowels and
/// hums so the whole voice pipeline can be exercised without a microphone:
/// in unit tests, integration tests and the emulator.
class SynthVoice {
  SynthVoice({this.sampleRate = kSampleRate, int seed = 7}) : _rand = math.Random(seed);

  final int sampleRate;
  final math.Random _rand;
  double _phase = 0;

  /// Renders [seconds] of a vowel at [f0] Hz with formants [f1]/[f2]/[f3].
  /// [amp] is the peak level (0..1). [f0End] makes a glide.
  Float32List vowel({
    required double seconds,
    required double f0,
    double? f0End,
    double f1 = 1000,
    double f2 = 2300,
    double f3 = 3500,
    double amp = 0.3,
  }) {
    final n = (seconds * sampleRate).round();
    final out = Float32List(n);
    final res = [_Resonator(f1, 90, sampleRate), _Resonator(f2, 120, sampleRate), _Resonator(f3, 180, sampleRate)];
    for (var i = 0; i < n; i++) {
      final t = i / n;
      final f = f0End == null ? f0 : f0 * math.pow(f0End / f0, t);
      final vib = 1 + 0.01 * math.sin(2 * math.pi * 5 * i / sampleRate);
      _phase += f * vib / sampleRate;
      // Band-limited glottal source (-12 dB/octave) plus lip radiation
      // (+6 dB/octave): the -6 dB/octave slope a microphone hears.
      var src = 0.0;
      final kMax = (0.45 * sampleRate / f).floor();
      for (var k = 1; k <= kMax; k++) {
        src += math.sin(2 * math.pi * k * _phase) / k;
      }
      src += (_rand.nextDouble() - 0.5) * 0.01;
      var y = src;
      for (final r in res) {
        y = r.process(y);
      }
      out[i] = y;
    }
    // Normalise and apply short fades.
    var peak = 0.0;
    for (final v in out) {
      peak = math.max(peak, v.abs());
    }
    final g = peak > 0 ? amp / peak : 0.0;
    final fade = (0.02 * sampleRate).round();
    for (var i = 0; i < n; i++) {
      final e = math.min(1.0, math.min(i, n - 1 - i) / fade);
      out[i] *= g * e;
    }
    return out;
  }

  /// A child holding one of the four corner vowels.
  Float32List childVowel(Vowel v, {double seconds = 1.5, double f0 = 290, double amp = 0.3}) {
    final (f1, f2) = VowelClassifier.childCentroids[v]!;
    return vowel(seconds: seconds, f0: f0, f1: f1, f2: f2, f3: f2 > 2500 ? 3800 : 3600, amp: amp);
  }

  /// A closed-mouth hum ("mmm"): a nasal murmur with a strong resonance near
  /// 270 Hz and almost nothing above 1 kHz.
  Float32List hum({double seconds = 1.5, double f0 = 280, double amp = 0.25}) {
    final raw = vowel(seconds: seconds, f0: f0, f1: 270, f2: 1100, f3: 2400, amp: 1);
    // Two one-pole low-passes at ~350 Hz model the nasal antiresonance.
    final a = math.exp(-2 * math.pi * 350 / sampleRate);
    for (var pass = 0; pass < 2; pass++) {
      var y = 0.0;
      for (var i = 0; i < raw.length; i++) {
        y = (1 - a) * raw[i] + a * y;
        raw[i] = y;
      }
    }
    var peak = 0.0;
    for (final v in raw) {
      peak = math.max(peak, v.abs());
    }
    for (var i = 0; i < raw.length; i++) {
      raw[i] *= amp / peak;
    }
    return raw;
  }

  /// Reduplicated babbling ("ba-ba-ba"): [count] short open syllables, each
  /// with a consonant closure (a near-silent dip) before it.
  Float32List babble({int count = 3, double f0 = 300, double amp = 0.3, Vowel v = Vowel.ah}) {
    final parts = <Float32List>[];
    for (var i = 0; i < count; i++) {
      parts.add(silence(0.09, noise: 0.0015));
      parts.add(childVowel(v, seconds: 0.22, f0: f0 * (1 + 0.04 * (i % 2)), amp: amp));
    }
    return concat(parts);
  }

  Float32List silence(double seconds, {double noise = 0.001}) {
    final out = Float32List((seconds * sampleRate).round());
    for (var i = 0; i < out.length; i++) {
      out[i] = (_rand.nextDouble() - 0.5) * 2 * noise;
    }
    return out;
  }

  static Float32List concat(List<Float32List> parts) {
    final out = Float32List(parts.fold(0, (s, p) => s + p.length));
    var o = 0;
    for (final p in parts) {
      out.setRange(o, o + p.length, p);
      o += p.length;
    }
    return out;
  }
}

class _Resonator {
  _Resonator(double f, double bw, int sr) {
    final r = math.exp(-math.pi * bw / sr);
    _b1 = 2 * r * math.cos(2 * math.pi * f / sr);
    _b2 = -r * r;
    _a = 1 - _b1 - _b2;
  }

  late final double _a, _b1, _b2;
  double _y1 = 0, _y2 = 0;

  double process(double x) {
    final y = _a * x + _b1 * _y1 + _b2 * _y2;
    _y2 = _y1;
    _y1 = y;
    return y;
  }
}
