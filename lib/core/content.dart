import 'package:flutter/material.dart';

import 'audio/dsp.dart';

/// How a target sound is recognised.
enum TargetKind {
  /// Hold a vowel ("aaah").
  vowel,

  /// Hold a closed-mouth hum ("mmm").
  hum,

  /// Repeat a syllable ("ba-ba-ba"): canonical babbling.
  syllable,
}

/// Mouth shapes Pip and the mouth card model. Values are the lips' opening
/// (0 closed .. 1 wide) and width (0 puckered .. 1 wide smile).
enum MouthShape {
  ah(open: 1.0, width: 0.65, teeth: false),
  oh(open: 0.7, width: 0.35, teeth: false),
  oo(open: 0.45, width: 0.1, teeth: false),
  ee(open: 0.25, width: 1.0, teeth: true),
  closed(open: 0.0, width: 0.55, teeth: false);

  const MouthShape({required this.open, required this.width, required this.teeth});
  final double open;
  final double width;
  final bool teeth;
}

/// One Echo Safari stop.
class SoundTarget {
  const SoundTarget({
    required this.id,
    required this.label,
    required this.spoken,
    required this.kind,
    required this.mouth,
    required this.color,
    required this.tip,
    required this.cards,
    this.vowel,
    this.releaseMouth,
  });

  /// Stable id stored in progress data and Firestore (never rename).
  final String id;

  /// What the child sees ("Ah").
  final String label;

  /// What the TTS says when modelling it (spelled so TTS pronounces it well).
  final String spoken;
  final TargetKind kind;
  final Vowel? vowel;

  /// Mouth shape to model; syllables alternate [mouth] (closed) and
  /// [releaseMouth] (open).
  final MouthShape mouth;
  final MouthShape? releaseMouth;
  final Color color;

  /// Coaching tip for the grown-up.
  final String tip;

  /// AAC cards this stop unlocks.
  final List<String> cards;

  /// Shown in reports and the parent's sound list ("/a/").
  String get phoneme => switch (id) {
    'ah' => '/a/',
    'oh' => '/o/',
    'oo' => '/u/',
    'ee' => '/i/',
    'mmm' => '/m/',
    _ => '/$id/',
  };
}

/// The safari route, in a developmental order that alternates vowels with
/// the earliest consonants (lip sounds first).
const targets = <SoundTarget>[
  SoundTarget(
    id: 'ah',
    label: 'Ah',
    spoken: 'Ahhh',
    kind: TargetKind.vowel,
    vowel: Vowel.ah,
    mouth: MouthShape.ah,
    color: Color(0xFFFF6B6B),
    tip: 'Open wide, like at the doctor\'s. Any long open sound counts.',
    cards: ['car', 'potty', 'star'],
  ),
  SoundTarget(
    id: 'mmm',
    label: 'Mmm',
    spoken: 'Mmmmm',
    kind: TargetKind.hum,
    mouth: MouthShape.closed,
    color: Color(0xFFFF9F68),
    tip: 'Lips together and hum, like tasting something yummy. Touch your lips to show them.',
    cards: ['milk', 'music', 'yummy'],
  ),
  SoundTarget(
    id: 'oo',
    label: 'Oo',
    spoken: 'Oooo',
    kind: TargetKind.vowel,
    vowel: Vowel.oo,
    mouth: MouthShape.oo,
    color: Color(0xFFFFD166),
    tip: 'Round, small lips, like blowing a kiss or saying "ooh!" at fireworks.',
    cards: ['shoe', 'moon', 'juice'],
  ),
  SoundTarget(
    id: 'ba',
    label: 'Ba',
    spoken: 'Bah. Bah. Bah.',
    kind: TargetKind.syllable,
    mouth: MouthShape.closed,
    releaseMouth: MouthShape.ah,
    color: Color(0xFF95E1A3),
    tip: 'Press lips together, then pop them open: "ba-ba-ba". Babbling counts.',
    cards: ['ball', 'bubbles', 'book', 'banana'],
  ),
  SoundTarget(
    id: 'ee',
    label: 'Ee',
    spoken: 'Eeee',
    kind: TargetKind.vowel,
    vowel: Vowel.ee,
    mouth: MouthShape.ee,
    color: Color(0xFF4ECDC4),
    tip: 'Big smile and show your teeth, like "cheese!".',
    cards: ['sleep', 'tree', 'cheese'],
  ),
  SoundTarget(
    id: 'ma',
    label: 'Ma',
    spoken: 'Mah. Mah. Mah.',
    kind: TargetKind.syllable,
    mouth: MouthShape.closed,
    releaseMouth: MouthShape.ah,
    color: Color(0xFF6FA8FF),
    tip: 'Hum with lips closed, then open: "ma-ma-ma".',
    cards: ['mama', 'mango', 'monkey'],
  ),
  SoundTarget(
    id: 'oh',
    label: 'Oh',
    spoken: 'Ohhh',
    kind: TargetKind.vowel,
    vowel: Vowel.oh,
    mouth: MouthShape.oh,
    color: Color(0xFFB8A1FF),
    tip: 'A round, surprised mouth: "oh!".',
    cards: ['open', 'boat', 'home'],
  ),
  SoundTarget(
    id: 'da',
    label: 'Da',
    spoken: 'Dah. Dah. Dah.',
    kind: TargetKind.syllable,
    mouth: MouthShape.ee,
    releaseMouth: MouthShape.ah,
    color: Color(0xFFFF8FB8),
    tip: 'Tongue taps behind the top teeth: "da-da-da".',
    cards: ['dada', 'dog', 'duck'],
  ),
];

