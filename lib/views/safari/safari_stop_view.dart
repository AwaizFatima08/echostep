import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/audio/audio_input.dart';
import '../../core/audio/dsp.dart';
import '../../core/audio/sound_player.dart';
import '../../core/audio/voice_analyzer.dart';
import '../../core/content.dart';
import '../../core/theme.dart';
import '../../models/child.dart';
import '../../widgets/characters.dart';
import '../../widgets/effects.dart';
import '../../widgets/kid_widgets.dart';
import '../../widgets/listening.dart';

/// Scoring rules for one Echo Safari stop, separate from the UI so they can
/// be unit-tested with synthetic voices.
class StopScorer {
  StopScorer({required this.target, required this.level, required this.holdSeconds, required this.syllablesNeeded});

  final SoundTarget target;
  final PlayLevel level;
  final double holdSeconds;
  final int syllablesNeeded;

  /// 0..1 flower growth.
  double progress = 0;

  /// 0..1 how much the child's sound currently matches the target
  /// (drives the mouth card's glow).
  double match = 0;

  Vowel? _lastVowel;

  bool get done => progress >= 1;

  /// Whether one frame matches the target sound.
  bool matches(VoiceFrame f) {
    switch (target.kind) {
      case TargetKind.hum:
        return f.hum;
      case TargetKind.vowel:
        final s = f.vowelScores;
        return !f.hum && s != null && VowelClassifier.matches(s, target.vowel!);
      case TargetKind.syllable:
        // Babbling syllables should open to a vowel like "ah" or "oh".
        final v = f.vowel ?? _lastVowel;
        return v == Vowel.ah || v == Vowel.oh;
    }
  }

  /// Folds in one analysed frame (32 ms).
  void add(VoiceFrame f) {
    if (done) return;
    if (f.vowel != null) _lastVowel = f.vowel;
    const hop = VoiceAnalyzer.hopSeconds;
    final isMatch = f.voiced && matches(f);
    match += ((isMatch ? 1.0 : 0.0) - match) * 0.15;
    if (!f.voiced) return;
    final explore = level == PlayLevel.explore;
    switch (target.kind) {
      case TargetKind.vowel:
      case TargetKind.hum:
        // Explore: any sound grows it. Practise: the target sound grows it
        // three times faster than other sounds (which still help).
        final w = explore ? 1.0 : (isMatch ? 1.0 : 0.33);
        progress += hop * w / holdSeconds;
      case TargetKind.syllable:
        // Each syllable is a step; a long single vowel still creeps forward.
        final w = explore ? 1.0 : (isMatch ? 1.0 : 0.5);
        progress += f.syllables * w / syllablesNeeded;
        progress += hop * 0.12 / holdSeconds;
    }
    progress = math.min(1, progress);
  }
}

/// One Echo Safari stop (PDD Screen 4): Pip models the sound and its mouth
/// shape, the child imitates, the flower grows, blooms and unlocks cards.
class SafariStopView extends StatefulWidget {
  const SafariStopView({super.key, required this.target});
  final SoundTarget target;

  @override
  State<SafariStopView> createState() => _SafariStopViewState();
}

enum _Phase { modelling, listening, blooming, reward }

class _SafariStopViewState extends ListeningState<SafariStopView> {
  late StopScorer _scorer = _newScorer();
  final _field = ParticleField(maxParticles: 60);
  _Phase _phase = _Phase.modelling;
  double _t = 0;
  double _bloom = 0;
  double _quiet = 0;
  double _level = 0;
  List<AacCard> _newCards = const [];
  Offset _flowerTop = Offset.zero;

  SoundTarget get target => widget.target;

  @override
  String get mode => 'safari';

  @override
  String? get targetId => target.id;

  StopScorer _newScorer() => StopScorer(
    target: target,
    level: child.settings.level,
    holdSeconds: child.holdSeconds,
    syllablesNeeded: child.syllablesNeeded,
  );

  @override
  void onStarted() => _model(first: true);

