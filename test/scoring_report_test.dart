import 'dart:math' as math;
import 'dart:typed_data';

import 'package:echosteps/core/audio/dsp.dart';
import 'package:echosteps/core/audio/synth_voice.dart';
import 'package:echosteps/core/audio/voice_analyzer.dart';
import 'package:echosteps/core/content.dart';
import 'package:echosteps/models/child.dart';
import 'package:echosteps/services/progress.dart';
import 'package:echosteps/services/report.dart';
import 'package:echosteps/services/store.dart';
import 'package:echosteps/views/safari/safari_stop_view.dart';
import 'package:echosteps/widgets/growth_tree.dart';
import 'package:flutter_test/flutter_test.dart';

/// Feeds [audio] through a fresh analyzer into [scorer]; returns seconds of
/// audio needed to finish (or null if it never finished).
double? secondsToFinish(StopScorer scorer, Float32List audio) {
  final a = VoiceAnalyzer();
  var t = 0.0;
  for (var i = 0; i < audio.length; i += 512) {
    for (final f in a.add(Float32List.sublistView(audio, i, math.min(i + 512, audio.length)))) {
      scorer.add(f);
      t += VoiceAnalyzer.hopSeconds;
      if (scorer.done) return t;
    }
  }
  return null;
}

StopScorer scorer(String id, PlayLevel level) =>
    StopScorer(target: targetById(id)!, level: level, holdSeconds: 2.5, syllablesNeeded: 4);

Float32List repeat(Float32List Function() piece, SynthVoice s, int times) => SynthVoice.concat([
  for (var i = 0; i < times; i++) ...[s.silence(0.4), piece()],
]);

