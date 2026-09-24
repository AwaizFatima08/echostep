import 'dart:io';

import 'package:echosteps/app.dart';
import 'package:echosteps/core/audio/audio_input.dart';
import 'package:echosteps/core/audio/sound_player.dart';
import 'package:echosteps/core/audio/speech.dart';
import 'package:echosteps/core/audio/voice_engine.dart';
import 'package:echosteps/models/child.dart';
import 'package:echosteps/services/cloud_sync.dart';
import 'package:echosteps/services/session_tracker.dart';
import 'package:echosteps/services/store.dart';
import 'package:echosteps/widgets/parent_gate.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Builds the real app with a synthetic voice, no audio output and no
/// Firebase.
Future<Store> pumpApp(WidgetTester tester, Directory dir, {void Function(Store)? seed}) async {
  final store = (await tester.runAsync(() => Store.open(dir)))!;
  seed?.call(store);
  final speech = Speech(enabled: false);
  await tester.binding.setSurfaceSize(const Size(412, 915));
  await tester.pumpWidget(
    EchoStepsApp(
      store: store,
      sound: SoundPlayer(enabled: false),
      speech: speech,
      voice: VoiceEngine(
        appSpeaking: speech.speaking,
        inputFactory: (id) => SynthInput(script: id == null ? null : SynthInput.targetScript(id)),
      ),
      session: SessionTracker(store),
      cloud: CloudSync(store: store),
    ),
  );
  return store;
}

