import 'dart:math' as math;
import 'dart:typed_data';

import 'dsp.dart';

/// One analysis result, produced every hop (32 ms).
class VoiceFrame {
  const VoiceFrame({
    required this.rms,
    required this.level,
    required this.voiced,
    required this.pitchHz,
    this.vowelScores,
    this.vowel,
    this.hum = false,
    this.vocalizations = 0,
    this.syllables = 0,
  });

  static const silent = VoiceFrame(rms: 0, level: 0, voiced: false, pitchHz: 0);

  final double rms;

  /// 0..1 loudness above the room's noise (0 = silence, 1 = very loud).
  final double level;

  /// True when the child is making any sound above the noise gate: voice,
  /// hum, whisper, click or blow.
  final bool voiced;

  /// Smoothed fundamental frequency; 0 when unpitched.
  final double pitchHz;

  /// Fit error per vowel (smaller is closer), when the frame was clear.
  final Map<Vowel, double>? vowelScores;

  /// Best-fitting vowel, when [vowelScores] is present.
  final Vowel? vowel;

  /// True when the sound is a closed-mouth hum ("mmm").
  final bool hum;

  /// New vocalizations that started during this frame (usually 0 or 1).
  final int vocalizations;

  /// New syllable nuclei during this frame (usually 0 or 1). "ba-ba-ba"
  /// produces three; one long "aaah" produces one.
  final int syllables;

  bool get pitched => pitchHz > 0;

  /// 0 (low voice) .. 1 (high voice) on a fixed child-voice scale, 0.5 when
  /// unpitched. Used for colour and height, never for judging.
  double get pitchNorm {
    if (pitchHz <= 0) return 0.5;
    const lo = 5.0106; // ln(150 Hz)
    const hi = 6.3969; // ln(600 Hz)
    return ((math.log(pitchHz) - lo) / (hi - lo)).clamp(0.0, 1.0);
  }

  /// Loudness in dBFS, for the parent's report.
  double get db => dbfs(rms);
}

/// Streams mono samples into overlapping analysis windows and tracks the
/// child's vocalizations.
///
/// Everything adapts to the room: the noise gate follows a minimum-statistics
/// noise estimate, so a fan or TV doesn't count as the child, while the
/// parent's [sensitivity] (0.5..2.0) moves the gate for very quiet or very
/// loud children.
class VoiceAnalyzer {
  VoiceAnalyzer({this.sensitivity = 1.0});

  static const int window = 1024; // 64 ms at 16 kHz
  static const int hop = 512; // 32 ms
  static const int _block = 256; // 16 ms envelope blocks for onsets
  static const double hopSeconds = hop / kSampleRate;
  static const double _blockSeconds = _block / kSampleRate;

  /// A sound must last this long to count as a vocalization...
  static const double minVocalization = 0.15;

  /// ...and this much quiet ends one.
  static const double pauseToEnd = 0.25;

  /// Parent's mic sensitivity: 0.5 (needs louder voice) .. 2.0 (very soft).
  double sensitivity;

  /// While true, input is treated as silence (the app itself is speaking).
  bool muted = false;

  final classifier = VowelClassifier();
  final noise = NoiseFloor(frameSeconds: _blockSeconds);
  final _yin = YinPitchDetector();
  final _smooth = MedianSmoother(5);
  Float32List _buf = Float32List(window * 4);
  int _len = 0;
  int _unpitched = 0;
  double _lastPitch = 0;

  // Envelope (16 ms blocks) state for vocalization and syllable counting.
  final Float32List _blk = Float32List(_block);
  int _blkLen = 0;
  double _voicedRun = 0, _quietRun = 1;
  bool _counted = false;
  bool _sylHigh = false;
  double _sylPeak = -120, _sylValley = -120;
  int _pendingVocalizations = 0, _pendingSyllables = 0;

  /// Total vocalizations and syllables since creation (for tests and HUDs).
  int totalVocalizations = 0;
  int totalSyllables = 0;

  /// RMS below which input counts as silence.
  double get gateRms {
    final factor = (2.8 / sensitivity.clamp(0.5, 2.0)).clamp(1.5, 5.6);
    return math.max(noise.rmsLevel * factor, 0.0012);
  }

