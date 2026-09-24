import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../models/child.dart';
import 'store.dart';

enum CloudMode {
  /// Firebase isn't available on this device (or in tests).
  unavailable,

  /// The grown-up switched cloud backup off.
  off,

  /// Backup is on but not signed in yet (usually offline); retrying.
  waiting,

  /// Backed up under a silent guest (anonymous) account.
  guest,

  /// Backed up under the grown-up's email account (works across devices).
  linked,
}

@immutable
class CloudState {
  const CloudState(this.mode, {this.email, this.lastSync});
  final CloudMode mode;
  final String? email;
  final DateTime? lastSync;

  bool get active => mode == CloudMode.guest || mode == CloudMode.linked;
}

/// A readable message for an auth failure, for the grown-up's screens.
String authMessage(Object e) {
  if (e is FirebaseAuthException) {
    return switch (e.code) {
      'email-already-in-use' || 'credential-already-in-use' =>
        'That email already has an EchoSteps account. Use "I already have an account" instead.',
      'invalid-email' => 'That email address doesn\'t look right.',
      'weak-password' => 'Please choose a longer password (at least 8 characters).',
      'wrong-password' ||
      'invalid-credential' ||
      'user-not-found' ||
      'INVALID_LOGIN_CREDENTIALS' => 'The email or password is not correct.',
      'too-many-requests' => 'Too many tries. Please wait a few minutes and try again.',
      'network-request-failed' => 'No internet connection. Please connect and try again.',
      'requires-recent-login' => 'Please enter your password again to confirm.',
      _ => 'Something went wrong (${e.code}). Please try again.',
    };
  }
  if (e is StateError) return e.message;
  return 'Something went wrong. Please try again.';
}

/// Mirrors the local store to Firestore under `users/{uid}/children/...`.
///
/// Local-first: the store is always the source of truth, every cloud call is
/// fire-and-forget or awaited only on the grown-up's account screens, and
/// Firestore's offline queue carries writes made without a connection.
class CloudSync implements StoreObserver {
  CloudSync({required this.store, this.auth, this.db}) {
    store.observer = this;
  }

  final Store store;
  final FirebaseAuth? auth;
  final FirebaseFirestore? db;

  final state = ValueNotifier<CloudState>(const CloudState(CloudMode.unavailable));
  Timer? _retry;
  bool _signingIn = false;

  bool get available => auth != null && db != null;
  User? get user => auth?.currentUser;
  bool get _on => available && store.settings.cloudBackup;

  DocumentReference<Map<String, dynamic>> _userDoc(String uid) => db!.collection('users').doc(uid);
  CollectionReference<Map<String, dynamic>> _children(String uid) => _userDoc(uid).collection('children');
  CollectionReference<Map<String, dynamic>> _sessions(String uid, String childId) =>
      _children(uid).doc(childId).collection('sessions');

  /// Called once at launch.
  Future<void> start() async {
    if (!available) {
      state.value = const CloudState(CloudMode.unavailable);
      return;
    }
    if (!store.settings.cloudBackup) {
      state.value = const CloudState(CloudMode.off);
      return;
    }
    await _ensureSignedIn();
  }

  void _publish() {
    final u = user;
    if (!available) {
      state.value = const CloudState(CloudMode.unavailable);
    } else if (!store.settings.cloudBackup) {
      state.value = const CloudState(CloudMode.off);
    } else if (u == null) {
      state.value = const CloudState(CloudMode.waiting);
    } else if (u.isAnonymous) {
      state.value = CloudState(CloudMode.guest, lastSync: state.value.lastSync);
    } else {
      state.value = CloudState(CloudMode.linked, email: u.email, lastSync: state.value.lastSync);
    }
  }

  Future<void> _ensureSignedIn() async {
    if (!_on || _signingIn) return;
    if (user == null) {
      // Nothing to back up yet: sign in once there is a child (onboarding
      // done), so opening the app never creates an empty account.
      if (!store.isSetUp) {
        _publish();
        return;
      }
      _signingIn = true;
      try {
        await auth!.signInAnonymously();
      } catch (e) {
        debugPrint('anonymous sign-in failed (offline?): $e');
        _publish();
        _retry ??= Timer.periodic(const Duration(minutes: 2), (_) => _ensureSignedIn());
        return;
      } finally {
        _signingIn = false;
      }
    }
    _retry?.cancel();
    _retry = null;
    _publish();
    unawaited(pushAll());
  }

