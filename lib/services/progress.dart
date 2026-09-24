import '../core/content.dart';
import '../models/child.dart';

/// One calendar day of activity.
class DayActivity {
  DayActivity(this.day);
  final DateTime day;
  double playMinutes = 0;
  double voiceMinutes = 0;
  int vocalizations = 0;
}

/// Per-target Echo Safari summary.
class TargetSummary {
  TargetSummary(this.target);
  final SoundTarget target;
  int visits = 0;
  int attempts = 0;
  int completions = 0;
  double voiceSeconds = 0;

  double get successRate => attempts == 0 ? 0 : (completions / attempts).clamp(0, 1).toDouble();
}

/// Read-only views over a child's sessions for the dashboard and report.
class Progress {
  Progress(this.child, {DateTime? now}) : now = now ?? DateTime.now();

  final ChildProfile child;
  final DateTime now;

  static DateTime dayOf(DateTime t) => DateTime(t.year, t.month, t.day);

  /// The last [days] days, oldest first, including today.
  List<DayActivity> daily(int days) {
    final today = dayOf(now);
    final out = [for (var i = days - 1; i >= 0; i--) DayActivity(today.subtract(Duration(days: i)))];
    final first = out.first.day;
    for (final s in child.sessions) {
      final d = dayOf(s.start);
      if (d.isBefore(first) || d.isAfter(today)) continue;
      final a = out[d.difference(first).inDays.clamp(0, days - 1)];
      a.playMinutes += s.durationSeconds / 60;
      a.voiceMinutes += s.voiceSeconds / 60;
      a.vocalizations += s.vocalizations;
    }
    return out;
  }

  /// Sessions within the last [days] days.
  Iterable<SessionRecord> recent(int days) {
    final from = dayOf(now).subtract(Duration(days: days - 1));
    return child.sessions.where((s) => !s.start.isBefore(from));
  }

  int activeDays(int days) => {for (final s in recent(days)) dayOf(s.start)}.length;

  Map<String, TargetSummary> targetSummaries({int? days}) {
    final out = {for (final t in targets) t.id: TargetSummary(t)};
    for (final s in days == null ? child.sessions : recent(days)) {
      final t = s.target == null ? null : out[s.target];
      if (t == null) continue;
      t.visits++;
      t.attempts += s.attempts;
      t.completions += s.completions;
      t.voiceSeconds += s.voiceSeconds;
    }
    return out;
  }

  /// Whether the child has ever tried [t] (a visit), completed it, or had it
  /// confirmed as mastered by a grown-up.
  String status(SoundTarget t) {
    if (child.mastered.contains(t.id)) return 'mastered';
    if ((child.practised[t.id] ?? 0) > 0) return 'practised';
    if (child.sessions.any((s) => s.target == t.id)) return 'tried';
    return 'new';
  }
}
