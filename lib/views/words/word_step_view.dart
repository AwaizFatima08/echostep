// First Words (v1.2, My Steps): the bridge from a practised sound to a word
// the child can use. Pip shows a picture card, says the word slowly, and the
// child tries; any try in the word's sound family counts (Explore), and the
// card is spoken back and unlocked on the card wall. Nothing can be failed:
// a quiet child just hears the word again.

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/audio/audio_input.dart' show smoothTo;
import '../../core/audio/sound_player.dart';
import '../../core/audio/voice_analyzer.dart';
import '../../core/content.dart';
import '../../core/theme.dart';
import '../../widgets/characters.dart';
import '../../widgets/effects.dart';
import '../../widgets/kid_widgets.dart';
import '../../widgets/listening.dart';
import '../cards/card_wall_view.dart' show AacCardTile;
import '../safari/safari_stop_view.dart' show StopScorer;

class WordStepView extends StatefulWidget {
  const WordStepView({super.key, required this.card});

  /// A card with a [AacCard.sound] (every card used in a lesson has one).
  final AacCard card;

  @override
  State<WordStepView> createState() => _WordStepViewState();
}

enum _Phase { modelling, listening, done }

class _WordStepViewState extends ListeningState<WordStepView> {
  late final SoundTarget target = widget.card.target!;
  late final StopScorer _scorer = StopScorer(
    target: target,
    level: child.settings.level,
    // A word is short: about half a Safari hold, or a couple of syllables.
    holdSeconds: math.max(1.0, child.holdSeconds * 0.6),
    syllablesNeeded: math.max(2, child.syllablesNeeded ~/ 2),
  );
  final _field = ParticleField(maxParticles: 50);
  _Phase _phase = _Phase.modelling;
  bool _fresh = false;
  double _t = 0;
  double _level = 0;
  double _quiet = 0;
  Offset _cardCenter = Offset.zero;

  AacCard get card => widget.card;

  @override
  String get mode => 'word';

  @override
  String? get targetId => target.id;

  @override
  void onStarted() {
    services.session.attempt();
    unawaited(_model(first: true));
  }

  Future<void> _model({bool first = false}) async {
    if (!mounted || _phase == _Phase.done) return;
    setState(() => _phase = _Phase.modelling);
    final sp = services.speech;
    // The word itself is always said (it is the exercise); the framing
    // around it follows the grown-up's spoken-encouragement setting.
    if (first) await sp.prompt('Look! ${card.word[0].toUpperCase()}${card.word.substring(1)}.');
    if (!mounted || _phase == _Phase.done) return;
    await sp.say(card.word, rateOverride: 0.3);
    if (!mounted || _phase == _Phase.done) return;
    await sp.prompt('Your turn!');
    if (!mounted || _phase != _Phase.modelling) return;
    _quiet = 0;
    setState(() => _phase = _Phase.listening);
  }

  @override
  void onFrames(VoiceFrame latest, List<VoiceFrame> frames, double dt) {
    _t += dt;
    _level = smoothTo(_level, latest.level, 10, dt);
    if (_phase == _Phase.listening) {
      for (final f in frames) {
        _scorer.add(f);
      }
      _quiet = latest.voiced ? 0 : _quiet + dt;
      if (latest.voiced) _field.emit(_cardCenter, latest.level * 0.5, latest.pitchNorm, dt, calm: true);
      if (_scorer.done) {
        unawaited(_finish());
      } else if (_quiet > 9) {
        _quiet = 0;
        unawaited(_model());
      }
    }
    _field.step(dt);
    setState(() {});
  }

  void _tapCard() {
    // Touch fallback without a microphone: each tap is a try.
    if (_phase != _Phase.listening || micOn) return;
    _scorer.progress = math.min(1, _scorer.progress + 0.34);
    services.sound.sfx(Sfx.droplet, volume: 0.5);
    if (_scorer.done) unawaited(_finish());
  }