  /// Maps RMS to 0..1: 0 at the gate, 1 at 30 dB above it.
  double level(double r) {
    final g = gateRms;
    if (r <= g) return 0;
    return ((dbfs(r) - dbfs(g)) / 30).clamp(0.0, 1.0);
  }

  /// Adds samples and returns the frames completed by them (usually 0–2).
  List<VoiceFrame> add(Float32List samples) {
    _envelope(samples);
    if (_len + samples.length > _buf.length) {
      final bigger = Float32List(math.max(_buf.length * 2, _len + samples.length));
      bigger.setRange(0, _len, _buf);
      _buf = bigger;
    }
    _buf.setRange(_len, _len + samples.length, samples);
    _len += samples.length;
    final out = <VoiceFrame>[];
    var start = 0;
    while (_len - start >= window) {
      out.add(_analyze(Float32List.sublistView(_buf, start, start + window)));
      start += hop;
    }
    if (start > 0) {
      _buf.setRange(0, _len - start, _buf, start);
      _len -= start;
    }
    return out;
  }

  /// Runs the 16 ms envelope used for noise tracking and counting.
  void _envelope(Float32List samples) {
    var i = 0;
    while (i < samples.length) {
      final take = math.min(_block - _blkLen, samples.length - i);
      _blk.setRange(_blkLen, _blkLen + take, samples, i);
      _blkLen += take;
      i += take;
      if (_blkLen == _block) {
        _blkLen = 0;
        _onBlock(rms(_blk));
      }
    }
  }

  void _onBlock(double r) {
    if (muted) {
      _quiet();
      return;
    }
    noise.add(r);
    final sounding = r > gateRms;
    if (!sounding) {
      _quiet();
      return;
    }
    // Vocalization: a sound lasting minVocalization after a pause.
    _quietRun = 0;
    _voicedRun += _blockSeconds;
    if (!_counted && _voicedRun >= minVocalization) {
      _counted = true;
      _pendingVocalizations++;
      totalVocalizations++;
    }
    // Syllable nuclei: a rise of 6 dB from the last valley, ended by a fall
    // of 6 dB from the peak (consonant closures make those dips).
    final e = dbfs(r);
    if (_sylHigh) {
      _sylPeak = math.max(_sylPeak, e);
      if (e <= _sylPeak - 6) {
        _sylHigh = false;
        _sylValley = e;
      }
    } else {
      _sylValley = math.min(_sylValley, e);
      if (e - _sylValley >= 6) {
        _sylHigh = true;
        _sylPeak = e;
        _pendingSyllables++;
        totalSyllables++;
      }
    }
  }

  void _quiet() {
    _quietRun += _blockSeconds;
    if (_quietRun >= pauseToEnd) {
      _counted = false;
      _voicedRun = 0;
    }
    _sylHigh = false;
    _sylValley = -120;
  }

  VoiceFrame _analyze(Float32List w) {
    final vocal = _pendingVocalizations, syl = _pendingSyllables;
    _pendingVocalizations = 0;
    _pendingSyllables = 0;
    final r = rms(w);
    final lvl = muted ? 0.0 : level(r);
    if (lvl <= 0) {
      _smooth.reset();
      _lastPitch = 0;
      return VoiceFrame(rms: r, level: 0, voiced: false, pitchHz: 0, vocalizations: vocal, syllables: syl);
    }
    final p = _yin.detect(w);
    var hz = 0.0;
    if (p.voiced) {
      hz = _smooth.add(p.hz);
      _unpitched = 0;
      _lastPitch = hz;
    } else if (++_unpitched <= 2) {
      hz = _lastPitch; // bridge short dropouts so colours don't flicker
    }
    Map<Vowel, double>? scores;
    var hum = false;
    if (p.voiced && p.clarity > 0.6) {
      classifier.observePitch(p.hz);
      final h = HarmonicSpectrum.measure(w, p.hz);
      if (h != null) {
        scores = classifier.score(h);
        // "ee" is also quiet between 1 and 2.5 kHz; never call it a hum.
        hum = h.isHum && (scores == null || VowelClassifier.best(scores) != Vowel.ee);
      }
    }
    return VoiceFrame(
      rms: r,
      level: lvl,
      voiced: true,
      pitchHz: hz,
      vowelScores: scores,
      vowel: scores == null ? null : VowelClassifier.best(scores),
      hum: hum,
      vocalizations: vocal,
      syllables: syl,
    );
  }
}
