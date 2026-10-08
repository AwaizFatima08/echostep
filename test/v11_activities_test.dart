// v1.1: Animal Friends, Echo Turns, Pitch Slide and the four new Safari stops.
import 'dart:io';

import 'package:echosteps/core/audio/audio_input.dart';
import 'package:echosteps/core/audio/voice_analyzer.dart';
import 'package:echosteps/core/content.dart';
import 'package:echosteps/models/child.dart';
import 'package:echosteps/services/store.dart';
import 'package:echosteps/views/pitch/pitch_slide_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'app_flow_test.dart' show pumpApp, run;

void main() {
  late Directory dir;
  setUp(() => dir = Directory.systemTemp.createTempSync('es_v11'));
  tearDown(() async {
    await Future<void>.delayed(const Duration(milliseconds: 300));
    dir.deleteSync(recursive: true);
  });

  void seedChild(Store s) => s.addChild(nickname: 'Leo', ageGroup: '2-3', buddy: Buddy.milo);

  group('content', () {
    test('12 Safari stops, every card and animal has a picture, synth covers every stop', () {
      expect(targets, hasLength(12));
      expect(targets.map((t) => t.id).skip(8), ['pa', 'wa', 'na', 'bye']);
      expect(targets.map((t) => t.id).toSet(), hasLength(12));
      for (final t in targets) {
        for (final c in t.cards) {
          expect(cardById(c), isNotNull, reason: '${t.id}/$c');
          expect(File(cardById(c)!.asset).existsSync(), isTrue, reason: c);
        }
        // Every stop has a synthetic performance that matches its kind.
        expect(SynthInput.targetScript(t.id), isNotEmpty);
        expect(t.phoneme, isNotEmpty);
      }
      expect(aacCards.map((c) => c.id).toSet(), hasLength(aacCards.length));
      expect(animals, hasLength(6));
      for (final a in animals) {
        expect(targetById(a.targetId), isNotNull, reason: a.id);
        expect(File(a.asset).existsSync(), isTrue, reason: a.id);
        expect(cardById(a.id), isNull, reason: 'animals are not AAC cards');
      }
    });

    test('pitch trail follows the voice and settles in silence', () {
      final tr = PitchTrail();
      VoiceFrame f(double pitch, {bool voiced = true}) =>
          VoiceFrame(rms: voiced ? 0.1 : 0, level: voiced ? 0.5 : 0, voiced: voiced, pitchHz: voiced ? pitch : 0);
      for (var i = 0; i < 60; i++) {
        tr.step(f(600), 0.05);
      }
      expect(tr.height, greaterThan(0.7));
      for (var i = 0; i < 60; i++) {
        tr.step(f(150), 0.05);
      }
      expect(tr.height, lessThan(0.3));
      for (var i = 0; i < 200; i++) {
        tr.step(f(0, voiced: false), 0.05);
      }
      expect(tr.height, closeTo(0.5, 0.05));
      expect(tr.points.length, lessThanOrEqualTo(PitchTrail.seconds * PitchTrail.perSecond));
      expect(tr.points.last, isNull);
      expect(PitchTrail(calm: true).guideAt(2) - 0.5, lessThan(tr.guideAt(2) - 0.5 + 1e-9));
    });
  });

  testWidgets('Animal Friends: echoing the cow counts as practising "oo"', (tester) async {
    final store = await pumpApp(tester, dir, seed: seedChild);
    await run(tester, 3);
    await tester.tap(find.byKey(const ValueKey('hub-animals')));
    await run(tester, 1.5);
    expect(find.text('Animal Friends'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('animal-cow')));
    await run(tester, 14);
    final c = store.active!;
    expect(c.practised['oo'], 1, reason: 'the cow is an "oo" in disguise');
    expect(find.byKey(const ValueKey('animal-cow')), findsOneWidget, reason: 'back on the grid, cow starred');
    expect(find.byIcon(Icons.star_rounded), findsWidgets);
    await tester.tap(find.bySemanticsLabel('Back').first);
    await run(tester, 1.5);
    final s = c.sessions.single;
    expect(s.mode, 'animals');
    expect(s.completions, 1);
  });

  testWidgets('Echo Turns: four echoes finish a round', (tester) async {
    final store = await pumpApp(tester, dir, seed: seedChild);
    await run(tester, 3);
    await tester.tap(find.byKey(const ValueKey('hub-turns')));
    await run(tester, 36);
    expect(find.byKey(const ValueKey('turns-done')), findsOneWidget);
    final c = store.active!;
    expect(c.practised['ah'], 1, reason: 'the suggested first sound is "ah"');
    await tester.tap(find.byKey(const ValueKey('turns-home')));
    await run(tester, 1.5);
    final s = c.sessions.single;
    expect(s.mode, 'turns');
    expect(s.completions, 1);
    expect(s.target, 'ah');
  });

  testWidgets('Pitch Slide: the voice flies Pip and the visit is recorded', (tester) async {
    final store = await pumpApp(tester, dir, seed: seedChild);
    await run(tester, 3);
    await tester.tap(find.byKey(const ValueKey('hub-pitch')));
    await run(tester, 12);
    final cue = tester.widget<Text>(find.byKey(const ValueKey('pitch-cue'))).data;
    expect(cue, isNot('Make a sound to fly!'));
    await tester.tap(find.bySemanticsLabel('Back').first);
    await run(tester, 1.5);
    final s = store.active!.sessions.single;
    expect(s.mode, 'pitch');
    expect(s.voiceSeconds, greaterThan(2));
  });

  testWidgets('Safari: the new "pa" stop blooms with babbling', (tester) async {
    final store = await pumpApp(tester, dir, seed: seedChild);
    await run(tester, 3);
    await tester.tap(find.byKey(const ValueKey('hub-safari')));
    await run(tester, 1.5);
    await tester.ensureVisible(find.byKey(const ValueKey('stop-pa')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('stop-pa')));
    await run(tester, 14);
    expect(find.text('New card!'), findsOneWidget);
    expect(store.active!.practised['pa'], 1);
    expect(store.active!.unlockedCards, containsAll(['papa', 'pear', 'popcorn']));
  });
}
