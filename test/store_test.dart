import 'dart:convert';
import 'dart:io';

import 'package:echosteps/core/content.dart';
import 'package:echosteps/models/child.dart';
import 'package:echosteps/services/session_tracker.dart';
import 'package:echosteps/services/store.dart';
import 'package:flutter_test/flutter_test.dart';

class RecordingObserver implements StoreObserver {
  final changed = <String>[];
  final deleted = <String>[];
  final sessions = <String>[];

  @override
  void childChanged(ChildProfile child) => changed.add(child.id);
  @override
  void childDeleted(String childId) => deleted.add(childId);
  @override
  void sessionAdded(ChildProfile child, SessionRecord session) => sessions.add(session.id);
}

SessionRecord session(
  ChildProfile c, {
  DateTime? start,
  int seconds = 60,
  int vocal = 10,
  String mode = 'spark',
  String? target,
}) => SessionRecord(
  id: Store.newId(),
  childId: c.id,
  start: start ?? DateTime.now(),
  mode: mode,
  durationSeconds: seconds,
  vocalizations: vocal,
  voiceSeconds: seconds / 4,
  avgDb: -20,
  target: target,
);

void main() {
  late Directory dir;
  setUp(() => dir = Directory.systemTemp.createTempSync('es_store'));
  tearDown(() async {
    // Let debounced writes land before removing the folder.
    await Future<void>.delayed(const Duration(milliseconds: 400));
    dir.deleteSync(recursive: true);
  });

  test('a child survives a restart with settings, progress and sessions', () async {
    final s = await Store.open(dir);
    expect(s.isSetUp, isFalse);
    final c = s.addChild(nickname: '  Leo  ', ageGroup: '4-5', buddy: Buddy.pip);
    c.settings
      ..calmMode = true
      ..sensitivity = 1.5
      ..dailyMinutes = 15;
    s.childUpdated(c);
    s.addSession(c, session(c, target: 'ah', mode: 'safari'));
    s.recordCompletion(c, targets.first);
    s.setMastered(c, 'ah', true);
    await s.flush();

    final r = await Store.open(dir);
    final c2 = r.active!;
    expect(c2.nickname, 'Leo');
    expect(c2.ageGroup, '4-5');
    expect(c2.buddy, Buddy.pip);
    expect(c2.settings.calmMode, isTrue);
    expect(c2.settings.sensitivity, 1.5);
    expect(c2.settings.dailyMinutes, 15);
    expect(c2.sessions, hasLength(1));
    expect(c2.practised['ah'], 1);
    expect(c2.mastered, contains('ah'));
    expect(c2.unlockedCards, containsAll(targets.first.cards));
    expect(c2.totalSeconds, 60);
    expect(c2.totalVocalizations, 10);
  });

  test('a corrupt file never locks the child out', () async {
    File('${dir.path}/echosteps.json').writeAsStringSync('{not json');
    final s = await Store.open(dir);
    expect(s.isSetUp, isFalse);
    expect(File('${dir.path}/echosteps.json.corrupt').existsSync(), isTrue);
  });

  test('rapid saves coalesce and the last state wins', () async {
    final s = await Store.open(dir);
    final c = s.addChild(nickname: 'A', ageGroup: '2-3', buddy: Buddy.milo);
    for (var i = 0; i < 50; i++) {
      c.nickname = 'N$i';
      s.childUpdated(c);
    }
    await s.flush();
    final j = jsonDecode(File('${dir.path}/echosteps.json').readAsStringSync()) as Map<String, dynamic>;
    expect((j['children'] as List).first['nickname'], 'N49');
  });

  test('nickname is trimmed and capped at 24 characters', () async {
    final s = await Store.open(dir);
    final c = s.addChild(nickname: 'x' * 40, ageGroup: '2-3', buddy: Buddy.milo);
    expect(c.nickname.length, 24);
    expect(s.addChild(nickname: '', ageGroup: '2-3', buddy: Buddy.milo).displayName, 'Superstar');
  });

  test('older children start in Practise, younger in Explore', () async {
    final s = await Store.open(dir);
    expect(s.addChild(nickname: 'a', ageGroup: '2-3', buddy: Buddy.milo).settings.level, PlayLevel.explore);
    expect(s.addChild(nickname: 'b', ageGroup: '6+', buddy: Buddy.milo).settings.level, PlayLevel.practise);
  });

  test('completing a stop unlocks its cards once', () async {
    final s = await Store.open(dir);
    final c = s.addChild(nickname: 'a', ageGroup: '2-3', buddy: Buddy.milo);
    final ba = targetById('ba')!;
    final first = s.recordCompletion(c, ba);
    expect(first.map((x) => x.id), ba.cards);
    expect(s.recordCompletion(c, ba), isEmpty);
    expect(c.practised['ba'], 2);
  });

  test('core cards are always available; others need unlocking or the parent switch', () async {
    final s = await Store.open(dir);
    final c = s.addChild(nickname: 'a', ageGroup: '2-3', buddy: Buddy.milo);
    final core = aacCards.where((x) => x.core).length;
    expect(c.availableCards, hasLength(core));
    expect(c.availableCards.map((x) => x.id), containsAll(['more', 'help', 'all_done', 'yes', 'no']));
    c.settings.unlockAllCards = true;
    expect(c.availableCards, hasLength(aacCards.length));
  });

  test('every card and target reference resolves, with a picture on disk', () {
    for (final t in targets) {
      for (final id in t.cards) {
        expect(cardById(id), isNotNull, reason: '${t.id} -> $id');
      }
    }
    for (final c in aacCards) {
      expect(File(c.asset).existsSync(), isTrue, reason: c.asset);
    }
    expect(targets.map((t) => t.id).toSet(), hasLength(targets.length));
    expect(aacCards.map((c) => c.id).toSet(), hasLength(aacCards.length));
  });

  test('observer hears every change', () async {
    final s = await Store.open(dir);
    final o = RecordingObserver();
    s.observer = o;
    final c = s.addChild(nickname: 'a', ageGroup: '2-3', buddy: Buddy.milo);
    s.addSession(c, session(c));
    await s.deleteChild(c);
    expect(o.changed, contains(c.id));
    expect(o.sessions, hasLength(1));
    expect(o.deleted, [c.id]);
    expect(s.isSetUp, isFalse);
  });

  test('sessions are capped but totals are kept forever', () async {
    final s = await Store.open(dir);
    final c = s.addChild(nickname: 'a', ageGroup: '2-3', buddy: Buddy.milo);
    for (var i = 0; i < ChildProfile.maxSessions + 20; i++) {
      s.addSession(c, session(c, seconds: 10, vocal: 1));
    }
    expect(c.sessions, hasLength(ChildProfile.maxSessions));
    expect(c.totalSessions, ChildProfile.maxSessions + 20);
    expect(c.totalVocalizations, ChildProfile.maxSessions + 20);
  });

  test('reset clears progress but keeps the profile and settings', () async {
    final s = await Store.open(dir);
    final c = s.addChild(nickname: 'a', ageGroup: '2-3', buddy: Buddy.milo);
    c.settings.calmMode = true;
    s.addSession(c, session(c));
    s.recordCompletion(c, targets.first);
    s.resetProgress(c);
    expect(c.sessions, isEmpty);
    expect(c.practised, isEmpty);
    expect(c.unlockedCards, isEmpty);
    expect(c.totalSeconds, 0);
    expect(c.settings.calmMode, isTrue);
  });

  test('merging a cloud copy unions sessions and keeps the newer profile', () async {
    final s = await Store.open(dir);
    final c = s.addChild(nickname: 'Local', ageGroup: '2-3', buddy: Buddy.milo);
    final shared = session(c);
    s.addSession(c, shared);
    s.addSession(c, session(c));

    final remote = ChildProfile.fromJson(c.toJson())
      ..nickname = 'Remote'
      ..updatedAt = DateTime.now().add(const Duration(minutes: 5))
      ..sessions.removeWhere((x) => x.id != shared.id);
    remote.sessions.add(session(c, start: DateTime.now().subtract(const Duration(days: 1))));
    remote.practised['oo'] = 3;
    s.mergeRemote(remote);
    expect(c.nickname, 'Remote');
    expect(c.sessions, hasLength(3));
    expect(c.practised['oo'], 3);

    final stranger = ChildProfile(id: 'other', nickname: 'New', ageGroup: '6+', buddy: Buddy.pip);
    s.mergeRemote(stranger);
    expect(s.children, hasLength(2));
  });

  test('clearAll forgets everything', () async {
    final s = await Store.open(dir);
    s.addChild(nickname: 'a', ageGroup: '2-3', buddy: Buddy.milo);
    await s.clearAll();
    expect((await Store.open(dir)).isSetUp, isFalse);
  });

  test('bad values in stored settings are clamped', () {
    final st = ChildSettings.fromJson({'sensitivity': 99, 'daily_minutes': -5, 'level': 'nonsense'});
    expect(st.sensitivity, 2.0);
    expect(st.dailyMinutes, 0);
    expect(st.level, PlayLevel.explore);
    expect(ChildProfile.fromJson({'id': 'x', 'age_group': '99'}).ageGroup, '2-3');
  });

  group('session tracker', () {
    late Store s;
    late ChildProfile c;
    late DateTime now;
    late SessionTracker t;

    setUp(() async {
      s = await Store.open(dir);
      c = s.addChild(nickname: 'a', ageGroup: '2-3', buddy: Buddy.milo);
      now = DateTime(2026, 9, 24, 10);
      t = SessionTracker(s, now: () => now);
    });

    test('a visit is saved with its duration, attempts and completions', () {
      t.begin(c, 'safari', target: 'ah');
      t.attempt();
      t.completion();
      now = now.add(const Duration(seconds: 42));
      t.end();
      expect(c.sessions.single.durationSeconds, 42);
      expect(c.sessions.single.successRate, 1);
      expect(c.sessions.single.target, 'ah');
    });

    test('accidental 2-second visits are dropped', () {
      t.begin(c, 'spark');
      now = now.add(const Duration(seconds: 2));
      t.end();
      expect(c.sessions, isEmpty);
    });

    test('a closing screen cannot end its successor\'s visit', () {
      final first = t.begin(c, 'safari', target: 'ah');
      now = now.add(const Duration(seconds: 30));
      final second = t.begin(c, 'safari', target: 'mmm');
      t.end(first); // stale dispose: ignored
      expect(t.current, same(second));
      now = now.add(const Duration(seconds: 20));
      t.end(second);
      expect(c.sessions.map((x) => x.target), ['ah', 'mmm']);
    });

    test('daily limit counts today only, and a grown-up can extend it', () {
      c.settings.dailyMinutes = 10;
      s.addSession(c, session(c, start: now.subtract(const Duration(days: 1)), seconds: 3000));
      expect(t.limitReached(c), isFalse);
      s.addSession(c, session(c, start: now.subtract(const Duration(hours: 1)), seconds: 590));
      t.begin(c, 'spark');
      expect(t.limitReached(c), isFalse);
      now = now.add(const Duration(seconds: 15));
      expect(t.limitReached(c), isTrue);
      t.extend(c);
      expect(t.limitReached(c), isFalse);
      expect(t.timeUp.value, isFalse);
    });
  });
}
