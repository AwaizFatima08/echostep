// My Steps (v1.2): lesson content, progress storage and the lesson flows.
import 'dart:io';

import 'package:echosteps/core/content.dart';
import 'package:echosteps/core/lessons.dart';
import 'package:echosteps/core/version.dart';
import 'package:echosteps/models/child.dart';
import 'package:echosteps/services/cloud_sync.dart';
import 'package:echosteps/services/report.dart';
import 'package:echosteps/services/store.dart';
import 'package:echosteps/views/steps/lesson_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'app_flow_test.dart' show pumpApp, run, tapIn;

void main() {
  group('content', () {
    test('7 chapters of 3 lessons, 3 steps each, unique ids', () {
      expect(chapters, hasLength(7));
      expect(allLessons, hasLength(21));
      for (final l in allLessons) {
        expect(l.steps, hasLength(3), reason: l.id);
      }
      expect(allLessons.map((l) => l.id).toSet(), hasLength(21));
      expect(chapters.map((c) => c.id).toSet(), hasLength(7));
    });

    test('every step points at a real sound, animal or card with a picture', () {
      for (final l in allLessons) {
        for (final s in l.steps) {
          final where = '${l.id}/${s.kind.name}/${s.ref}';
          switch (s.kind) {
            case StepKind.spark || StepKind.pitch:
              expect(s.seconds, inInclusiveRange(15, 90), reason: where);
            case StepKind.stop || StepKind.turns:
              expect(targetById(s.ref!), isNotNull, reason: where);
            case StepKind.animal:
              expect(File(animalById(s.ref!)!.asset).existsSync(), isTrue, reason: where);
            case StepKind.word:
              final card = cardById(s.ref!);
              expect(card, isNotNull, reason: where);
              expect(card!.target, isNotNull, reason: '$where has no sound');
              expect(File(card.asset).existsSync(), isTrue, reason: where);
          }
          expect(s.label, isNotEmpty, reason: where);
          // Every step screen can be built for every step.
          expect(stepScreen(s), isA<Widget>(), reason: where);
        }
      }
    });

    test('every Safari sound is practised somewhere on the path', () {
      final used = {
        for (final l in allLessons)
          for (final s in l.steps)
            if (s.target != null) s.target!.id,
      };
      expect(used, containsAll(targets.map((t) => t.id)));
    });

    test('card sounds resolve, and the new words exist', () {
      for (final c in aacCards.where((c) => c.sound != null)) {
        expect(c.target, isNotNull, reason: c.id);
      }
      expect(cardById('up'), isNotNull);
      expect(cardById('uh_oh'), isNotNull);
    });

    test('next lesson follows path order, then the least-done lesson', () {
      expect(nextLesson({}).id, 'c1l1');
      expect(nextLesson({'c1l1': 1}).id, 'c1l2');
      expect(nextLesson({'c1l1': 1, 'c1l3': 2}).id, 'c1l2');
      final all = {for (final l in allLessons) l.id: 2};
      all['c5l2'] = 1;
      expect(nextLesson(all).id, 'c5l2');
      expect(lessonsFinished({'c1l1': 3, 'c2l1': 1, 'nope': 4}), 2);
    });

    test('app version constant matches pubspec', () {
      final pub = File('pubspec.yaml').readAsStringSync();
      final v = RegExp(r'^version:\s*([0-9.]+)\+', multiLine: true).firstMatch(pub)!.group(1);
      expect(appVersion, v);
    });
  });

  group('progress', () {
    late Directory dir;
    setUp(() => dir = Directory.systemTemp.createTempSync('es_steps'));
    tearDown(() async {
      await Future<void>.delayed(const Duration(milliseconds: 400));
      dir.deleteSync(recursive: true);
    });

    test('lessons and words are recorded, survive a restart and reset clears them', () async {
      final s = await Store.open(dir);
      final c = s.addChild(nickname: 'Leo', ageGroup: '2-3', buddy: Buddy.milo);
      s.recordLesson(c, 'c1l1');
      s.recordLesson(c, 'c1l1');
      expect(s.recordWord(c, cardById('milk')!), isTrue);
      expect(s.recordWord(c, cardById('milk')!), isFalse);
      expect(s.recordWord(c, cardById('more')!), isFalse, reason: 'core cards are already available');
      expect(c.practised['mmm'], 3);
      await s.flush();
      final r = (await Store.open(dir)).active!;
      expect(r.lessonsDone, {'c1l1': 2});
      expect(r.unlockedCards, contains('milk'));
      s.resetProgress(c);
      expect(c.lessonsDone, isEmpty);
    });

    test('a cloud copy merges lesson progress by the larger count', () async {
      final s = await Store.open(dir);
      final c = s.addChild(nickname: 'Leo', ageGroup: '2-3', buddy: Buddy.milo);
      s.recordLesson(c, 'c1l1');
      final remote = ChildProfile.fromJson(c.toJson())
        ..lessonsDone['c1l1'] = 3
        ..lessonsDone['c2l1'] = 1;
      s.mergeRemote(remote);
      expect(c.lessonsDone, {'c1l1': 3, 'c2l1': 1});
    });

    test('lesson progress is part of the cloud document and the report', () async {
      final c = ChildProfile(id: 'k', nickname: 'Leo', ageGroup: '4-5', buddy: Buddy.pip)..lessonsDone['c3l2'] = 1;
      expect(CloudSync.childToCloud(c)['lessons_done'], {'c3l2': 1});
      final back = CloudSync.childFromCloud('k', CloudSync.childToCloud(c), const []);
      expect(back.lessonsDone, {'c3l2': 1});
      final pdf = await Report.build(c);
      expect(String.fromCharCodes(pdf.take(5)), '%PDF-');
    });
  });

  group('flows', () {
    late Directory dir;
    setUp(() => dir = Directory.systemTemp.createTempSync('es_steps_flow'));
    tearDown(() async {
      await Future<void>.delayed(const Duration(milliseconds: 300));
      dir.deleteSync(recursive: true);
    });

    void seed(Store s) => s.addChild(nickname: 'Leo', ageGroup: '2-3', buddy: Buddy.milo);

    /// Taps Go, waits for the step to finish, taps "next step".
    Future<void> playStep(WidgetTester tester, {double seconds = 45}) async {
      await tapIn(tester, find.byKey(const ValueKey('lesson-go')));
      for (var t = 0.0; t < seconds && find.byKey(const ValueKey('lesson-continue')).evaluate().isEmpty; t += 0.5) {
        await run(tester, 0.5);
      }
      expect(find.byKey(const ValueKey('lesson-continue')), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('lesson-continue')));
      await run(tester, 1.5);
    }

    testWidgets('hub banner -> My Steps -> first lesson: Sound Spark, Pitch Slide, Sound Spark', (tester) async {
      final store = await pumpApp(tester, dir, seed: seed);
      await run(tester, 3);
      expect(find.text('Next: Wake up, Milo'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('hub-steps')));
      await run(tester, 1.5);
      expect(find.text('My Steps'), findsWidgets);
      expect(find.text('0 / 21'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('path-next')));
      await run(tester, 1.5);
      expect(find.byKey(const ValueKey('lesson-title')), findsOneWidget);
      expect(find.text('Wake up, Milo'), findsOneWidget);

      await playStep(tester);
      expect(find.byKey(const ValueKey('lesson-go')), findsOneWidget);
      await playStep(tester);
      await playStep(tester);
      expect(find.byKey(const ValueKey('lesson-done')), findsOneWidget);
      final c = store.active!;
      expect(c.lessonsDone, {'c1l1': 1});
      expect(c.sessions.map((s) => s.mode), ['spark', 'pitch', 'spark']);

      // Next lesson goes straight on to lesson 2.
      await tester.tap(find.byKey(const ValueKey('lesson-next')));
      await run(tester, 1.5);
      expect(find.text('Big and small'), findsOneWidget);
    });

    testWidgets('a lesson with a Safari stop, an animal and a First Words card', (tester) async {
      final store = await pumpApp(
        tester,
        dir,
        seed: seed,
        home: LessonView(lesson: lessonById('c4l1')!),
      );
      await run(tester, 2);
      expect(find.text('Hum like a bee'), findsOneWidget);
      await playStep(tester); // stop: mmm
      await playStep(tester); // animal: bee
      await playStep(tester); // word: milk
      expect(find.byKey(const ValueKey('lesson-done')), findsOneWidget);
      final c = store.active!;
      expect(c.lessonsDone['c4l1'], 1);
      expect(c.unlockedCards, contains('milk'));
      expect(c.sessions.map((s) => s.mode), ['safari', 'animals', 'word']);
      expect(c.sessions.last.target, 'mmm');
      expect(c.sessions.last.completions, 1);
    });

    testWidgets('leaving a step early keeps the lesson where it was', (tester) async {
      final store = await pumpApp(
        tester,
        dir,
        seed: seed,
        home: LessonView(lesson: lessonById('c2l2')!),
      );
      await run(tester, 2);
      await tapIn(tester, find.byKey(const ValueKey('lesson-go')));
      await run(tester, 2);
      await tester.tap(find.bySemanticsLabel('Back').last);
      await run(tester, 1.5);
      expect(find.byKey(const ValueKey('lesson-go')), findsOneWidget);
      expect(find.byIcon(Icons.star_rounded), findsNothing);
      expect(store.active!.lessonsDone, isEmpty);
    });
  });
}
