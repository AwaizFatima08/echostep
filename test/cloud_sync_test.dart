import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:echosteps/models/child.dart';
import 'package:echosteps/services/cloud_sync.dart';
import 'package:echosteps/services/store.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter_test/flutter_test.dart';

/// Lets fire-and-forget writes complete.
Future<void> settle() => Future<void>.delayed(const Duration(milliseconds: 50));

void main() {
  late Directory dir;
  late Store store;
  late FakeFirebaseFirestore db;
  late MockFirebaseAuth auth;
  late CloudSync sync;

  setUp(() async {
    dir = Directory.systemTemp.createTempSync('es_cloud');
    store = await Store.open(dir);
    db = FakeFirebaseFirestore();
    auth = MockFirebaseAuth();
    sync = CloudSync(store: store, auth: auth, db: db);
  });

  tearDown(() async {
    sync.dispose();
    await Future<void>.delayed(const Duration(milliseconds: 400));
    dir.deleteSync(recursive: true);
  });

  CollectionReference<Map<String, dynamic>> kids() =>
      db.collection('users').doc(auth.currentUser!.uid).collection('children');

  SessionRecord session(ChildProfile c, {String? target}) => SessionRecord(
    id: Store.newId(),
    childId: c.id,
    start: DateTime(2026, 9, 24, 10),
    mode: target == null ? 'spark' : 'safari',
    durationSeconds: 90,
    vocalizations: 7,
    voiceSeconds: 21.37,
    avgDb: -19.94,
    target: target,
    attempts: target == null ? 0 : 2,
    completions: target == null ? 0 : 1,
  );

  test('without Firebase the app runs local-only', () async {
    final offline = CloudSync(store: store);
    await offline.start();
    expect(offline.state.value.mode, CloudMode.unavailable);
    store.addChild(nickname: 'a', ageGroup: '2-3', buddy: Buddy.milo); // must not throw
  });

  test('no account is created before a child exists', () async {
    await sync.start();
    expect(auth.currentUser, isNull);
    expect(sync.state.value.mode, CloudMode.waiting);
  });

  test('adding a child signs in silently and backs it up', () async {
    await sync.start();
    final c = store.addChild(nickname: 'Leo', ageGroup: '4-5', buddy: Buddy.pip);
    await settle();
    expect(auth.currentUser, isNotNull);
    expect(sync.state.value.mode, CloudMode.guest);
    final doc = await kids().doc(c.id).get();
    expect(doc.exists, isTrue);
    final d = doc.data()!;
    // PDD schema field names; no email, no audio.
    expect(d['nickname'], 'Leo');
    expect(d['age_group'], '4-5');
    expect(d['avatar_id'], 'pip_bird');
    expect(d['stats'], containsPair('total_minutes_played', 0));
    expect(d.keys, isNot(contains('parent_email')));
    final user = await db.collection('users').doc(auth.currentUser!.uid).get();
    expect(user.data()!['schema'], 1);
  });

  test('sessions are mirrored with the PDD fields and marked synced', () async {
    await sync.start();
    final c = store.addChild(nickname: 'Leo', ageGroup: '4-5', buddy: Buddy.milo);
    await settle();
    final s = session(c, target: 'ah');
    store.addSession(c, s);
    await settle();
    final d = (await kids().doc(c.id).collection('sessions').doc(s.id).get()).data()!;
    expect(d['child_id'], c.id);
    expect(d['timestamp'], isA<Timestamp>());
    expect(d['duration_seconds'], 90);
    expect(d['vocalization_count'], 7);
    expect(d['avg_volume_db'], -19.9);
    expect(d['target_sound'], 'ah');
    expect(d['success_rate'], 0.5);
    expect(d['mode'], 'safari');
    expect(s.synced, isTrue);
  });

  test('sessions recorded before sign-in are uploaded later by pushAll', () async {
    final c = store.addChild(nickname: 'a', ageGroup: '2-3', buddy: Buddy.milo);
    store.addSession(c, session(c));
    store.addSession(c, session(c));
    expect(c.sessions.every((s) => !s.synced), isTrue);
    await sync.start();
    await settle();
    await sync.pushAll();
    expect((await kids().doc(c.id).collection('sessions').get()).docs, hasLength(2));
    expect(c.sessions.every((s) => s.synced), isTrue);
  });

  test('removing a child deletes its cloud copy', () async {
    await sync.start();
    final c = store.addChild(nickname: 'a', ageGroup: '2-3', buddy: Buddy.milo);
    await settle();
    store.addSession(c, session(c));
    await settle();
    await store.deleteChild(c);
    await settle();
    expect((await kids().doc(c.id).get()).exists, isFalse);
    expect((await kids().doc(c.id).collection('sessions').get()).docs, isEmpty);
  });

  test('turning backup off can delete the cloud copy', () async {
    await sync.start();
    final c = store.addChild(nickname: 'a', ageGroup: '2-3', buddy: Buddy.milo);
    await settle();
    store.addSession(c, session(c));
    await settle();
    await sync.setBackup(false, deleteExisting: true);
    expect(sync.state.value.mode, CloudMode.off);
    expect((await kids().get()).docs, isEmpty);
    // Nothing more is written while off.
    store.addSession(c, session(c));
    await settle();
    expect((await kids().get()).docs, isEmpty);
    expect(store.isSetUp, isTrue, reason: 'local data stays');
  });

  test('cloud copy round-trips into a fresh device', () async {
    await sync.start();
    final c = store.addChild(nickname: 'Leo', ageGroup: '6+', buddy: Buddy.pip);
    c.settings.calmMode = true;
    store.childUpdated(c);
    store.recordCompletion(c, store.children.first.suggestedTarget);
    store.setMastered(c, 'ah', true);
    store.addSession(c, session(c, target: 'ah'));
    await settle();

    // A second device signed in to the same account.
    final dir2 = Directory.systemTemp.createTempSync('es_cloud2');
    final store2 = await Store.open(dir2);
    final sync2 = CloudSync(store: store2, auth: auth, db: db);
    expect(await sync2.pullAll(), 1);
    final r = store2.children.single;
    expect(r.nickname, 'Leo');
    expect(r.ageGroup, '6+');
    expect(r.buddy, Buddy.pip);
    expect(r.settings.calmMode, isTrue);
    expect(r.practised['ah'], 1);
    expect(r.mastered, contains('ah'));
    expect(r.unlockedCards, isNotEmpty);
    expect(r.sessions.single.target, 'ah');
    expect(r.sessions.single.synced, isTrue);
    await Future<void>.delayed(const Duration(milliseconds: 400));
    dir2.deleteSync(recursive: true);
  });

  test('deleting everything clears the cloud and the device', () async {
    await sync.start();
    final c = store.addChild(nickname: 'a', ageGroup: '2-3', buddy: Buddy.milo);
    await settle();
    store.addSession(c, session(c));
    await settle();
    final uid = auth.currentUser!.uid;
    await sync.deleteAccount();
    expect((await db.collection('users').doc(uid).get()).exists, isFalse);
    expect((await db.collection('users').doc(uid).collection('children').get()).docs, isEmpty);
    expect(store.isSetUp, isFalse);
  });

  test('friendly messages for auth errors', () {
    expect(authMessage(Exception('x')), contains('Something went wrong'));
    expect(authMessage(StateError('Cloud backup isn\'t available')), contains('available'));
  });
}
