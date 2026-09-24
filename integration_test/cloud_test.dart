// Cloud backup end-to-end with the real Firebase SDKs and security rules,
// against the local Firebase emulators (never the production project):
//
//   firebase emulators:start --only auth,firestore --project demo-echosteps
//   adb -s <device> reverse tcp:9099 tcp:9099
//   adb -s <device> reverse tcp:8085 tcp:8085
//   flutter drive --driver test_driver/integration_test.dart --target integration_test/cloud_test.dart -d <device>
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:echosteps/models/child.dart';
import 'package:echosteps/services/cloud_sync.dart';
import 'package:echosteps/services/store.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';

Future<void> settle([int ms = 1500]) => Future<void>.delayed(Duration(milliseconds: ms));

/// Polls [ok] for up to 30 s (a slow emulator talks to the host's Firebase
/// emulators through adb reverse).
Future<void> until(bool Function() ok) async {
  final end = DateTime.now().add(const Duration(seconds: 30));
  while (!ok() && DateTime.now().isBefore(end)) {
    await Future<void>.delayed(const Duration(milliseconds: 250));
  }
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  late FirebaseAuth auth;
  late FirebaseFirestore db;

  setUpAll(() async {
    await Firebase.initializeApp(
      options: const FirebaseOptions(
        apiKey: 'demo-key',
        appId: '1:1:android:1',
        messagingSenderId: '1',
        projectId: 'demo-echosteps',
      ),
    );
    auth = FirebaseAuth.instance;
    db = FirebaseFirestore.instance;
    await auth.useAuthEmulator('localhost', 9099);
    db.useFirestoreEmulator('localhost', 8085);
  });

  Future<Store> freshStore(String name) async {
    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory('${docs.path}/${name}_${DateTime.now().microsecondsSinceEpoch}')..createSync();
    return Store.open(dir);
  }

  SessionRecord session(ChildProfile c) => SessionRecord(
    id: Store.newId(),
    childId: c.id,
    start: DateTime.now(),
    mode: 'safari',
    durationSeconds: 75,
    vocalizations: 9,
    voiceSeconds: 18,
    avgDb: -21,
    target: 'ah',
    attempts: 1,
    completions: 1,
  );

  testWidgets('guest backup, account upgrade, restore on a new device, deletion', (tester) async {
    await auth.signOut();
    final email = 'parent${DateTime.now().millisecondsSinceEpoch}@example.com';

    // Device A: guest backup starts when the first child is added.
    final storeA = await freshStore('a');
    final syncA = CloudSync(store: storeA, auth: auth, db: db);
    await syncA.start();
    final c = storeA.addChild(nickname: 'Leo', ageGroup: '4-5', buddy: Buddy.pip);
    await until(() => syncA.state.value.mode == CloudMode.guest);
    await settle();
    expect(syncA.state.value.mode, CloudMode.guest);
    final guestUid = auth.currentUser!.uid;
    storeA.addSession(c, session(c));
    storeA.setMastered(c, 'ah', true);
    await settle();
    final cloudChild = await db.doc('users/$guestUid/children/${c.id}').get();
    expect(cloudChild.data()!['nickname'], 'Leo');
    expect((await db.collection('users/$guestUid/children/${c.id}/sessions').get()).docs, hasLength(1));

    // Upgrade: same UID, now with an email (nothing is lost).
    await syncA.createAccount(email, 'correct horse 42');
    expect(auth.currentUser!.uid, guestUid);
    expect(syncA.state.value.mode, CloudMode.linked);
    await syncA.signOut();
    expect(storeA.isSetUp, isFalse);

    // Device B: a wrong password is refused, the right one restores everything.
    final storeB = await freshStore('b');
    final syncB = CloudSync(store: storeB, auth: auth, db: db);
    await syncB.start();
    await expectLater(syncB.signIn(email, 'wrong password'), throwsA(isA<FirebaseAuthException>()));
    await syncB.signIn(email, 'correct horse 42');
    final r = storeB.children.single;
    expect(r.nickname, 'Leo');
    expect(r.buddy, Buddy.pip);
    expect(r.mastered, contains('ah'));
    expect(r.sessions, hasLength(1));

    // Deleting everything removes cloud data and the account.
    await syncB.deleteAccount(password: 'correct horse 42');
    expect(auth.currentUser, isNull);
    expect(storeB.isSetUp, isFalse);
    await auth.signInAnonymously(); // any signed-in user may try to read...
    await expectLater(db.doc('users/$guestUid/children/${c.id}').get(), throwsA(isA<FirebaseException>()));
    await auth.currentUser!.delete();
    await expectLater(
      auth.signInWithEmailAndPassword(email: email, password: 'correct horse 42'),
      throwsA(isA<FirebaseAuthException>()),
    );
  });

  testWidgets('another family cannot read this family\'s children', (tester) async {
    await auth.signOut();
    final storeA = await freshStore('x');
    final syncA = CloudSync(store: storeA, auth: auth, db: db);
    await syncA.start();
    final c = storeA.addChild(nickname: 'Mia', ageGroup: '2-3', buddy: Buddy.milo);
    await until(() => syncA.state.value.mode == CloudMode.guest);
    await settle();
    final uidA = auth.currentUser!.uid;
    await auth.signOut();
    await auth.signInAnonymously();
    expect(auth.currentUser!.uid, isNot(uidA));
    await expectLater(db.doc('users/$uidA/children/${c.id}').get(), throwsA(isA<FirebaseException>()));
    await expectLater(
      db.doc('users/$uidA/children/${c.id}').set({'nickname': 'x', 'age_group': '2-3', 'avatar_id': 'milo_bear'}),
      throwsA(isA<FirebaseException>()),
    );
  });
}
