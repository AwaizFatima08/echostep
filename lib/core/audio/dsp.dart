import 'dart:math' as math;
import 'dart:typed_data';

/// Signal-processing building blocks. Pure Dart with no Flutter imports, so
/// every piece is unit-testable from synthetic voices on a machine with no
/// microphone.
///
/// Pitch (YIN) and the harmonic-fit vowel method come from Sound Painter,
/// where they are field-tested; the vowel set and the hum detector are
/// EchoSteps' own.

const int kSampleRate = 16000;

/// Root-mean-square level of [x] (samples in -1..1).
double rms(Float32List x, [int start = 0, int? end]) {
  end ??= x.length;
  if (end <= start) return 0;
  var sum = 0.0;
  for (var i = start; i < end; i++) {
    sum += x[i] * x[i];
  }
  return math.sqrt(sum / (end - start));
}

/// RMS in dB relative to full scale; -120 for silence.
double dbfs(double r) => r <= 1e-6 ? -120 : 20 * math.log(r) / math.ln10;

/// Converts little-endian PCM16 bytes to floats in -1..1, respecting the
/// view's offset and length.
Float32List pcm16ToFloat(Uint8List bytes) {
  final n = bytes.lengthInBytes ~/ 2;
  final data = ByteData.sublistView(bytes, 0, n * 2);
  final out = Float32List(n);
  for (var i = 0; i < n; i++) {
    out[i] = data.getInt16(i * 2, Endian.little) / 32768.0;
  }
  return out;
}

class PitchResult {
  const PitchResult(this.hz, this.clarity);

  /// Fundamental frequency, or 0 when the frame isn't clearly pitched.
  final double hz;

  /// 1 - aperiodicity; near 1 for clean voiced sound.
  final double clarity;

  bool get voiced => hz > 0;
}

/// YIN pitch detector (de Cheveigné & Kawahara, 2002) with parabolic
/// interpolation. Unlike plain autocorrelation it doesn't favour small lags,
/// so it avoids octave errors on children's high voices.
class YinPitchDetector {
  YinPitchDetector({this.sampleRate = kSampleRate, this.minHz = 70, this.maxHz = 1100, this.threshold = 0.2});

  final int sampleRate;
  final double minHz;
  final double maxHz;
  final double threshold;

  Float64List _d = Float64List(0);

  PitchResult detect(Float32List x) {
    final tauMin = (sampleRate / maxHz).floor().clamp(2, x.length);
    final tauMax = math.min((sampleRate / minHz).ceil(), x.length ~/ 2);
    if (tauMax <= tauMin + 2) return const PitchResult(0, 0);
    if (_d.length < tauMax + 1) _d = Float64List(tauMax + 1);
    final d = _d;
    final w = x.length - tauMax;

    for (var tau = 1; tau <= tauMax; tau++) {
      var sum = 0.0;
      for (var i = 0; i < w; i++) {
        final diff = x[i] - x[i + tau];
        sum += diff * diff;
      }
      d[tau] = sum;
    }
    d[0] = 1;
    var running = 0.0;
    for (var tau = 1; tau <= tauMax; tau++) {
      running += d[tau];
      d[tau] = running == 0 ? 1 : d[tau] * tau / running;
    }
    var best = -1;
    for (var tau = tauMin; tau <= tauMax; tau++) {
      if (d[tau] < threshold) {
        while (tau + 1 <= tauMax && d[tau + 1] < d[tau]) {
          tau++;
        }
        best = tau;
        break;
      }
    }
    if (best == -1) {
      var minV = double.infinity;
      for (var tau = tauMin; tau <= tauMax; tau++) {
        if (d[tau] < minV) minV = d[tau];
      }
      return PitchResult(0, (1 - minV).clamp(0.0, 1.0));
    }
    var refined = best.toDouble();
    if (best > 1 && best < tauMax) {
      final a = d[best - 1], b = d[best], c = d[best + 1];
      final denom = a - 2 * b + c;
      if (denom.abs() > 1e-12) refined = best + 0.5 * (a - c) / denom;
    }
    return PitchResult(sampleRate / refined, (1 - d[best]).clamp(0.0, 1.0));
  }
}

/// Level (dB) of each harmonic of a known pitch, up to [maxHz].
///
/// Children's voices are high, so their harmonics are spaced too widely for
/// LPC formant tracking. Sampling the spectrum exactly at the harmonics and
/// fitting resonance curves to those points works at any pitch.
class HarmonicSpectrum {
  HarmonicSpectrum._(this.f0, this.freqs, this.db);

