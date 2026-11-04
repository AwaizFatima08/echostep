// Every My Steps lesson played start to finish with the synthetic voice,
// one test per chapter (about a minute in all).
import 'dart:io';

import 'package:echosteps/core/lessons.dart';
import 'package:echosteps/models/child.dart';
import 'package:echosteps/views/steps/lesson_view.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'app_flow_test.dart' show pumpApp, tapIn;

/// Like `run` in the host tests, with 100 ms frames to halve the cost.
Future<void> run(WidgetTester tester, double seconds) async {
  for (var t = 0.0; t < seconds; t += 0.1) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  for (final ch in chapters) {
    testWidgets('chapter ${ch.id}: every lesson can be finished', (tester) async {
      final dir = Directory.systemTemp.createTempSync('es_all_${ch.id}');
      // Teardown runs on the real clock (a delay inside the test body would
      // wait on the fake one forever).
      addTearDown(() async {
        await Future<void>.delayed(const Duration(milliseconds: 300));
        dir.deleteSync(recursive: true);
      });
      for (final l in ch.lessons) {
        final store = await pumpApp(
          tester,
          dir,
          seed: (s) {
            if (!s.isSetUp) s.addChild(nickname: 'Leo', ageGroup: '2-3', buddy: Buddy.milo);
          },
          home: LessonView(key: ValueKey(l.id), lesson: l),
        );
        await run(tester, 2);
        for (var i = 0; i < l.steps.length; i++) {
          await tapIn(tester, find.byKey(const ValueKey('lesson-go')));
          for (var t = 0.0; t < 60 && find.byKey(const ValueKey('lesson-continue')).evaluate().isEmpty; t += 0.5) {
            await run(tester, 0.5);
          }
          expect(find.byKey(const ValueKey('lesson-continue')), findsOneWidget, reason: '${l.id} step ${i + 1}');
          await tester.tap(find.byKey(const ValueKey('lesson-continue')));
          await run(tester, 1.5);
        }
        expect(find.byKey(const ValueKey('lesson-done')), findsOneWidget, reason: l.id);
        expect(store.active!.lessonsDone[l.id], 1, reason: l.id);
      }
    }, timeout: const Timeout(Duration(minutes: 5)));
  }
}
