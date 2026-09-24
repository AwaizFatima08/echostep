// Security-rules tests for firebase/firestore.rules, run against the
// Firestore emulator:
//
//   cd firebase/rules-test && npm install
//   JAVA_HOME=~/jdks/jdk-21.0.12.1+1 firebase emulators:exec --only firestore "npm test" --project demo-echosteps
import { readFileSync } from 'node:fs';
import { after, before, beforeEach, describe, test } from 'node:test';

import { assertFails, assertSucceeds, initializeTestEnvironment } from '@firebase/rules-unit-testing';
import { deleteDoc, doc, getDoc, getDocs, collection, setDoc, Timestamp } from 'firebase/firestore';

let env;

const child = (extra = {}) => ({
  nickname: 'Leo',
  age_group: '4-5',
  avatar_id: 'milo_bear',
  created_at: Timestamp.now(),
  updated_at: Timestamp.now(),
  stats: { total_vocalizations: 10, total_seconds_played: 60, total_minutes_played: 1, total_voice_seconds: 12.5, total_sessions: 1 },
  practised_sounds: { ah: 1 },
  mastered_sounds: ['ah'],
  unlocked_cards: ['car', 'potty', 'star'],
  settings: { level: 'explore', sensitivity: 1, calm_mode: false, prompts_on: true, daily_minutes: 0, unlock_all_cards: false },
  ...extra,
});

const session = (childId, extra = {}) => ({
  child_id: childId,
  timestamp: Timestamp.now(),
  duration_seconds: 90,
  vocalization_count: 7,
  voice_seconds: 21.4,
  avg_volume_db: -19.9,
  mode: 'safari',
  target_sound: 'ah',
  attempts: 2,
  completions: 1,
  success_rate: 0.5,
  ...extra,
});

before(async () => {
  env = await initializeTestEnvironment({
    projectId: 'demo-echosteps',
    firestore: { rules: readFileSync('../firestore.rules', 'utf8'), host: '127.0.0.1', port: 8085 },
  });
});
after(() => env.cleanup());
beforeEach(() => env.clearFirestore());

const as = (uid) => env.authenticatedContext(uid).firestore();

describe('ownership', () => {
  test('a parent can write and read their own child and sessions', async () => {
    const db = as('alice');
    await assertSucceeds(setDoc(doc(db, 'users/alice'), { schema: 1, created_at: Timestamp.now(), updated_at: Timestamp.now() }));
    await assertSucceeds(setDoc(doc(db, 'users/alice/children/c1'), child()));
    await assertSucceeds(setDoc(doc(db, 'users/alice/children/c1/sessions/s1'), session('c1')));
    await assertSucceeds(getDoc(doc(db, 'users/alice/children/c1')));
    await assertSucceeds(getDocs(collection(db, 'users/alice/children/c1/sessions')));
  });

  test('nobody else can read or write them', async () => {
    await env.withSecurityRulesDisabled(async (ctx) => {
      await setDoc(doc(ctx.firestore(), 'users/alice/children/c1'), child());
      await setDoc(doc(ctx.firestore(), 'users/alice/children/c1/sessions/s1'), session('c1'));
    });
    const bob = as('bob');
    await assertFails(getDoc(doc(bob, 'users/alice/children/c1')));
    await assertFails(getDocs(collection(bob, 'users/alice/children')));
    await assertFails(getDoc(doc(bob, 'users/alice/children/c1/sessions/s1')));
    await assertFails(setDoc(doc(bob, 'users/alice/children/c2'), child()));
    await assertFails(deleteDoc(doc(bob, 'users/alice/children/c1')));
  });

  test('signed-out users get nothing', async () => {
    const anon = env.unauthenticatedContext().firestore();
    await assertFails(getDoc(doc(anon, 'users/alice/children/c1')));
    await assertFails(setDoc(doc(anon, 'users/alice/children/c1'), child()));
  });

  test('a parent can delete everything they own', async () => {
    const db = as('alice');
    await setDoc(doc(db, 'users/alice'), { schema: 1 });
    await setDoc(doc(db, 'users/alice/children/c1'), child());
    await setDoc(doc(db, 'users/alice/children/c1/sessions/s1'), session('c1'));
    await assertSucceeds(deleteDoc(doc(db, 'users/alice/children/c1/sessions/s1')));
    await assertSucceeds(deleteDoc(doc(db, 'users/alice/children/c1')));
    await assertSucceeds(deleteDoc(doc(db, 'users/alice')));
  });

  test('anything outside users/{uid} is denied', async () => {
    const db = as('alice');
    await assertFails(setDoc(doc(db, 'sessions/s1'), session('c1')));
    await assertFails(getDocs(collection(db, 'users')));
  });
});

describe('shape checks', () => {
  test('unknown fields (like an email) are rejected', async () => {
    const db = as('alice');
    await assertFails(setDoc(doc(db, 'users/alice'), { schema: 1, parent_email: 'x@example.com' }));
    await assertFails(setDoc(doc(db, 'users/alice/children/c1'), child({ real_name: 'Leonard Smith' })));
    await assertFails(setDoc(doc(db, 'users/alice/children/c1/sessions/s1'), session('c1', { audio: 'base64...' })));
  });

  test('child fields are validated', async () => {
    const db = as('alice');
    await assertFails(setDoc(doc(db, 'users/alice/children/c1'), child({ nickname: 'x'.repeat(25) })));
    await assertFails(setDoc(doc(db, 'users/alice/children/c1'), child({ age_group: '12' })));
    await assertFails(setDoc(doc(db, 'users/alice/children/c1'), child({ unlocked_cards: 'all' })));
    const { nickname, ...noName } = child();
    await assertFails(setDoc(doc(db, 'users/alice/children/c1'), noName));
    await assertSucceeds(setDoc(doc(db, 'users/alice/children/c1'), child({ nickname: '' })));
  });

  test('sessions must belong to the child they are filed under and be sane', async () => {
    const db = as('alice');
    await assertFails(setDoc(doc(db, 'users/alice/children/c1/sessions/s1'), session('c2')));
    await assertFails(setDoc(doc(db, 'users/alice/children/c1/sessions/s1'), session('c1', { mode: 'hack' })));
    await assertFails(setDoc(doc(db, 'users/alice/children/c1/sessions/s1'), session('c1', { duration_seconds: 999999 })));
    await assertFails(setDoc(doc(db, 'users/alice/children/c1/sessions/s1'), session('c1', { success_rate: 3 })));
    await assertFails(setDoc(doc(db, 'users/alice/children/c1/sessions/s1'), session('c1', { vocalization_count: -1 })));
    await assertFails(setDoc(doc(db, 'users/alice/children/c1/sessions/s1'), session('c1', { timestamp: 'yesterday' })));
    await assertSucceeds(setDoc(doc(db, 'users/alice/children/c1/sessions/s1'), session('c1', { target_sound: null, mode: 'spark' })));
    // An offline retry of the same session is an allowed update.
    await assertSucceeds(setDoc(doc(db, 'users/alice/children/c1/sessions/s1'), session('c1', { target_sound: null, mode: 'spark' })));
  });
});
