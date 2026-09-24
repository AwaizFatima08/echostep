import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import '../core/content.dart';
import '../models/child.dart';

/// Receives every change so it can be mirrored to the cloud.
abstract class StoreObserver {
  void childChanged(ChildProfile child);
  void childDeleted(String childId);
  void sessionAdded(ChildProfile child, SessionRecord session);
}

/// Everything the app remembers, as one JSON file on this device. This is
/// the source of truth: the app never waits for the network. Cloud sync
/// (when on) mirrors it through [observer].
class Store extends ChangeNotifier {
  Store._(this._file);

  final File _file;
  final List<ChildProfile> children = [];
  AppSettings settings = AppSettings();
  String? _activeId;
  StoreObserver? observer;

  static Future<Store> open([Directory? dir]) async {
    final d = dir ?? await getApplicationDocumentsDirectory();
    final s = Store._(File('${d.path}/echosteps.json'));
    await s._load();
    return s;
  }

  static final _rand = math.Random.secure();

  /// Random, URL-safe id (also used as the Firestore document id).
  static String newId() {
    const chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
    return List.generate(20, (_) => chars[_rand.nextInt(chars.length)]).join();
  }

  bool get isSetUp => children.isNotEmpty;

  ChildProfile? get active {
    for (final c in children) {
      if (c.id == _activeId) return c;
    }
    return children.isEmpty ? null : children.first;
  }

  set active(ChildProfile? c) {
    _activeId = c?.id;
    save();
  }

  ChildProfile? childById(String id) {
    for (final c in children) {
      if (c.id == id) return c;
    }
    return null;
  }

  Future<void> _load() async {
    try {
      if (!await _file.exists()) return;
      final j = jsonDecode(await _file.readAsString()) as Map<String, dynamic>;
      children
        ..clear()
        ..addAll([
          for (final c in (j['children'] as List?) ?? const [])
            ChildProfile.fromJson((c as Map).cast<String, dynamic>()),
        ]);
      settings = AppSettings.fromJson((j['settings'] as Map?)?.cast<String, dynamic>());
      _activeId = j['active'] as String?;
    } catch (e) {
      // A corrupt file must never lock a child out of the app. Keep a copy
      // for debugging and start fresh (the cloud copy, if any, can restore).
      debugPrint('store load failed: $e');
      try {
        await _file.rename('${_file.path}.corrupt');
      } catch (_) {}
    }
  }

  Future<void>? _pending;
  bool _dirty = false;

  /// Saves soon; bursts of changes coalesce into one write, and writes never
  /// overlap.
  Future<void> save() {
    notifyListeners();
    _dirty = true;
    return _pending ??= _writeLoop();
  }

  /// Completes when everything so far is on disk.
  Future<void> flush() async {
    while (_pending != null) {
      await _pending;
    }
  }

  Future<void> _writeLoop() async {
    try {
      while (_dirty) {
        await Future<void>.delayed(const Duration(milliseconds: 150));
        _dirty = false;
        final j = {
          'version': 1,
          'children': [for (final c in children) c.toJson()],
          'settings': settings.toJson(),
          'active': _activeId,
        };
        final tmp = File('${_file.path}.tmp');
        await tmp.writeAsString(jsonEncode(j), flush: true);
        await tmp.rename(_file.path);
      }
    } catch (e) {
      debugPrint('store save failed: $e');
    } finally {
      _pending = null;
    }
  }

  // ---- children ----

  ChildProfile addChild({required String nickname, required String ageGroup, required Buddy buddy}) {
    final c = ChildProfile(
      id: newId(),
      nickname: nickname.trim().substring(0, math.min(24, nickname.trim().length)),
      ageGroup: ageGroup,
      buddy: buddy,
      settings: ChildSettings(level: ageGroup == '6+' ? PlayLevel.practise : PlayLevel.explore),
    );
    children.add(c);
    _activeId = c.id;
    save();
    observer?.childChanged(c);
    return c;
  }

  /// Call after changing any of [c]'s fields or settings.
  void childUpdated(ChildProfile c) {
    c.touch();
    save();
    observer?.childChanged(c);
  }