/// Pumps [seconds] of app time in 50 ms steps (animations never settle).
Future<void> run(WidgetTester tester, double seconds) async {
  for (var t = 0.0; t < seconds; t += 0.05) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

/// The scrolling list inside one Parent Zone tab (all three stay built).
Finder tabList(String tab) => find
    .descendant(of: find.byWidgetPredicate((w) => w.runtimeType.toString() == tab), matching: find.byType(Scrollable))
    .first;

/// Scrolls [f] into view, then taps it.
Future<void> tapIn(WidgetTester tester, Finder f) async {
  await tester.ensureVisible(f);
  await tester.pump();
  await tester.tap(f);
}

Future<void> passGate(WidgetTester tester) async {
  final q = tester.widget<Text>(find.textContaining('What is')).data!;
  await tester.tap(find.byKey(ValueKey('gate-${gateAnswer(q)}')));
  await run(tester, 1);
}

void main() {
  late Directory dir;
  setUp(() => dir = Directory.systemTemp.createTempSync('es_flow'));
  tearDown(() async {
    await Future<void>.delayed(const Duration(milliseconds: 300));
    dir.deleteSync(recursive: true);
  });

  void seedChild(Store s) => s.addChild(nickname: 'Leo', ageGroup: '2-3', buddy: Buddy.milo);

  testWidgets('first run: setup creates a child and lands on the hub', (tester) async {
    final store = await pumpApp(tester, dir);
    await run(tester, 3); // splash
    expect(find.text('Welcome to EchoSteps'), findsOneWidget);
    await tapIn(tester, find.byKey(const ValueKey('onboarding-start')));
    await run(tester, 1);
    await tester.enterText(find.byKey(const ValueKey('nickname')), 'Leo');
    await tapIn(tester, find.text('4-5'));
    await tapIn(tester, find.text('Pip'));
    await run(tester, 0.5);
    await tapIn(tester, find.byKey(const ValueKey('onboarding-next')));
    await run(tester, 1);
    expect(find.text('Sound and privacy'), findsOneWidget);
    await tapIn(tester, find.byKey(const ValueKey('privacy-next')));
    await run(tester, 1);
    expect(find.text('All set for Leo!'), findsOneWidget);
    await tapIn(tester, find.byKey(const ValueKey('start-playing')));
    await run(tester, 1.5);
    expect(find.text('Hi, Leo!'), findsOneWidget);
    expect(find.text('Sound Spark'), findsOneWidget);
    expect(find.text('Echo Safari'), findsOneWidget);
    expect(find.text('My Cards'), findsOneWidget);
    final c = store.active!;
    expect(c.nickname, 'Leo');
    expect(c.ageGroup, '4-5');
    expect(c.buddy, Buddy.pip);
  });

  testWidgets('Sound Spark hears the synthetic voice and records the visit', (tester) async {
    final store = await pumpApp(tester, dir, seed: seedChild);
    await run(tester, 3);
    await tester.tap(find.byKey(const ValueKey('hub-spark')));
    await run(tester, 14);
    await tester.tap(find.bySemanticsLabel('Back').first);
    await run(tester, 1.5);
    final s = store.active!.sessions.single;
    expect(s.mode, 'spark');
    expect(s.durationSeconds, greaterThanOrEqualTo(10));
    expect(s.vocalizations, greaterThanOrEqualTo(2));
    expect(s.voiceSeconds, greaterThan(2));
    expect(find.text('Hi, Leo!'), findsOneWidget);
  });

  testWidgets('Echo Safari: imitating "ah" blooms the flower and unlocks cards', (tester) async {
    final store = await pumpApp(tester, dir, seed: seedChild);
    await run(tester, 3);
    await tester.tap(find.byKey(const ValueKey('hub-safari')));
    await run(tester, 1.5);
    await tester.tap(find.byKey(const ValueKey('stop-ah')));
    await run(tester, 12);
    expect(find.text('New card!'), findsOneWidget);
    expect(find.text('car'), findsOneWidget);
    final c = store.active!;
    expect(c.practised['ah'], 1);
    expect(c.unlockedCards, containsAll(['car', 'potty', 'star']));

    // "Next sound" goes straight on to Mmm and it works too (the mic hand-over).
    await tester.tap(find.byKey(const ValueKey('stop-next')));
    await run(tester, 14);
    expect(find.text('New card!'), findsOneWidget);
    expect(c.practised['mmm'], 1);
    await tester.tap(find.bySemanticsLabel('Back').first);
    await run(tester, 1.5);
    await tester.tap(find.bySemanticsLabel('Back').first);
    await run(tester, 1.5);
    final visits = c.sessions.where((s) => s.mode == 'safari').toList();
    expect(visits.map((s) => s.target), ['ah', 'mmm']);
    expect(visits.every((s) => s.completions == 1), isTrue);
  });

  testWidgets('My Cards shows core words and speaks a tapped card', (tester) async {
    await pumpApp(tester, dir, seed: seedChild);
    await run(tester, 3);
    await tester.tap(find.byKey(const ValueKey('hub-cards')));
    await run(tester, 1);
    for (final w in ['more', 'help', 'all done', 'yes', 'no']) {
      expect(find.text(w), findsWidgets);
    }
    expect(find.text('car'), findsNothing);
    await tester.tap(find.byKey(const ValueKey('card-more')));
    await run(tester, 1);
    expect(find.text('more'), findsNWidgets(2)); // grid + enlarged
  });

  testWidgets('the parent gate keeps children out and lets grown-ups in', (tester) async {
    await pumpApp(tester, dir, seed: seedChild);
    await run(tester, 3);
    await tester.tap(find.byKey(const ValueKey('parent-lock')));
    await run(tester, 1);
    final q = tester.widget<Text>(find.textContaining('What is')).data!;
    final wrong = find.byWidgetPredicate(
      (w) =>
          w is OutlinedButton &&
          w.key is ValueKey<String> &&
          (w.key as ValueKey<String>).value != 'gate-${gateAnswer(q)}',
    );
    await tester.tap(wrong.first);
    await run(tester, 0.5);
    expect(find.textContaining('Not quite'), findsOneWidget);
    expect(find.text('Parent Zone'), findsNothing);
    await passGate(tester);
    expect(find.text('Parent Zone'), findsOneWidget);
    expect(find.textContaining('Vocal Growth Tree'), findsOneWidget);
    await tester.tap(find.text('Settings'));
    await run(tester, 0.5);
    await tester.scrollUntilVisible(find.text('Calm mode'), 200, scrollable: tabList('SettingsTab'));
    expect(find.text('Calm mode'), findsOneWidget);
    await tester.tap(find.text('Family & account'));
    await run(tester, 0.5);
    await tester.scrollUntilVisible(
      find.textContaining('Not available on this device'),
      200,
      scrollable: tabList('FamilyTab'),
    );
    expect(find.textContaining('Not available on this device'), findsOneWidget);
  });

  testWidgets('a grown-up marks a sound mastered; it shows in the report data', (tester) async {
    final store = await pumpApp(tester, dir, seed: seedChild);
    await run(tester, 3);
    await tester.tap(find.byKey(const ValueKey('parent-lock')));
    await run(tester, 1);
    await passGate(tester);
    await tester.scrollUntilVisible(find.byKey(const ValueKey('sound-oo')), 200, scrollable: tabList('ProgressTab'));
    await tapIn(tester, find.byKey(const ValueKey('sound-oo')));
    await run(tester, 1);
    await tester.tap(find.byType(SwitchListTile).last);
    await run(tester, 0.5);
    expect(store.active!.mastered, contains('oo'));
  });

  testWidgets('daily limit: time up shows the rest screen, not the game', (tester) async {
    final store = await pumpApp(
      tester,
      dir,
      seed: (s) {
        seedChild(s);
        final c = s.active!;
        c.settings.dailyMinutes = 10;
        s.addSession(
          c,
          SessionRecord(id: 'x', childId: c.id, start: DateTime.now(), mode: 'spark', durationSeconds: 700),
        );
      },
    );
    await run(tester, 3);
    await tester.tap(find.byKey(const ValueKey('hub-spark')));
    await run(tester, 2);
    expect(find.text('Rest time'), findsOneWidget);
    // Cards stay available: communication is never limited.
    await tester.tap(find.bySemanticsLabel('Home'));
    await run(tester, 2);
    await tester.tap(find.byKey(const ValueKey('hub-cards')));
    await run(tester, 1);
    expect(find.text('more'), findsWidgets);
    expect(store.active!.settings.dailyMinutes, 10);
  });
}
