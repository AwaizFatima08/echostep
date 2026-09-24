import 'dart:math' as math;

import '../core/content.dart';

/// Age pills from the onboarding screen.
const ageGroups = ['2-3', '4-5', '6+'];

/// Buddy characters a child can choose.
enum Buddy {
  milo('Milo', 'milo_bear'),
  pip('Pip', 'pip_bird');

  const Buddy(this.displayName, this.id);
  final String displayName;

  /// Stored as `avatar_id` (PDD schema).
  final String id;

  static Buddy fromId(String? id) => Buddy.values.firstWhere((b) => b.id == id, orElse: () => Buddy.milo);
}

/// How Echo Safari rewards sound.
enum PlayLevel {
  /// Any voice grows the flower.
  explore,

  /// The target sound grows it three times faster; other sounds still grow
  /// it slowly (errorless).
  practise;

  static PlayLevel fromName(String? n) =>
      PlayLevel.values.firstWhere((l) => l.name == n, orElse: () => PlayLevel.explore);
}

/// Per-child settings chosen by the grown-up.
class ChildSettings {
  ChildSettings({
    this.level = PlayLevel.explore,
    this.sensitivity = 1.0,
    this.calmMode = false,
    this.promptsOn = true,
    this.dailyMinutes = 0,
    this.unlockAllCards = false,
  });

  PlayLevel level;

  /// Mic sensitivity 0.5 (loud child) .. 2.0 (very quiet child).
  double sensitivity;

  /// Fewer particles, slower motion, no screen-wide bursts.
  bool calmMode;

  /// Spoken coaching prompts.
  bool promptsOn;

  /// Daily play limit in minutes; 0 = no limit.
  int dailyMinutes;

  /// Make every AAC card available without Echo Safari.
  bool unlockAllCards;

  Map<String, dynamic> toJson() => {
    'level': level.name,
    'sensitivity': sensitivity,
    'calm_mode': calmMode,
    'prompts_on': promptsOn,
    'daily_minutes': dailyMinutes,
    'unlock_all_cards': unlockAllCards,
  };

  factory ChildSettings.fromJson(Map<String, dynamic>? j) {
    j ??= const {};
    return ChildSettings(
      level: PlayLevel.fromName(j['level'] as String?),
      sensitivity: ((j['sensitivity'] as num?)?.toDouble() ?? 1.0).clamp(0.5, 2.0),
      calmMode: j['calm_mode'] as bool? ?? false,
      promptsOn: j['prompts_on'] as bool? ?? true,
      dailyMinutes: ((j['daily_minutes'] as num?)?.toInt() ?? 0).clamp(0, 240),
      unlockAllCards: j['unlock_all_cards'] as bool? ?? false,
    );
  }
}

/// One play session in one mode. `mode` is spark, safari or cards.
class SessionRecord {
  SessionRecord({
    required this.id,
    required this.childId,
    required this.start,
    required this.mode,
    this.durationSeconds = 0,
    this.vocalizations = 0,
    this.voiceSeconds = 0,
    this.avgDb = -120,
    this.target,
    this.attempts = 0,
    this.completions = 0,
    this.synced = false,
  });

  final String id;
  final String childId;
  final DateTime start;
  final String mode;
  int durationSeconds;
  int vocalizations;
  double voiceSeconds;

  /// Mean loudness of voiced frames, dBFS.
  double avgDb;

  /// Echo Safari target id, when there was one.
  String? target;
  int attempts;
  int completions;

  /// True once written to Firestore (local bookkeeping only).
  bool synced;

  double get successRate => attempts == 0 ? 0 : math.min(1, completions / attempts);

  Map<String, dynamic> toJson() => {
    'id': id,
    'child_id': childId,
    'start': start.toUtc().toIso8601String(),
    'mode': mode,
    'duration_seconds': durationSeconds,
    'vocalization_count': vocalizations,
    'voice_seconds': voiceSeconds,
    'avg_volume_db': avgDb,
    'target_sound': target,
    'attempts': attempts,
    'completions': completions,
    'synced': synced,
  };