  final double f0;
  final List<double> freqs;
  final List<double> db;

  static const double maxHz = 4000;

  static HarmonicSpectrum? measure(Float32List x, double f0, {int sampleRate = kSampleRate}) {
    if (f0 <= 0) return null;
    final n = x.length;
    final win = Float64List(n);
    for (var i = 0; i < n; i++) {
      win[i] = x[i] * (0.5 - 0.5 * math.cos(2 * math.pi * i / (n - 1)));
    }
    final freqs = <double>[];
    final db = <double>[];
    for (var k = 1; k * f0 <= maxHz; k++) {
      final f = k * f0;
      final w = 2 * math.pi * f / sampleRate;
      // Goertzel-style single-bin DFT via a rotating phasor.
      final cw = math.cos(w), sw = math.sin(w);
      var c = 1.0, s = 0.0, re = 0.0, im = 0.0;
      for (var i = 0; i < n; i++) {
        re += win[i] * c;
        im -= win[i] * s;
        final nc = c * cw - s * sw;
        s = s * cw + c * sw;
        c = nc;
      }
      freqs.add(f);
      db.add(10 * math.log(re * re + im * im + 1e-12) / math.ln10);
    }
    return HarmonicSpectrum._(f0, freqs, db);
  }

  /// Loudest harmonic (dB) with frequency in [lo, hi); null when none.
  double? peakIn(double lo, double hi) {
    double? best;
    for (var i = 0; i < freqs.length; i++) {
      if (freqs[i] >= lo && freqs[i] < hi && (best == null || db[i] > best)) best = db[i];
    }
    return best;
  }

  /// True for a closed-mouth hum ("mmm"): a nasal murmur puts nearly all its
  /// energy below 600 Hz (typically 30+ dB above everything else) and, unlike
  /// "ee" (also quiet between 1 and 2.5 kHz), has no high resonance peak.
  bool get isHum {
    final low = peakIn(0, 600);
    final mid = peakIn(900, 2400);
    final top = peakIn(2400, 3800);
    if (low == null || mid == null) return false;
    final rest = top == null ? mid : math.max(mid, top);
    final hasHighFormant = top != null && top > mid + 3;
    return low - rest >= 30 && !hasHighFormant;
  }
}

/// The four corner vowels Echo Safari models. They are the first vowels
/// children imitate, and their mouth shapes are clearly different to see.
enum Vowel { ah, oh, oo, ee }

/// Recognises [Vowel]s by fitting each vowel's resonance curve to the
/// measured harmonics (analysis by synthesis), allowing any overall level
/// and spectral tilt.
///
/// Centroids are children's means from Peterson & Barney (1952). Adult vocal
/// tracts are longer, so their formants sit ~20% lower; [scale] compensates,
/// derived from the speaker's typical pitch (a steady cue that can't drift
/// toward whichever vowel a child keeps repeating).
class VowelClassifier {
  /// Children's (F1, F2) in Hz.
  static const Map<Vowel, (double, double)> childCentroids = {
    Vowel.ah: (1030, 1370), // ɑ  "aah"
    Vowel.oh: (660, 1060), //  o/ɔ "oh"
    Vowel.oo: (430, 1170), //  u  "ooo"
    Vowel.ee: (370, 3200), //  i  "eee"
  };

  final int sampleRate;
  VowelClassifier({this.sampleRate = kSampleRate});

  /// Divides the centroids' frequencies to match the speaker (child 1.0,
  /// adult up to 1.25).
  double scale = 1.0;
  double _f0Log = math.log(280);

  void observePitch(double hz) {
    if (hz <= 0) return;
    _f0Log += 0.05 * (math.log(hz) - _f0Log);
    final t = ((_f0Log - math.log(130)) / (math.log(250) - math.log(130))).clamp(0.0, 1.0);
    scale = 1.25 - 0.25 * t;
  }

  /// Fit error per vowel; smaller is closer. Null with too few harmonics.
  Map<Vowel, double>? score(HarmonicSpectrum h) {
    if (h.freqs.length < 5) return null;
    final logF = [for (final f in h.freqs) math.log(f) / math.ln2];
    return {
      for (final e in childCentroids.entries)
        e.key: _fitError(h.db, logF, [
          for (final f in h.freqs)
            _modelDb(f, e.value.$1 / scale, e.value.$2 / scale, math.max(3500.0, e.value.$2 + 500) / scale),
        ]),
    };
  }