void main() {
  group('Echo Safari scoring', () {
    test('silence never grows the flower', () {
      final sc = scorer('ah', PlayLevel.explore);
      expect(secondsToFinish(sc, SynthVoice().silence(20)), isNull);
      expect(sc.progress, 0);
    });

    test('Explore: any sound completes a vowel stop', () {
      final s = SynthVoice(seed: 1);
      final oo = repeat(() => s.childVowel(Vowel.oo, seconds: 1.5), s, 4);
      expect(secondsToFinish(scorer('ah', PlayLevel.explore), oo), isNotNull);
    });

    for (final v in Vowel.values) {
      test('Practise: the target ${v.name} finishes much faster than a different vowel', () {
        final s = SynthVoice(seed: 2);
        final other = Vowel.values[(v.index + 2) % 4];
        final right = secondsToFinish(
          scorer(v.name, PlayLevel.practise),
          repeat(() => s.childVowel(v, seconds: 1.5), s, 12),
        );
        final wrong = secondsToFinish(
          scorer(v.name, PlayLevel.practise),
          repeat(() => s.childVowel(other, seconds: 1.5), s, 30),
        );
        expect(right, isNotNull);
        expect(wrong, isNotNull, reason: 'errorless: other sounds still finish eventually');
        expect(wrong! / right!, greaterThan(2), reason: '${v.name} vs ${other.name}');
      });
    }

    test('Practise: a hum finishes the Mmm stop faster than an open vowel', () {
      final s = SynthVoice(seed: 3);
      final hum = secondsToFinish(scorer('mmm', PlayLevel.practise), repeat(() => s.hum(seconds: 1.5), s, 12));
      final ah = secondsToFinish(
        scorer('mmm', PlayLevel.practise),
        repeat(() => s.childVowel(Vowel.ah, seconds: 1.5), s, 30),
      );
      expect(hum, isNotNull);
      expect(ah! / hum!, greaterThan(2));
    });

    test('babbling ba-ba-ba finishes a syllable stop quickly; one long vowel only creeps', () {
      final s = SynthVoice(seed: 4);
      final babble = secondsToFinish(scorer('ba', PlayLevel.practise), repeat(() => s.babble(count: 3), s, 6));
      expect(babble, isNotNull);
      expect(babble, lessThan(4));
      final long = scorer('ba', PlayLevel.practise);
      secondsToFinish(long, s.childVowel(Vowel.ah, seconds: 3));
      expect(long.progress, lessThan(0.6));
    });

    test('age sets the goal: 2-3 year olds need less than 6+', () {
      final young = ChildProfile(id: 'a', nickname: '', ageGroup: '2-3', buddy: Buddy.milo);
      final old = ChildProfile(id: 'b', nickname: '', ageGroup: '6+', buddy: Buddy.milo);
      expect(young.holdSeconds, lessThan(old.holdSeconds));
      expect(young.syllablesNeeded, lessThan(old.syllablesNeeded));
    });
  });

  group('progress and report', () {
    final now = DateTime(2026, 9, 24, 18);
    ChildProfile child() {
      final c = ChildProfile(id: 'kid', nickname: 'Leo', ageGroup: '4-5', buddy: Buddy.milo);
      void add(int daysAgo, String mode, {String? target, int attempts = 0, int completions = 0}) {
        c.sessions.add(
          SessionRecord(
            id: Store.newId(),
            childId: c.id,
            start: now.subtract(Duration(days: daysAgo, hours: 1)),
            mode: mode,
            durationSeconds: 120,
            vocalizations: 12,
            voiceSeconds: 30,
            avgDb: -22,
            target: target,
            attempts: attempts,
            completions: completions,
          ),
        );
      }

      add(0, 'spark');
      add(0, 'safari', target: 'ah', attempts: 2, completions: 1);
      add(3, 'safari', target: 'ba', attempts: 1, completions: 1);
      add(40, 'spark'); // outside a 30-day window
      c
        ..practised.addAll({'ah': 1, 'ba': 1})
        ..mastered.add('ah')
        ..totalSessions = 4
        ..totalSeconds = 480
        ..totalVocalizations = 48;
      return c;
    }

    test('daily buckets, active days and per-sound summaries', () {
      final p = Progress(child(), now: now);
      final week = p.daily(7);
      expect(week, hasLength(7));
      expect(week.last.playMinutes, 4);
      expect(week[3].playMinutes, 2);
      expect(p.activeDays(30), 2);
      final sums = p.targetSummaries(days: 30);
      expect(sums['ah']!.attempts, 2);
      expect(sums['ah']!.successRate, 0.5);
      expect(sums['ba']!.completions, 1);
      expect(sums['oo']!.visits, 0);
    });

    test('sound status: mastered only when a grown-up said so', () {
      final c = child();
      final p = Progress(c, now: now);
      expect(p.status(targetById('ah')!), 'mastered');
      expect(p.status(targetById('ba')!), 'practised');
      expect(p.status(targetById('ee')!), 'new');
      c.sessions.add(SessionRecord(id: 'x', childId: c.id, start: now, mode: 'safari', target: 'ee'));
      expect(p.status(targetById('ee')!), 'tried');
    });

    test('the growth tree gets fuller with practice', () {
      final empty = TreeStats.of(ChildProfile(id: 'e', nickname: '', ageGroup: '2-3', buddy: Buddy.milo));
      final busy = TreeStats.of(child());
      expect(empty.depth, 0);
      expect(busy.depth, greaterThan(empty.depth));
      expect(busy.practised, hasLength(2));
      expect(busy.mastered.single.id, 'ah');
      expect(busy.growth, greaterThan(empty.growth));
    });

    test('the SLP report builds a PDF', () async {
      final bytes = await Report.build(child(), now: now);
      expect(String.fromCharCodes(bytes.take(5)), '%PDF-');
      expect(bytes.length, greaterThan(3000));
    });

    test('the report also builds for a child with no sessions', () async {
      final bytes = await Report.build(
        ChildProfile(id: 'n', nickname: '', ageGroup: '2-3', buddy: Buddy.pip),
        now: now,
      );
      expect(String.fromCharCodes(bytes.take(5)), '%PDF-');
    });
  });
}
