// End-to-end on a device or emulator, with the real Android plugins (TTS,
// audio, file system, PDF) and a synthetic child voice instead of the mic:
//
//   flutter test integration_test/app_flow_test.dart -d <device>
import 'dart:io';

import 'package:echosteps/app.dart';
import 'package:echosteps/core/audio/audio_input.dart';
import 'package:echosteps/core/audio/sound_player.dart';
import 'package:echosteps/core/audio/speech.dart';
import 'package:echosteps/core/audio/voice_engine.dart';
import 'package:echosteps/models/child.dart';
import 'package:echosteps/services/cloud_sync.dart';
import 'package:echosteps/services/report.dart';
import 'package:echosteps/services/session_tracker.dart';
import 'package:echosteps/services/store.dart';
import 'package:echosteps/widgets/parent_gate.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';

Future<void> run(WidgetTester tester, double seconds) async {
  final end = DateTime.now().add(Duration(milliseconds: (seconds * 1000).round()));
  while (DateTime.now().isBefore(end)) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

/// Pumps until [f] finds something (slow emulators drop many frames).
Future<void> waitFor(WidgetTester tester, Finder f, {double seconds = 45}) async {
  final end = DateTime.now().add(Duration(milliseconds: (seconds * 1000).round()));
  while (f.evaluate().isEmpty && DateTime.now().isBefore(end)) {
    await tester.pump(const Duration(milliseconds: 100));
  }
  expect(f, findsWidgets);
}

/// Pumps until [f] finds nothing.
Future<void> waitGone(WidgetTester tester, Finder f, {double seconds = 20}) async {
  final end = DateTime.now().add(Duration(milliseconds: (seconds * 1000).round()));
  while (f.evaluate().isNotEmpty && DateTime.now().isBefore(end)) {
    await tester.pump(const Duration(milliseconds: 100));
  }
  expect(f, findsNothing);
}

Future<void> tapIn(WidgetTester tester, Finder f) async {
  await waitFor(tester, f);
  await tester.ensureVisible(f);
  await tester.pump();
  await tester.tap(f);
}

/// Taps the top-most Back until [target] shows. On a slow emulator a tap can
/// land on a screen that is still fading out.
Future<void> backUntil(WidgetTester tester, Finder target) async {
  for (var i = 0; i < 4 && target.evaluate().isEmpty; i++) {
    final back = find.bySemanticsLabel('Back');
    if (back.evaluate().isNotEmpty) await tester.tap(back.last, warnIfMissed: false);
    final end = DateTime.now().add(const Duration(seconds: 8));
    while (target.evaluate().isEmpty && DateTime.now().isBefore(end)) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }
  expect(target, findsWidgets);
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('a child sets up, plays every mode and a grown-up reviews progress', (tester) async {
    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory('${docs.path}/it_${DateTime.now().millisecondsSinceEpoch}')..createSync();
    final store = await Store.open(dir);
    final speech = Speech(); // real TTS: prompts play, and the mic is muted meanwhile
    await tester.pumpWidget(
      EchoStepsApp(
        store: store,
        sound: SoundPlayer(),
        speech: speech,
        voice: VoiceEngine(
          appSpeaking: speech.speaking,
          inputFactory: (id) => SynthInput(script: id == null ? null : SynthInput.targetScript(id)),
        ),
        session: SessionTracker(store),
        cloud: CloudSync(store: store),
      ),
    );
    await run(tester, 3);

    // Setup.
    await tapIn(tester, find.byKey(const ValueKey('onboarding-start')));
    await run(tester, 1);
    await waitFor(tester, find.byKey(const ValueKey('nickname')));
    await tester.enterText(find.byKey(const ValueKey('nickname')), 'Ava');
    await tapIn(tester, find.text('2-3'));
    await tapIn(tester, find.byKey(const ValueKey('onboarding-next')));
    await run(tester, 1);
    await tapIn(tester, find.byKey(const ValueKey('privacy-next')));
    await run(tester, 1);
    await tapIn(tester, find.byKey(const ValueKey('start-playing')));
    await waitFor(tester, find.text('Hi, Ava!'));
    await run(tester, 1);

    // Sound Spark.
    await tapIn(tester, find.byKey(const ValueKey('hub-spark')));
    await run(tester, 15);
    await backUntil(tester, find.byKey(const ValueKey('hub-safari')));
    await run(tester, 2);

    // Echo Safari: "ah" then "Next sound" to "mmm".
    await tapIn(tester, find.byKey(const ValueKey('hub-safari')));
    await run(tester, 2);
    await tapIn(tester, find.byKey(const ValueKey('stop-ah')));
    await waitFor(tester, find.text('New card!'), seconds: 90);
    await run(tester, 2);
    await tapIn(tester, find.byKey(const ValueKey('stop-next')));
    // The first stop's reward fades out before the "Mmm" stop takes over.
    await waitGone(tester, find.text('New card!'));
    await waitFor(tester, find.text('New card!'), seconds: 90);
    expect(find.text('milk'), findsOneWidget);
    await backUntil(tester, find.byKey(const ValueKey('stop-ah'))); // the map
    await run(tester, 2);
    await backUntil(tester, find.byKey(const ValueKey('hub-cards')));
    await run(tester, 2);

    // Card wall.
    await tapIn(tester, find.byKey(const ValueKey('hub-cards')));
    await waitFor(tester, find.byKey(const ValueKey('card-more')));
    // "milk" (unlocked by "mmm") is further down the grid.
    await tester.dragUntilVisible(find.byKey(const ValueKey('card-milk')), find.byType(GridView), const Offset(0, -300));
    await tester.tap(find.byKey(const ValueKey('card-milk')));
    await run(tester, 6);
    await backUntil(tester, find.byKey(const ValueKey('parent-lock')));
    await run(tester, 2);

    // Parent Zone.
    await tapIn(tester, find.byKey(const ValueKey('parent-lock')));
    await waitFor(tester, find.textContaining('What is'));
    final q = tester.widget<Text>(find.textContaining('What is')).data!;
    await tester.tap(find.byKey(ValueKey('gate-${gateAnswer(q)}')));
    await waitFor(tester, find.text('Parent Zone'));

    final c = store.active!;
    expect(c.practised['ah'], 1);
    expect(c.practised['mmm'], 1);
    expect(c.sessions.where((s) => s.mode == 'spark').single.vocalizations, greaterThan(0));
    expect(c.sessions.where((s) => s.mode == 'safari'), hasLength(2));
    expect(c.sessions.where((s) => s.mode == 'cards'), hasLength(1));

    // The therapist report builds with the real fonts on the device.
    final pdf = await Report.build(c);
    expect(String.fromCharCodes(pdf.take(5)), '%PDF-');

    // Everything survives an app restart.
    await store.flush();
    final reopened = await Store.open(dir);
    expect(reopened.active!.nickname, 'Ava');
    expect(reopened.active!.sessions, hasLength(c.sessions.length));
    expect(reopened.active!.buddy, Buddy.milo);
  });
}
