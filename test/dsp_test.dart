import 'dart:math' as math;
import 'dart:typed_data';

import 'package:echosteps/core/audio/dsp.dart';
import 'package:echosteps/core/audio/synth_voice.dart';
import 'package:echosteps/core/audio/voice_analyzer.dart';
import 'package:flutter_test/flutter_test.dart';

Float32List tone(double hz, double seconds, {double amp = 0.3}) {
  final n = (seconds * kSampleRate).round();
  return Float32List.fromList([for (var i = 0; i < n; i++) amp * math.sin(2 * math.pi * hz * i / kSampleRate)]);
}

/// Feeds [x] in 512-sample chunks and returns all frames.
List<VoiceFrame> run(VoiceAnalyzer a, Float32List x) {
  final out = <VoiceFrame>[];
  for (var i = 0; i < x.length; i += 512) {
    out.addAll(a.add(Float32List.sublistView(x, i, math.min(i + 512, x.length))));
  }
  return out;
}

/// Fraction of scored frames whose best vowel is [v].
double vowelHitRate(List<VoiceFrame> frames, Vowel v) {
  final scored = frames.where((f) => f.vowel != null).toList();
  if (scored.isEmpty) return 0;
  return scored.where((f) => f.vowel == v).length / scored.length;
}

void main() {
  group('YIN pitch', () {
    for (final hz in [110.0, 220.0, 330.0, 480.0, 800.0]) {
      test('pure tone $hz Hz', () {
        final p = YinPitchDetector().detect(Float32List.sublistView(tone(hz, 0.2), 0, 1024));
        expect(p.hz, closeTo(hz, hz * 0.01));
      });
    }

    test('synthetic child vowel at 300 Hz has no octave error', () {
      final x = SynthVoice().childVowel(Vowel.ah, seconds: 0.3, f0: 300);
      final p = YinPitchDetector().detect(Float32List.sublistView(x, 2000, 3024));
      expect(p.hz, closeTo(300, 6));
    });

    test('noise is unpitched', () {
      final r = math.Random(1);
      final x = Float32List.fromList([for (var i = 0; i < 1024; i++) (r.nextDouble() - 0.5) * 0.4]);
      expect(YinPitchDetector().detect(x).voiced, isFalse);
    });
  });

  group('vowels', () {
    for (final v in Vowel.values) {
      for (final f0 in [250.0, 320.0]) {
        test('child ${v.name} at $f0 Hz is recognised', () {
          final a = VoiceAnalyzer();
          final s = SynthVoice(seed: 11);
          final frames = run(a, SynthVoice.concat([s.silence(0.5), s.childVowel(v, seconds: 2, f0: f0)]));
          expect(vowelHitRate(frames, v), greaterThan(0.6), reason: '${v.name} @ $f0');
        });
      }
    }
  });

  group('hum', () {
    test('a hum is detected as a hum', () {
      final s = SynthVoice(seed: 2);
      final frames = run(VoiceAnalyzer(), SynthVoice.concat([s.silence(0.5), s.hum(seconds: 2)]));
      final voiced = frames.where((f) => f.voiced).toList();
      expect(voiced.where((f) => f.hum).length / voiced.length, greaterThan(0.7));
    });

    for (final v in Vowel.values) {
      test('open vowel ${v.name} is not a hum', () {
        final s = SynthVoice(seed: 4);
        final frames = run(VoiceAnalyzer(), SynthVoice.concat([s.silence(0.5), s.childVowel(v, seconds: 2)]));
        final voiced = frames.where((f) => f.voiced).toList();
        expect(voiced.where((f) => f.hum).length / voiced.length, lessThan(0.2), reason: v.name);
      });
    }
  });

  group('counting', () {
    test('one long aaah is one vocalization and one syllable', () {
      final s = SynthVoice(seed: 5);
      final a = VoiceAnalyzer();
      run(a, SynthVoice.concat([s.silence(0.6), s.childVowel(Vowel.ah, seconds: 2.5), s.silence(0.6)]));
      expect(a.totalVocalizations, 1);
      expect(a.totalSyllables, 1);
    });

    test('three separate sounds are three vocalizations', () {
      final s = SynthVoice(seed: 6);
      final a = VoiceAnalyzer();
      run(
        a,
        SynthVoice.concat([
          s.silence(0.6),
          for (var i = 0; i < 3; i++) ...[s.childVowel(Vowel.oo, seconds: 0.6), s.silence(0.5)],
        ]),
      );
      expect(a.totalVocalizations, 3);
    });

    test('ba-ba-ba-ba babble is four syllables but one vocalization', () {
      final s = SynthVoice(seed: 7);
      final a = VoiceAnalyzer();
      run(a, SynthVoice.concat([s.silence(0.6), s.babble(count: 4), s.silence(0.6)]));
      expect(a.totalSyllables, 4);
      expect(a.totalVocalizations, 1);
    });

    test('a 60 ms click is not a vocalization', () {
      final s = SynthVoice(seed: 8);
      final a = VoiceAnalyzer();
      run(a, SynthVoice.concat([s.silence(0.6), s.childVowel(Vowel.ah, seconds: 0.06), s.silence(0.6)]));
      expect(a.totalVocalizations, 0);
    });
  });

  group('noise gate', () {
    test('steady room noise is silence after it adapts', () {
      final r = math.Random(3);
      final noise = Float32List.fromList([for (var i = 0; i < kSampleRate * 10; i++) (r.nextDouble() - 0.5) * 0.02]);
      final a = VoiceAnalyzer();
      final frames = run(a, noise);
      final late = frames.skip(frames.length ~/ 2);
      expect(late.where((f) => f.voiced).length, lessThan(late.length * 0.05));
    });

    test('a quiet voice over room noise still counts', () {
      final r = math.Random(4);
      final s = SynthVoice(seed: 9);
      final bed = Float32List.fromList([for (var i = 0; i < kSampleRate * 8; i++) (r.nextDouble() - 0.5) * 0.01]);
      final voice = s.childVowel(Vowel.ah, seconds: 1.5, amp: 0.03);
      final mix = Float32List.fromList(bed);
      final at = kSampleRate * 6;
      for (var i = 0; i < voice.length; i++) {
        mix[at + i] += voice[i];
      }
      final a = VoiceAnalyzer();
      run(a, mix);
      expect(a.totalVocalizations, greaterThanOrEqualTo(1));
    });

    test('higher sensitivity reacts to softer sound', () {
      final s = SynthVoice(seed: 10);
      final x = SynthVoice.concat([s.silence(1.0, noise: 0.002), s.childVowel(Vowel.ah, seconds: 1, amp: 0.004)]);
      final low = VoiceAnalyzer(sensitivity: 0.5);
      final high = VoiceAnalyzer(sensitivity: 2.0);
      run(low, x);
      run(high, x);
      expect(high.totalVocalizations, greaterThanOrEqualTo(low.totalVocalizations));
      expect(high.totalVocalizations, 1);
    });

    test('muted input is silent', () {
      final s = SynthVoice(seed: 12);
      final a = VoiceAnalyzer()..muted = true;
      final frames = run(a, SynthVoice.concat([s.silence(0.5), s.childVowel(Vowel.ah, seconds: 1)]));
      expect(frames.every((f) => !f.voiced), isTrue);
      expect(a.totalVocalizations, 0);
    });

    test('level rises with loudness', () {
      final s = SynthVoice(seed: 13);
      double peakLevel(double amp) {
        final a = VoiceAnalyzer();
        return run(
          a,
          SynthVoice.concat([s.silence(0.8), s.childVowel(Vowel.ah, seconds: 1, amp: amp)]),
        ).map((f) => f.level).reduce(math.max);
      }

      final soft = peakLevel(0.02), loud = peakLevel(0.4);
      expect(soft, greaterThan(0));
      expect(loud, greaterThan(soft + 0.2));
    });
  });

  test('pcm16ToFloat respects a sliced view', () {
    final bytes = Uint8List.fromList([0, 0, 0xff, 0x7f, 0x00, 0x80]);
    final f = pcm16ToFloat(Uint8List.sublistView(bytes, 2));
    expect(f.length, 2);
    expect(f[0], closeTo(1, 0.001));
    expect(f[1], closeTo(-1, 0.001));
  });
}