  Future<void> deleteChild(ChildProfile c) async {
    children.remove(c);
    if (_activeId == c.id) _activeId = children.isEmpty ? null : children.first.id;
    await save();
    observer?.childDeleted(c.id);
  }

  /// Clears a child's history but keeps the profile and settings.
  void resetProgress(ChildProfile c) {
    c.practised.clear();
    c.mastered.clear();
    c.unlockedCards.clear();
    c.sessions.clear();
    c
      ..totalVocalizations = 0
      ..totalSeconds = 0
      ..totalVoiceSeconds = 0
      ..totalSessions = 0;
    childUpdated(c);
  }

  // ---- progress ----

  /// Adds a finished session and folds it into the child's totals.
  void addSession(ChildProfile c, SessionRecord s) {
    c.sessions.add(s);
    if (c.sessions.length > ChildProfile.maxSessions) {
      c.sessions.removeRange(0, c.sessions.length - ChildProfile.maxSessions);
    }
    c
      ..totalSessions += 1
      ..totalSeconds += s.durationSeconds
      ..totalVocalizations += s.vocalizations
      ..totalVoiceSeconds += s.voiceSeconds;
    c.touch();
    save();
    observer?.sessionAdded(c, s);
    observer?.childChanged(c);
  }

  /// Records a completed Echo Safari stop; returns the cards it newly
  /// unlocked (empty on repeat visits).
  List<AacCard> recordCompletion(ChildProfile c, SoundTarget t) {
    c.practised[t.id] = (c.practised[t.id] ?? 0) + 1;
    final fresh = <AacCard>[];
    for (final id in t.cards) {
      if (c.unlockedCards.add(id)) {
        final card = cardById(id);
        if (card != null) fresh.add(card);
      }
    }
    childUpdated(c);
    return fresh;
  }

  void setMastered(ChildProfile c, String targetId, bool mastered) {
    if (mastered) {
      c.mastered.add(targetId);
    } else {
      c.mastered.remove(targetId);
    }
    childUpdated(c);
  }

  /// Marks sessions as written to the cloud.
  void markSynced(Iterable<SessionRecord> sessions) {
    var any = false;
    for (final s in sessions) {
      if (!s.synced) {
        s.synced = true;
        any = true;
      }
    }
    if (any) save();
  }

  // ---- cloud restore ----

  /// Merges a child downloaded from the cloud: unknown children are added;
  /// known ones take whichever profile is newer, union their sessions and
  /// progress, and keep the larger totals.
  void mergeRemote(ChildProfile remote) {
    final local = childById(remote.id);
    for (final s in remote.sessions) {
      s.synced = true;
    }
    if (local == null) {
      children.add(remote);
      _activeId ??= remote.id;
      save();
      return;
    }
    final known = {for (final s in local.sessions) s.id};
    local.sessions
      ..addAll(remote.sessions.where((s) => !known.contains(s.id)))
      ..sort((a, b) => a.start.compareTo(b.start));
    if (remote.updatedAt.isAfter(local.updatedAt)) {
      local
        ..nickname = remote.nickname
        ..ageGroup = remote.ageGroup
        ..buddy = remote.buddy
        ..settings = remote.settings
        ..updatedAt = remote.updatedAt;
      local.mastered
        ..clear()
        ..addAll(remote.mastered);
    }
    for (final e in remote.practised.entries) {
      local.practised[e.key] = math.max(local.practised[e.key] ?? 0, e.value);
    }
    local.unlockedCards.addAll(remote.unlockedCards);
    local
      ..totalVocalizations = math.max(local.totalVocalizations, remote.totalVocalizations)
      ..totalSeconds = math.max(local.totalSeconds, remote.totalSeconds)
      ..totalVoiceSeconds = math.max(local.totalVoiceSeconds, remote.totalVoiceSeconds)
      ..totalSessions = math.max(local.totalSessions, remote.totalSessions);
    save();
  }

  /// Forgets everything on this device (sign-out, account deletion).
  Future<void> clearAll() async {
    children.clear();
    _activeId = null;
    await save();
    await flush();
  }
}
