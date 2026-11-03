// My Steps (v1.2): a guided path of chapters and short lessons built from the
// free-play activities. Each lesson is three steps shown up front as a
// "first, then, then" picture schedule, so a child always knows what comes
// next. Nothing is locked: the next suggested lesson simply glows.

import 'package:flutter/material.dart';

import 'content.dart';
import 'theme.dart';

/// What a lesson step opens.
enum StepKind {
  /// Sound Spark for [LessonStep.seconds] of play.
  spark,

  /// Pitch Slide for [LessonStep.seconds] of play.
  pitch,

  /// One Echo Safari stop ([LessonStep.ref] = sound id).
  stop,

  /// One round of Echo Turns ([LessonStep.ref] = sound id).
  turns,

  /// One Animal Friends call ([LessonStep.ref] = animal id).
  animal,

  /// A First Words card ([LessonStep.ref] = card id).
  word,
}

class LessonStep {
  const LessonStep(this.kind, [this.ref, this.seconds = 30]);

  final StepKind kind;

  /// Sound, animal or card id, depending on [kind].
  final String? ref;

  /// Play time for the free-play steps (spark, pitch).
  final int seconds;

  SoundTarget? get target => switch (kind) {
    StepKind.stop || StepKind.turns => targetById(ref!),
    StepKind.animal => animalById(ref!)?.target,
    StepKind.word => cardById(ref!)?.target,
    _ => null,
  };

  /// Short label under the schedule picture.
  String get label => switch (kind) {
    StepKind.spark => 'Sound Spark',
    StepKind.pitch => 'Pitch Slide',
    StepKind.stop => 'Say ${target!.label}',
    StepKind.turns => 'Turns: ${target!.label}',
    StepKind.animal => animalById(ref!)!.call,
    StepKind.word => cardById(ref!)!.word,
  };

  Color get color => switch (kind) {
    StepKind.spark => ES.coral,
    StepKind.pitch => ES.peach,
    StepKind.stop => target!.color,
    StepKind.turns => ES.lilac,
    StepKind.animal => ES.mint,
    StepKind.word => ES.sunshine,
  };
}

class Lesson {
  const Lesson(this.id, this.title, this.steps);

  /// Stable id stored in progress data (never rename): `c<chapter>l<n>`.
  final String id;
  final String title;
  final List<LessonStep> steps;
}

class Chapter {
  const Chapter(this.id, this.title, this.subtitle, this.color, this.lessons);

  final String id;
  final String title;

  /// For grown-ups: what the chapter works on.
  final String subtitle;
  final Color color;
  final List<Lesson> lessons;
}

const _spark = LessonStep(StepKind.spark);
const _pitch = LessonStep(StepKind.pitch);
LessonStep _stop(String id) => LessonStep(StepKind.stop, id);
LessonStep _turns(String id) => LessonStep(StepKind.turns, id);
LessonStep _animal(String id) => LessonStep(StepKind.animal, id);
LessonStep _word(String id) => LessonStep(StepKind.word, id);

/// Developmental order: any voice first, then open vowels, rounded and
/// spread vowels, lip sounds, popping lips, tongue tips, and finally short
/// functional words.
final chapters = <Chapter>[
  Chapter(
    'c1',
    'Hello, Voice!',
    'Any sound counts: making voice and playing with loud, soft, high and low.',
    ES.coral,
    [
      Lesson('c1l1', 'Wake up, Milo', [_spark, _pitch, _spark]),
      Lesson('c1l2', 'Big and small', [_spark, _stop('ah'), _pitch]),
      Lesson('c1l3', 'Sing with Pip', [const LessonStep(StepKind.pitch, null, 40), _turns('ah'), _spark]),
    ],
  ),
  Chapter('c2', 'Open Wide', 'Open-mouth vowels: "ah" and "oh".', ES.turquoise, [
    Lesson('c2l1', 'Say Ah', [_stop('ah'), _turns('ah'), _animal('monkey_friend')]),
    Lesson('c2l2', 'Say Oh', [_stop('oh'), _turns('oh'), _word('open')]),
    Lesson('c2l3', 'Ah and Oh', [_turns('ah'), _turns('oh'), _word('car')]),
  ]),
  Chapter('c3', 'Round and Smiley', 'Round lips for "oo", a big smile for "ee".', ES.sunshine, [
    Lesson('c3l1', 'Say Oo', [_stop('oo'), _animal('cow'), _animal('owl')]),
    Lesson('c3l2', 'Say Ee', [_stop('ee'), _animal('cat'), _word('cheese')]),
    Lesson('c3l3', 'Oo and Ee', [_word('shoe'), _word('eat'), _turns('ee')]),
  ]),
  Chapter('c4', 'Humming Lips', 'Lips together: humming "mmm" and "ma-ma".', ES.peach, [
    Lesson('c4l1', 'Hum like a bee', [_stop('mmm'), _animal('bee'), _word('milk')]),
    Lesson('c4l2', 'Ma-ma', [_stop('ma'), _turns('ma'), _word('mama')]),
    Lesson('c4l3', 'Yummy words', [_word('more'), _word('yummy'), _turns('mmm')]),
  ]),
  Chapter('c5', 'Popping Lips', 'Lips pop open: "ba", "pa" and "bye-bye".', ES.mint, [
    Lesson('c5l1', 'Ba-ba', [_stop('ba'), _animal('sheep'), _word('ball')]),
    Lesson('c5l2', 'Pa-pa', [_stop('pa'), _turns('pa'), _word('papa')]),
    Lesson('c5l3', 'Bye-bye', [_stop('bye'), _turns('bye'), _word('bye')]),
  ]),
  Chapter('c6', 'Tongue Taps', 'Tongue behind the top teeth: "da" and "na".', ES.lilac, [
    Lesson('c6l1', 'Da-da', [_stop('da'), _turns('da'), _word('dada')]),
    Lesson('c6l2', 'Na-na', [_stop('na'), _turns('na'), _word('nose')]),
    Lesson('c6l3', 'Dog and duck', [_word('dog'), _word('duck'), _word('no')]),
  ]),
  Chapter('c7', 'Little Words', 'Short words a child can use every day.', ES.coral, [
    Lesson('c7l1', 'Wa-wa', [_stop('wa'), _word('water'), _word('wow')]),
    Lesson('c7l2', 'Up and uh-oh', [_word('up'), _word('uh_oh'), _turns('oh')]),
    Lesson('c7l3', 'I can ask', [_word('more'), _word('eat'), _word('all_done')]),
  ]),
];

/// Every lesson in path order.
final allLessons = [for (final c in chapters) ...c.lessons];

Lesson? lessonById(String id) {
  for (final l in allLessons) {
    if (l.id == id) return l;
  }
  return null;
}

Chapter chapterOf(Lesson l) => chapters.firstWhere((c) => c.lessons.contains(l));

/// The lesson to suggest next: the first one not yet finished in path order,
/// or (once all are done) the one finished fewest times.
Lesson nextLesson(Map<String, int> done) {
  for (final l in allLessons) {
    if ((done[l.id] ?? 0) == 0) return l;
  }
  return allLessons.reduce((a, b) => (done[b.id] ?? 0) < (done[a.id] ?? 0) ? b : a);
}

/// Lessons finished at least once.
int lessonsFinished(Map<String, int> done) => allLessons.where((l) => (done[l.id] ?? 0) > 0).length;