  factory SessionRecord.fromJson(Map<String, dynamic> j) => SessionRecord(
    id: j['id'] as String,
    childId: j['child_id'] as String,
    start: DateTime.tryParse(j['start'] as String? ?? '')?.toLocal() ?? DateTime.now(),
    mode: j['mode'] as String? ?? 'spark',
    durationSeconds: (j['duration_seconds'] as num?)?.toInt() ?? 0,
    vocalizations: (j['vocalization_count'] as num?)?.toInt() ?? 0,
    voiceSeconds: (j['voice_seconds'] as num?)?.toDouble() ?? 0,
    avgDb: (j['avg_volume_db'] as num?)?.toDouble() ?? -120,
    target: j['target_sound'] as String?,
    attempts: (j['attempts'] as num?)?.toInt() ?? 0,
    completions: (j['completions'] as num?)?.toInt() ?? 0,
    synced: j['synced'] as bool? ?? false,
  );
}

/// A child profile (an alias; the app never asks for a real name).
class ChildProfile {
  ChildProfile({
    required this.id,
    required this.nickname,
    required this.ageGroup,
    required this.buddy,
    DateTime? createdAt,
    DateTime? updatedAt,
    ChildSettings? settings,
    Map<String, int>? practised,
    Set<String>? mastered,
    Set<String>? unlockedCards,
    List<SessionRecord>? sessions,
    this.totalVocalizations = 0,
    this.totalSeconds = 0,
    this.totalVoiceSeconds = 0,
    this.totalSessions = 0,
  }) : createdAt = createdAt ?? DateTime.now(),
       updatedAt = updatedAt ?? DateTime.now(),
       settings = settings ?? ChildSettings(),
       practised = practised ?? {},
       mastered = mastered ?? {},
       unlockedCards = unlockedCards ?? {},
       sessions = sessions ?? [];

  /// Sessions kept on the device for charts and the report (about a year of
  /// daily play); aggregate totals below are kept forever.
  static const maxSessions = 1500;

  final String id;
  String nickname;
  String ageGroup;
  Buddy buddy;
  final DateTime createdAt;
  DateTime updatedAt;
  ChildSettings settings;

  /// Echo Safari completions per target id.
  final Map<String, int> practised;

  /// Target ids a grown-up marked as mastered (the app never decides this).
  final Set<String> mastered;

  /// AAC cards unlocked through Echo Safari (core cards are always on).
  final Set<String> unlockedCards;
  final List<SessionRecord> sessions;

  int totalVocalizations;
  int totalSeconds;
  double totalVoiceSeconds;
  int totalSessions;

  /// Name to show; a friendly default when the grown-up left it blank.
  String get displayName => nickname.trim().isEmpty ? 'Superstar' : nickname.trim();

  /// Seconds of Echo Safari hold needed per stop, scaled by age.
  double get holdSeconds => switch (ageGroup) {
    '2-3' => 1.5,
    '4-5' => 2.5,
    _ => 3.5,
  };

  /// Syllables needed per syllable stop, scaled by age.
  int get syllablesNeeded => switch (ageGroup) {
    '2-3' => 3,
    '4-5' => 4,
    _ => 6,
  };

  bool hasCard(AacCard c) => c.core || settings.unlockAllCards || unlockedCards.contains(c.id);

  List<AacCard> get availableCards => [
    for (final c in aacCards)
      if (hasCard(c)) c,
  ];

  /// The first safari stop not yet completed; the map highlights it.
  SoundTarget get suggestedTarget =>
      targets.firstWhere((t) => (practised[t.id] ?? 0) == 0, orElse: () => targets[_leastPractisedIndex()]);