  /// Writes the whole local store (idempotent; used after sign-in).
  Future<void> pushAll() async {
    final u = user;
    if (!_on || u == null) return;
    try {
      await _userDoc(u.uid).set({
        'schema': 1,
        'updated_at': FieldValue.serverTimestamp(),
        if (!await _userExists(u.uid)) 'created_at': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      for (final c in List.of(store.children)) {
        await _writeChild(u.uid, c);
        final pending = c.sessions.where((s) => !s.synced).toList();
        final batchSize = 400;
        for (var i = 0; i < pending.length; i += batchSize) {
          final chunk = pending.sublist(i, i + batchSize > pending.length ? pending.length : i + batchSize);
          final b = db!.batch();
          for (final s in chunk) {
            b.set(_sessions(u.uid, c.id).doc(s.id), sessionToCloud(s));
          }
          await b.commit();
          store.markSynced(chunk);
        }
      }
      state.value = CloudState(state.value.mode, email: state.value.email, lastSync: DateTime.now());
    } catch (e) {
      debugPrint('pushAll failed: $e');
    }
  }

  Future<bool> _userExists(String uid) async {
    try {
      return (await _userDoc(uid).get()).exists;
    } catch (_) {
      return true; // offline: don't overwrite created_at blindly
    }
  }

  Future<void> _writeChild(String uid, ChildProfile c) => _children(uid).doc(c.id).set(childToCloud(c));

  // ---- StoreObserver: write-through, never awaited by the UI ----

  @override
  void childChanged(ChildProfile child) {
    final u = user;
    if (!_on) return;
    if (u == null) {
      unawaited(_ensureSignedIn());
      return;
    }
    _writeChild(u.uid, child).then((_) => _stamp(), onError: (Object e) => debugPrint('child sync failed: $e'));
  }

  @override
  void sessionAdded(ChildProfile child, SessionRecord session) {
    final u = user;
    if (!_on || u == null) return;
    _sessions(u.uid, child.id).doc(session.id).set(sessionToCloud(session)).then((_) {
      store.markSynced([session]);
      _stamp();
    }, onError: (Object e) => debugPrint('session sync failed: $e'));
  }

  @override
  void childDeleted(String childId) {
    final u = user;
    if (!_on || u == null) return;
    unawaited(_deleteChildCloud(u.uid, childId));
  }

  void _stamp() => state.value = CloudState(state.value.mode, email: state.value.email, lastSync: DateTime.now());

  Future<void> _deleteChildCloud(String uid, String childId) async {
    try {
      while (true) {
        final snap = await _sessions(uid, childId).limit(400).get();
        if (snap.docs.isEmpty) break;
        final b = db!.batch();
        for (final d in snap.docs) {
          b.delete(d.reference);
        }
        await b.commit();
      }
      await _children(uid).doc(childId).delete();
    } catch (e) {
      debugPrint('child delete failed: $e');
    }
  }

  /// Deletes every cloud document of the signed-in account (not the local
  /// data and not the sign-in itself).
  Future<void> deleteCloudData() async {
    final u = user;
    if (!available || u == null) return;
    final kids = await _children(u.uid).get();
    for (final k in kids.docs) {
      await _deleteChildCloud(u.uid, k.id);
    }
    await _userDoc(u.uid).delete();
  }

  // ---- settings ----

  /// Turns cloud backup on or off. Turning it off keeps whatever is already
  /// in the cloud unless [deleteExisting] is true.
  Future<void> setBackup(bool on, {bool deleteExisting = false}) async {
    if (!on && deleteExisting) {
      try {
        await deleteCloudData();
      } catch (e) {
        debugPrint('delete cloud data failed: $e');
      }
    }
    store.settings.cloudBackup = on;
    await store.save();
    if (on) {
      await _ensureSignedIn();
    } else {
      _retry?.cancel();
      _retry = null;
    }
    _publish();
  }

  // ---- account upgrade (Parent Zone) ----

  /// Keeps the current guest account and adds an email + password to it, so
  /// the same progress can be restored on another device.
  Future<void> createAccount(String email, String password) async {
    _requireAvailable();
    if (user == null) await auth!.signInAnonymously();
    final cred = EmailAuthProvider.credential(email: email.trim(), password: password);
    await user!.linkWithCredential(cred);
    await user!.reload();
    if (!store.settings.cloudBackup) {
      store.settings.cloudBackup = true;
      await store.save();
    }
    _publish();
    await pushAll();
  }

  /// Signs in to an existing account and merges this device's children into
  /// it, then downloads the account's children.
  Future<void> signIn(String email, String password) async {
    _requireAvailable();
    final previous = user;
    final wasGuest = previous != null && previous.isAnonymous;
    // The guest copy in the cloud duplicates local data; remove it so no
    // orphaned child data is left behind once we switch accounts.
    if (wasGuest) {
      try {
        await deleteCloudData();
      } catch (e) {
        debugPrint('guest cleanup failed: $e');
      }
    }
    try {
      await auth!.signInWithEmailAndPassword(email: email.trim(), password: password);
    } catch (_) {
      // Still signed in as the guest: put the guest copy back.
      if (wasGuest) unawaited(pushAll());
      rethrow;
    }
    if (!store.settings.cloudBackup) {
      store.settings.cloudBackup = true;
    }
    for (final c in store.children) {
      for (final s in c.sessions) {
        s.synced = false;
      }
    }
    await store.save();
    _publish();
    await pushAll();
    await pullAll();
  }

  Future<void> sendPasswordReset(String email) async {
    _requireAvailable();
    await auth!.sendPasswordResetEmail(email: email.trim());
  }

  /// Downloads every child (and recent sessions) of the signed-in account
  /// and merges them into the local store.
  Future<int> pullAll() async {
    final u = user;
    if (!available || u == null) return 0;
    final kids = await _children(u.uid).get();
    for (final k in kids.docs) {
      final sessions = await _sessions(
        u.uid,
        k.id,
      ).orderBy('timestamp', descending: true).limit(ChildProfile.maxSessions).get();
      store.mergeRemote(
        childFromCloud(k.id, k.data(), [
          for (final s in sessions.docs.reversed) sessionFromCloud(s.id, k.id, s.data()),
        ]),
      );
    }
    await store.flush();
    _stamp();
    return kids.docs.length;
  }

  /// Signs out and removes all children from this device (their progress
  /// stays in the account).
  Future<void> signOut() async {
    if (!available) return;
    await auth!.signOut();
    await store.clearAll();
    _publish();
  }

  /// Deletes the account, all its cloud data and everything on this device.
  /// Linked accounts must confirm with their [password].
  Future<void> deleteAccount({String? password}) async {
    _requireAvailable();
    final u = user;
    if (u != null) {
      if (!u.isAnonymous && password != null && u.email != null) {
        await u.reauthenticateWithCredential(EmailAuthProvider.credential(email: u.email!, password: password));
      }
      await deleteCloudData();
      await u.delete();
    }
    await store.clearAll();
    _publish();
  }

  void _requireAvailable() {
    if (!available) throw StateError('Cloud backup isn\'t available on this device.');
  }

  void dispose() {
    _retry?.cancel();
  }

  // ---- Firestore mapping (field names follow the PDD schema) ----

  static Map<String, dynamic> childToCloud(ChildProfile c) => {
    'nickname': c.nickname,
    'age_group': c.ageGroup,
    'avatar_id': c.buddy.id,
    'created_at': Timestamp.fromDate(c.createdAt),
    'updated_at': Timestamp.fromDate(c.updatedAt),
    'stats': c.statsJson(),
    'practised_sounds': c.practised,
    'mastered_sounds': c.mastered.toList(),
    'unlocked_cards': c.unlockedCards.toList(),
    'settings': c.settings.toJson(),
  };

  static Map<String, dynamic> sessionToCloud(SessionRecord s) => {
    'child_id': s.childId,
    'timestamp': Timestamp.fromDate(s.start),
    'duration_seconds': s.durationSeconds,
    'vocalization_count': s.vocalizations,
    'voice_seconds': double.parse(s.voiceSeconds.toStringAsFixed(1)),
    'avg_volume_db': double.parse(s.avgDb.toStringAsFixed(1)),
    'mode': s.mode,
    'target_sound': s.target,
    'attempts': s.attempts,
    'completions': s.completions,
    'success_rate': double.parse(s.successRate.toStringAsFixed(3)),
  };

  static DateTime? _date(Object? v) => v is Timestamp ? v.toDate() : null;

  static ChildProfile childFromCloud(String id, Map<String, dynamic> d, List<SessionRecord> sessions) {
    final j = {
      ...d,
      'id': id,
      'created_at': _date(d['created_at'])?.toUtc().toIso8601String(),
      'updated_at': _date(d['updated_at'])?.toUtc().toIso8601String(),
    };
    return ChildProfile.fromJson(j)..sessions.addAll(sessions);
  }

  static SessionRecord sessionFromCloud(String id, String childId, Map<String, dynamic> d) => SessionRecord(
    id: id,
    childId: childId,
    start: _date(d['timestamp']) ?? DateTime.now(),
    mode: d['mode'] as String? ?? 'spark',
    durationSeconds: (d['duration_seconds'] as num?)?.toInt() ?? 0,
    vocalizations: (d['vocalization_count'] as num?)?.toInt() ?? 0,
    voiceSeconds: (d['voice_seconds'] as num?)?.toDouble() ?? 0,
    avgDb: (d['avg_volume_db'] as num?)?.toDouble() ?? -120,
    target: d['target_sound'] as String?,
    attempts: (d['attempts'] as num?)?.toInt() ?? 0,
    completions: (d['completions'] as num?)?.toInt() ?? 0,
    synced: true,
  );
}
