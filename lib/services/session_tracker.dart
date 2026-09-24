import 'dart:async';

import 'package:clock/clock.dart';
import 'package:flutter/foundation.dart';

import '../core/audio/voice_analyzer.dart';
import '../models/child.dart';
import 'store.dart';

/// Records one activity visit (Sound Spark, an Echo Safari stop, the card
/// wall) for the parent dashboard, and enforces the optional daily limit.
class SessionTracker {
  // package:clock follows fake time in tests and the real clock in the app.
  SessionTracker(this._store, {DateTime Function()? now}) : _now = now ?? clock.now;

  final Store _store;
  final DateTime Function() _now;
  ChildProfile? _child;
  SessionRecord? _record;
  DateTime? _startedAt;
  Timer? _timer;
  double _dbSum = 0;
  int _dbFrames = 0;

  /// Becomes true when today's play reaches the child's daily limit.
  final timeUp = ValueNotifier<bool>(false);

  /// Visits shorter than this are dropped so the dashboard stays honest.
  static const minSeconds = 5;

  SessionRecord? get current => _record;

  /// Starts recording a visit and returns it; pass it back to [end] so a
  /// screen that is closing can't end its successor's visit.
  SessionRecord begin(ChildProfile child, String mode, {String? target}) {
    end();
    _child = child;
    _startedAt = _now();
    _record = SessionRecord(id: Store.newId(), childId: child.id, start: _startedAt!, mode: mode, target: target);
    _dbSum = 0;
    _dbFrames = 0;
    _check();
    _timer = Timer.periodic(const Duration(seconds: 5), (_) => _check());
    return _record!;
  }

  /// Seconds played today by [child], including the visit in progress.
  int secondsToday(ChildProfile child) {
    final now = _now();
    final midnight = DateTime(now.year, now.month, now.day);
    var s = 0;
    for (final r in child.sessions) {
      if (!r.start.isBefore(midnight)) s += r.durationSeconds;
    }
    if (_child?.id == child.id && _startedAt != null) s += now.difference(_startedAt!).inSeconds;
    return s;
  }

  bool limitReached(ChildProfile child) {
    final m = child.settings.dailyMinutes;
    return m > 0 && secondsToday(child) >= m * 60;
  }

  void _check() {
    final c = _child;
    if (c != null && limitReached(c)) timeUp.value = true;
  }

  /// A grown-up chose to allow more play today: adds 10 minutes.
  void extend(ChildProfile child) {
    child.settings.dailyMinutes = (secondsToday(child) ~/ 60) + 10;
    _store.childUpdated(child);
    timeUp.value = false;
  }

  /// Folds in every analysed voice frame.
  void onFrame(VoiceFrame f, double dt) {
    final r = _record;
    if (r == null) return;
    r.vocalizations += f.vocalizations;
    if (f.voiced) {
      r.voiceSeconds += dt;
      _dbSum += f.db;
      _dbFrames++;
    }
  }

  void attempt() => _record?.attempts++;
  void completion() => _record?.completions++;

  /// Saves the visit (if long enough) and stops tracking. With [only], does
  /// nothing unless that visit is still the current one.
  void end([SessionRecord? only]) {
    if (only != null && !identical(only, _record)) return;
    _timer?.cancel();
    _timer = null;
    final r = _record, c = _child;
    _record = null;
    _child = null;
    if (r == null || c == null) return;
    r.durationSeconds = _now().difference(_startedAt!).inSeconds;
    r.avgDb = _dbFrames == 0 ? -120 : _dbSum / _dbFrames;
    if (r.durationSeconds >= minSeconds || r.completions > 0) _store.addSession(c, r);
  }
}