  int _leastPractisedIndex() {
    var best = 0;
    for (var i = 1; i < targets.length; i++) {
      if ((practised[targets[i].id] ?? 0) < (practised[targets[best].id] ?? 0)) best = i;
    }
    return best;
  }

  void touch() => updatedAt = DateTime.now();

  Map<String, dynamic> toJson() => {
    'id': id,
    'nickname': nickname,
    'age_group': ageGroup,
    'avatar_id': buddy.id,
    'created_at': createdAt.toUtc().toIso8601String(),
    'updated_at': updatedAt.toUtc().toIso8601String(),
    'settings': settings.toJson(),
    'practised_sounds': practised,
    'mastered_sounds': mastered.toList(),
    'unlocked_cards': unlockedCards.toList(),
    'stats': statsJson(),
    'sessions': [for (final s in sessions) s.toJson()],
  };

  Map<String, dynamic> statsJson() => {
    'total_vocalizations': totalVocalizations,
    'total_seconds_played': totalSeconds,
    'total_minutes_played': totalSeconds ~/ 60,
    'total_voice_seconds': double.parse(totalVoiceSeconds.toStringAsFixed(1)),
    'total_sessions': totalSessions,
  };

  factory ChildProfile.fromJson(Map<String, dynamic> j) {
    final stats = (j['stats'] as Map?)?.cast<String, dynamic>() ?? const {};
    final age = j['age_group'] as String?;
    return ChildProfile(
      id: j['id'] as String,
      nickname: (j['nickname'] as String?) ?? '',
      ageGroup: ageGroups.contains(age) ? age! : '2-3',
      buddy: Buddy.fromId(j['avatar_id'] as String?),
      createdAt: DateTime.tryParse(j['created_at'] as String? ?? '')?.toLocal(),
      updatedAt: DateTime.tryParse(j['updated_at'] as String? ?? '')?.toLocal(),
      settings: ChildSettings.fromJson((j['settings'] as Map?)?.cast<String, dynamic>()),
      practised: {
        for (final e in ((j['practised_sounds'] as Map?) ?? const {}).entries) '${e.key}': (e.value as num).toInt(),
      },
      mastered: {for (final m in (j['mastered_sounds'] as List?) ?? const []) '$m'},
      unlockedCards: {for (final c in (j['unlocked_cards'] as List?) ?? const []) '$c'},
      sessions: [
        for (final s in (j['sessions'] as List?) ?? const [])
          SessionRecord.fromJson((s as Map).cast<String, dynamic>()),
      ],
      totalVocalizations: (stats['total_vocalizations'] as num?)?.toInt() ?? 0,
      totalSeconds: (stats['total_seconds_played'] as num?)?.toInt() ?? 0,
      totalVoiceSeconds: (stats['total_voice_seconds'] as num?)?.toDouble() ?? 0,
      totalSessions: (stats['total_sessions'] as num?)?.toInt() ?? 0,
    );
  }
}

/// Device-wide settings.
class AppSettings {
  AppSettings({this.sfxOn = true, this.musicOn = false, this.speechRate = 0.4, this.cloudBackup = true});

  bool sfxOn;
  bool musicOn;

  /// TTS rate (Android: 0.5 is normal speed).
  double speechRate;

  /// Mirror progress to Firestore (parent can switch off).
  bool cloudBackup;

  Map<String, dynamic> toJson() => {
    'sfx_on': sfxOn,
    'music_on': musicOn,
    'speech_rate': speechRate,
    'cloud_backup': cloudBackup,
  };

  factory AppSettings.fromJson(Map<String, dynamic>? j) {
    j ??= const {};
    return AppSettings(
      sfxOn: j['sfx_on'] as bool? ?? true,
      musicOn: j['music_on'] as bool? ?? false,
      speechRate: ((j['speech_rate'] as num?)?.toDouble() ?? 0.4).clamp(0.2, 0.6),
      cloudBackup: j['cloud_backup'] as bool? ?? true,
    );
  }
}