  static double _fitError(List<double> m, List<double> x, List<double> model) {
    final n = m.length;
    var sx = 0.0, sy = 0.0, sxx = 0.0, sxy = 0.0;
    final y = List<double>.generate(n, (i) => m[i] - model[i]);
    for (var i = 0; i < n; i++) {
      sx += x[i];
      sy += y[i];
      sxx += x[i] * x[i];
      sxy += x[i] * y[i];
    }
    final den = n * sxx - sx * sx;
    final b = den.abs() < 1e-9 ? 0.0 : (n * sxy - sx * sy) / den;
    final a = (sy - b * sx) / n;
    var err = 0.0;
    for (var i = 0; i < n; i++) {
      final r = y[i] - a - b * x[i];
      err += r * r;
    }
    return math.sqrt(err / n);
  }

  double _modelDb(double f, double f1, double f2, double f3) {
    var db = 0.0;
    for (final (fc, bw) in [(f1, 110.0), (f2, 150.0), (f3, 220.0)]) {
      db += _resonatorDb(f, fc, bw);
    }
    return db;
  }

  double _resonatorDb(double f, double fc, double bw) {
    final r = math.exp(-math.pi * bw / sampleRate);
    final th = 2 * math.pi * fc / sampleRate;
    final w = 2 * math.pi * f / sampleRate;
    final re = 1 - 2 * r * math.cos(th) * math.cos(w) + r * r * math.cos(2 * w);
    final im = 2 * r * math.cos(th) * math.sin(w) - r * r * math.sin(2 * w);
    final re0 = 1 - 2 * r * math.cos(th) + r * r;
    return 10 * math.log(re0 * re0 / (re * re + im * im)) / math.ln10;
  }

  static Vowel best(Map<Vowel, double> scores) => scores.entries.reduce((a, b) => a.value <= b.value ? a : b).key;

  /// Generous match for errorless practice: the target counts when it's the
  /// best fit or within [toleranceDb] of it.
  static bool matches(Map<Vowel, double> scores, Vowel target, {double toleranceDb = 1.0}) {
    final top = scores.values.reduce(math.min);
    return scores[target]! <= top + toleranceDb;
  }
}

/// Median of the last [size] values; steadies pitch readings.
class MedianSmoother {
  MedianSmoother([this.size = 5]);
  final int size;
  final List<double> _v = [];

  double add(double x) {
    _v.add(x);
    if (_v.length > size) _v.removeAt(0);
    final s = [..._v]..sort();
    return s[s.length ~/ 2];
  }

  void reset() => _v.clear();
}

/// Background-noise estimate by minimum statistics (Martin, 2001): the
/// quietest frame level over the last few seconds. It follows a fan or TV
/// switching on within [windowSeconds], yet a child's vocalization (with
/// breaths between) never raises it, because the quiet gaps set the minimum.
class NoiseFloor {
  NoiseFloor({this.windowSeconds = 6, this.frameSeconds = 0.032, double initialRms = 0.003})
    : _blockFrames = math.max(1, (0.5 / frameSeconds).round()),
      _blocks = List<double>.filled(math.max(2, (windowSeconds / 0.5).round()), initialRms),
      _current = initialRms;

  final double windowSeconds;
  final double frameSeconds;
  final int _blockFrames;
  final List<double> _blocks;
  int _blockIndex = 0;
  int _inBlock = 0;
  double _blockMin = double.infinity;
  double _current;
  bool _primed = false;

  /// Current noise estimate (RMS). Never below a tiny absolute floor, so a
  /// digitally silent input can't make the gate hair-trigger.
  double get rmsLevel => math.max(_current, 0.0008);

  void add(double frameRms) {
    if (!_primed) {
      // Start from the room as it is, not a guess.
      _primed = true;
      _blocks.fillRange(0, _blocks.length, frameRms);
      _current = frameRms;
    }
    if (frameRms < _blockMin) _blockMin = frameRms;
    // Drop quickly when it gets quieter.
    if (frameRms < _current) _current = frameRms;
    if (++_inBlock >= _blockFrames) {
      _blocks[_blockIndex] = _blockMin;
      _blockIndex = (_blockIndex + 1) % _blocks.length;
      _inBlock = 0;
      _blockMin = double.infinity;
      _current = _blocks.reduce(math.min);
    }
  }
}