SoundTarget? targetById(String id) {
  for (final t in targets) {
    if (t.id == id) return t;
  }
  return null;
}

/// An AAC picture card.
class AacCard {
  const AacCard(this.id, this.word, this.emoji, {this.core = false});

  /// Stable id; also the picture file name (`assets/aac/<id>.png`).
  final String id;
  final String word;

  /// Unicode emoji the picture comes from (Noto Color Emoji, Apache 2.0).
  final String emoji;

  /// Core words are always available: communication is never locked behind
  /// speech practice.
  final bool core;

  String get asset => 'assets/aac/$id.png';
}

const aacCards = <AacCard>[
  // Core vocabulary, always available.
  AacCard('more', 'more', '➕', core: true),
  AacCard('help', 'help', '🙋', core: true),
  AacCard('all_done', 'all done', '👐', core: true),
  AacCard('yes', 'yes', '👍', core: true),
  AacCard('no', 'no', '🙅', core: true),
  AacCard('eat', 'eat', '🍽️', core: true),
  AacCard('drink', 'drink', '🥤', core: true),
  AacCard('play', 'play', '🧸', core: true),
  AacCard('hug', 'hug', '🤗', core: true),
  // Unlocked through Echo Safari.
  AacCard('car', 'car', '🚗'),
  AacCard('potty', 'potty', '🚽'),
  AacCard('star', 'star', '⭐'),
  AacCard('milk', 'milk', '🥛'),
  AacCard('music', 'music', '🎵'),
  AacCard('yummy', 'yummy', '😋'),
  AacCard('shoe', 'shoe', '👟'),
  AacCard('moon', 'moon', '🌙'),
  AacCard('juice', 'juice', '🧃'),
  AacCard('ball', 'ball', '⚽'),
  AacCard('bubbles', 'bubbles', '🫧'),
  AacCard('book', 'book', '📖'),
  AacCard('banana', 'banana', '🍌'),
  AacCard('sleep', 'sleep', '😴'),
  AacCard('tree', 'tree', '🌳'),
  AacCard('cheese', 'cheese', '🧀'),
  AacCard('mama', 'mama', '👩'),
  AacCard('mango', 'mango', '🥭'),
  AacCard('monkey', 'monkey', '🐒'),
  AacCard('open', 'open', '📦'),
  AacCard('boat', 'boat', '⛵'),
  AacCard('home', 'home', '🏠'),
  AacCard('dada', 'dada', '👨'),
  AacCard('dog', 'dog', '🐶'),
  AacCard('duck', 'duck', '🦆'),
];

AacCard? cardById(String id) {
  for (final c in aacCards) {
    if (c.id == id) return c;
  }
  return null;
}