  Future<void> _finish() async {
    if (_phase == _Phase.done) return;
    setState(() => _phase = _Phase.done);
    services.session.completion();
    _fresh = services.store.recordWord(child, card);
    services.sound.sfx(_fresh ? Sfx.sparkle : Sfx.chime);
    _field.burst(_cardCenter, count: 20, calm: child.settings.calmMode);
    await services.speech.prompt('You said it!');
    if (!mounted) return;
    await services.speech.say(card.word, rateOverride: 0.38);
  }

  @override
  Widget build(BuildContext context) {
    final calm = child.settings.calmMode;
    final done = _phase == _Phase.done;
    final shape = target.releaseMouth ?? target.mouth;
    return Scaffold(
      body: Backdrop(
        calm: calm,
        top: const Color(0xFF2A2440),
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, box) {
              final w = box.maxWidth, h = box.maxHeight;
              final cardW = math.min(w * 0.6, h * 0.3);
              _cardCenter = Offset(w / 2, 72 + (h - 136) * 0.3);
              final grow = math.min(1.0, _scorer.progress);
              return Stack(
                children: [
                  Positioned.fill(
                    child: IgnorePointer(child: CustomPaint(painter: ParticlePainter(_field))),
                  ),
                  // Card, Pip and the try dots as one column, so nothing
                  // overlaps on small or large-font phones.
                  Positioned.fill(
                    top: 72,
                    bottom: 64,
                    child: Column(
                      children: [
                        Expanded(
                          flex: 5,
                          child: Center(
                            child: GestureDetector(
                              onTap: _tapCard,
                              child: Transform.scale(
                                scale: 1 + (calm ? 0.02 : 0.05) * _level + 0.04 * grow,
                                child: SizedBox(
                                  width: cardW,
                                  child: FittedBox(
                                    child: SizedBox(
                                      width: 280,
                                      child: AacCardTile(key: const ValueKey('word-card'), card: card, big: true),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        Expanded(
                          flex: 3,
                          child: Center(
                            child: FittedBox(
                              child: Pip(
                                size: 130,
                                shape: done ? MouthShape.ah : shape,
                                happy: done,
                                flap: _level * math.sin(_t * 12),
                                glow: done ? 0.8 : _scorer.match * 0.6,
                              ),
                            ),
                          ),
                        ),
                        // A row of dots fills as the child tries (never "wrong").
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            for (var i = 0; i < 3; i++)
                              Container(
                                width: 18,
                                height: 18,
                                margin: const EdgeInsets.all(5),
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: grow > (i + 0.5) / 3 ? ES.sunshine : ES.cardLine,
                                  border: Border.all(color: ES.sunshine, width: 2),
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Positioned(
                    left: 20,
                    right: 20,
                    bottom: 10,
                    child: Text(
                      micOn
                          ? 'Grown-ups: say "${card.word}" together and point to the picture. Any try counts.'
                          : 'Grown-ups: no microphone - tap the card when the child has had a try.',
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: ES.muted, fontSize: 14),
                    ),
                  ),
                  if (done)
                    Positioned.fill(
                      child: ColoredBox(
                        color: ES.canvasDeep.withValues(alpha: 0.7),
                        child: Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                _fresh ? 'New card!' : 'You said it!',
                                key: const ValueKey('word-done'),
                                style: const TextStyle(fontSize: 34, fontWeight: FontWeight.w700, color: ES.sunshine),
                              ),
                              const SizedBox(height: 12),
                              BouncyButton(
                                label: card.word,
                                onTap: () => services.speech.say(card.word),
                                child: SizedBox(
                                  width: math.min(200, w * 0.5),
                                  child: FittedBox(
                                    child: SizedBox(width: 280, child: AacCardTile(card: card, big: true)),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 28),
                              const LessonContinueButton(),
                            ],
                          ),
                        ),
                      ),
                    ),
                  Positioned(top: 8, left: 8, child: const KidBackButton()),
                  if (_phase == _Phase.listening)
                    Positioned(
                      top: 8,
                      right: 8,
                      child: RoundButton(
                        key: const ValueKey('word-again'),
                        icon: Icons.hearing_rounded,
                        label: 'Hear it again',
                        size: 56,
                        color: ES.sunshine,
                        onTap: () => _model(),
                      ),
                    ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