  /// Pip says the sound (always, even with coaching prompts off: modelling
  /// is the exercise), then invites the child.
  Future<void> _model({bool first = false}) async {
    if (!mounted || _phase == _Phase.blooming || _phase == _Phase.reward) return;
    if (first) services.session.attempt();
    setState(() => _phase = _Phase.modelling);
    final sp = services.speech;
    if (first) await sp.prompt('Let\'s say ${target.spoken}!');
    if (!mounted) return;
    await sp.say(target.spoken, rateOverride: 0.32);
    if (!mounted) return;
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
      if (latest.voiced) {
        _field.emit(_flowerTop, latest.level * 0.6, latest.pitchNorm, dt, calm: true);
      }
      if (_scorer.done) {
        _complete();
      } else if (_quiet > 9) {
        _quiet = 0;
        unawaited(_model());
      }
    } else if (_phase == _Phase.blooming) {
      _bloom = math.min(1, _bloom + dt / 1.2);
    }
    _field.step(dt);
    setState(() {});
  }

  void _tapFlower() {
    // Touch fallback without a mic: each tap grows the flower a little.
    if (_phase != _Phase.listening || micOn) return;
    _scorer.progress = math.min(1, _scorer.progress + 0.2);
    services.sound.sfx(Sfx.droplet, volume: 0.5);
    if (_scorer.done) _complete();
  }

  Future<void> _complete() async {
    if (_phase == _Phase.blooming || _phase == _Phase.reward) return;
    setState(() => _phase = _Phase.blooming);
    services.session.completion();
    _newCards = services.store.recordCompletion(child, target);
    services.sound.sfx(Sfx.bloom);
    _field.burst(_flowerTop, count: 22, calm: child.settings.calmMode);
    await services.speech.prompt('Yay! You did it!');
    await Future<void>.delayed(const Duration(milliseconds: 700));
    if (!mounted) return;
    setState(() => _phase = _Phase.reward);
    if (_newCards.isNotEmpty) {
      services.sound.sfx(Sfx.sparkle);
      await services.speech.prompt('A new card!');
      if (!mounted) return;
      await services.speech.say(_newCards.first.word);
    }
  }

  void _again() {
    services.speech.hush();
    setState(() {
      _scorer = _newScorer();
      _bloom = 0;
      _newCards = const [];
      _phase = _Phase.modelling;
    });
    _model(first: true);
  }

  void _next() {
    services.speech.hush();
    final i = targets.indexWhere((t) => t.id == target.id);
    Navigator.of(context).pop(targets[(i + 1) % targets.length]);
  }

  MouthShape get _shownShape {
    final speaking = services.speech.speaking.value;
    if (target.releaseMouth != null && (speaking || _phase == _Phase.modelling)) {
      // Syllables alternate closed and open, like "ba-ba-ba".
      return (_t * 3).floor().isEven ? target.mouth : target.releaseMouth!;
    }
    return target.releaseMouth ?? target.mouth;
  }

  @override
  Widget build(BuildContext context) {
    final shape = _shownShape;
    final happy = _phase == _Phase.blooming || _phase == _Phase.reward;
    return Scaffold(
      body: Backdrop(
        calm: child.settings.calmMode,
        top: const Color(0xFF16263A),
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, box) {
              final w = box.maxWidth, h = box.maxHeight;
              final flowerW = math.min(w * 0.6, h * 0.34);
              final flowerRect = Rect.fromCenter(
                center: Offset(w / 2, h * 0.68),
                width: flowerW,
                height: flowerW * 1.25,
              );
              _flowerTop = Offset(flowerRect.center.dx, flowerRect.top + flowerRect.height * 0.35);
              final charSize = math.min(w * 0.42, h * 0.24);
              return Stack(
                children: [
                  Positioned.fill(
                    child: IgnorePointer(child: CustomPaint(painter: ParticlePainter(_field))),
                  ),
                  // Pip and the mouth card side by side.
                  Positioned(
                    top: h * 0.1,
                    left: 0,
                    right: 0,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        Pip(
                          size: charSize,
                          shape: happy ? MouthShape.ah : shape,
                          happy: happy,
                          flap: happy ? math.sin(_t * 10) : _level * math.sin(_t * 12),
                          glow: happy ? 0.8 : _scorer.match * 0.6,
                        ),
                        Semantics(
                          label: 'Mouth shape for ${target.label}',
                          child: SizedBox.square(
                            dimension: charSize * 0.85,
                            child: CustomPaint(
                              painter: MouthPainter(
                                open: shape.open,
                                width: shape.width,
                                teeth: shape.teeth,
                                highlight: _scorer.match,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Positioned(
                    top: h * 0.1 + charSize + 4,
                    left: 0,
                    right: 0,
                    child: Text(
                      target.label,
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 56, fontWeight: FontWeight.w700, color: target.color, height: 1),
                    ),
                  ),
                  Positioned.fromRect(
                    rect: flowerRect,
                    child: GestureDetector(
                      onTap: _tapFlower,
                      child: CustomPaint(
                        painter: FlowerPainter(
                          progress: math.max(_scorer.progress, 0.02),
                          bloom: _bloom,
                          color: target.color,
                          sway: math.sin(_t * 1.3),
                        ),
                      ),
                    ),
                  ),
                  // The reward sits under the top buttons: a child can always go back.
                  if (_phase == _Phase.reward) _reward(w, h),
                  Positioned(top: 8, left: 8, child: const KidBackButton()),
                  if (_phase != _Phase.reward)
                    Positioned(
                      top: 8,
                      right: 8,
                      child: RoundButton(
                        key: const ValueKey('listen-again'),
                        icon: Icons.hearing_rounded,
                        label: 'Hear it again',
                        size: 64,
                        color: ES.sunshine,
                        onTap: _phase == _Phase.listening ? () => _model() : null,
                      ),
                    ),
                  Positioned(
                    left: 20,
                    right: 20,
                    bottom: 10,
                    child: Text(
                      micOn ? 'Grown-ups: ${target.tip}' : 'Grown-ups: ${target.tip} (No microphone: tap the flower.)',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: ES.muted, fontSize: 14),
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

  Widget _reward(double w, double h) {
    return Positioned.fill(
      child: ColoredBox(
        color: ES.canvasDeep.withValues(alpha: 0.7),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_newCards.isNotEmpty) ...[
                const Text(
                  'New card!',
                  style: TextStyle(fontSize: 34, fontWeight: FontWeight.w700, color: ES.sunshine),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  alignment: WrapAlignment.center,
                  children: [
                    for (final c in _newCards)
                      BouncyButton(
                        label: c.word,
                        onTap: () => services.speech.say(c.word),
                        child: _MiniCard(card: c, size: math.min(120, (w - 40) / _newCards.length - 12)),
                      ),
                  ],
                ),
              ] else ...[
                Pip(size: 150, shape: MouthShape.ah, happy: true, glow: 0.8),
                const Text(
                  'Great job!',
                  style: TextStyle(fontSize: 34, fontWeight: FontWeight.w700, color: ES.sunshine),
                ),
              ],
              const SizedBox(height: 28),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  RoundButton(
                    key: const ValueKey('stop-again'),
                    icon: Icons.replay_rounded,
                    label: 'Again',
                    color: ES.turquoise,
                    onTap: _again,
                  ),
                  const SizedBox(width: 28),
                  RoundButton(
                    key: const ValueKey('stop-next'),
                    icon: Icons.arrow_forward_rounded,
                    label: 'Next sound',
                    color: ES.coral,
                    onTap: _next,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MiniCard extends StatelessWidget {
  const _MiniCard({required this.card, required this.size});
  final AacCard card;
  final double size;

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    padding: const EdgeInsets.all(10),
    decoration: BoxDecoration(color: ES.cream, borderRadius: BorderRadius.circular(18)),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Image.asset(card.asset, width: size * 0.7, height: size * 0.7),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            card.word,
            maxLines: 1,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: ES.canvasDeep),
          ),
        ),
      ],
    ),
  );
}
