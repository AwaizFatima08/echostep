// Animal Friends (v1.1): six animals whose calls are Safari sounds in
// disguise. Tap an animal, hear it, echo it; the animal wiggles and sparkles
// while the child's sound matches and never looks sad. A finished call counts
// as practising the matching Safari sound, so progress stays in one place.

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/audio/voice_analyzer.dart';
import '../../core/audio/audio_input.dart' show smoothTo;
import '../../core/audio/sound_player.dart';
import '../../core/content.dart';
import '../../core/theme.dart';
import '../../widgets/characters.dart';
import '../../widgets/effects.dart';
import '../../widgets/kid_widgets.dart';
import '../../widgets/listening.dart';
import '../safari/safari_stop_view.dart' show StopScorer;

class AnimalFriendsView extends StatefulWidget {
  const AnimalFriendsView({super.key});

  @override
  State<AnimalFriendsView> createState() => _AnimalFriendsViewState();
}

enum _Phase { choosing, modelling, listening, celebrating }

class _AnimalFriendsViewState extends ListeningState<AnimalFriendsView> {
  final _field = ParticleField(maxParticles: 50);
  _Phase _phase = _Phase.choosing;
  AnimalFriend? _animal;
  StopScorer? _scorer;
  double _t = 0;
  double _level = 0;
  double _quiet = 0;
  double _wiggle = 0;
  final _done = <String>{};
  Offset _animalCenter = Offset.zero;

  @override
  String get mode => 'animals';

  @override
  String? get targetId => _animal?.targetId;

  @override
  void onStarted() {
    unawaited(services.speech.prompt('Tap an animal!'));
  }

  Future<void> _choose(AnimalFriend a) async {
    if (_phase == _Phase.modelling || _phase == _Phase.celebrating) return;
    services.speech.hush();
    final t = a.target;
    setState(() {
      _animal = a;
      _phase = _Phase.modelling;
      _scorer = StopScorer(
        target: t,
        level: child.settings.level,
        // Animal calls are short: half a Safari hold is enough for one call.
        holdSeconds: math.max(1.0, child.holdSeconds * 0.6),
        syllablesNeeded: math.max(2, child.syllablesNeeded ~/ 2),
      );
    });
    services.session.attempt();
    // Re-open the input for the chosen sound: the synthetic voice (tests,
    // emulator) follows the target; a real microphone just restarts.
    await services.voice.stop(owner: this);
    if (!mounted || _animal != a) return;
    final ok = await services.voice.start(targetId: a.targetId, owner: this);
    if (!mounted || _animal != a) return;
    setState(() => micOn = ok);
    services.voice.drain();
    await _model();
  }

  Future<void> _model() async {
    final a = _animal;
    if (a == null || !mounted) return;
    setState(() => _phase = _Phase.modelling);
    final sp = services.speech;
    await sp.say('The ${a.name.toLowerCase()} says', rateOverride: 0.4);
    if (!mounted || _animal != a) return;
    await sp.say(a.spoken, rateOverride: 0.32);
    if (!mounted || _animal != a) return;
    await sp.prompt('Your turn!');
    if (!mounted || _animal != a || _phase != _Phase.modelling) return;
    _quiet = 0;
    setState(() => _phase = _Phase.listening);
  }

  @override
  void onFrames(VoiceFrame latest, List<VoiceFrame> frames, double dt) {
    _t += dt;
    _level = smoothTo(_level, latest.level, 10, dt);
    final sc = _scorer;
    if (_phase == _Phase.listening && sc != null) {
      for (final f in frames) {
        sc.add(f);
      }
      _wiggle = smoothTo(_wiggle, sc.match, 6, dt);
      _quiet = latest.voiced ? 0 : _quiet + dt;
      if (latest.voiced) {
        _field.emit(_animalCenter, latest.level * 0.5 * sc.match, latest.pitchNorm, dt, calm: true);
      }
      if (sc.done) {
        unawaited(_celebrate());
      } else if (_quiet > 9) {
        _quiet = 0;
        unawaited(_model());
      }
    } else {
      _wiggle = smoothTo(_wiggle, 0, 4, dt);
    }
    _field.step(dt);
    setState(() {});
  }

  void _tapAnimalPicture() {
    // Touch fallback without a microphone: each tap is one call.
    final sc = _scorer;
    if (_phase != _Phase.listening || micOn || sc == null) return;
    sc.progress = math.min(1, sc.progress + 0.34);
    services.sound.sfx(Sfx.droplet, volume: 0.5);
    if (sc.done) unawaited(_celebrate());
  }

  Future<void> _celebrate() async {
    final a = _animal;
    if (a == null || _phase == _Phase.celebrating) return;
    setState(() => _phase = _Phase.celebrating);
    services.session.completion();
    services.store.recordCompletion(child, a.target);
    _done.add(a.id);
    services.sound.sfx(Sfx.sparkle);
    _field.burst(_animalCenter, count: 20, calm: child.settings.calmMode);
    await services.speech.prompt('${a.call}! You did it!');
    await Future<void>.delayed(const Duration(milliseconds: 900));
    if (!mounted) return;
    setState(() {
      _phase = _Phase.choosing;
      _animal = null;
      _scorer = null;
    });
    unawaited(services.speech.prompt('Tap another animal!'));
  }

  @override
  Widget build(BuildContext context) {
    final a = _animal;
    final calm = child.settings.calmMode;
    return Scaffold(
      body: Backdrop(
        calm: calm,
        top: const Color(0xFF1F3A2A),
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, box) {
              return Stack(
                children: [
                  Positioned.fill(
                    child: IgnorePointer(child: CustomPaint(painter: ParticlePainter(_field))),
                  ),
                  // Title / body / footer as a column, so the grown-ups' note
                  // never covers the grid on small or large-font phones.
                  Positioned.fill(
                    child: Column(
                      children: [
                        SizedBox(
                          height: _titleH,
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(72, 8, 72, 0),
                            child: Center(
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text(
                                  a == null ? 'Animal Friends' : '${a.name} says "${a.call}"',
                                  key: const ValueKey('animals-title'),
                                  maxLines: 1,
                                  style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w700, color: ES.mint),
                                ),
                              ),
                            ),
                          ),
                        ),
                        Expanded(
                          child: LayoutBuilder(
                            builder: (context, inner) =>
                                a == null ? _grid(inner.maxWidth, inner.maxHeight) : _stage(a, inner.maxWidth, inner.maxHeight),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(20, 4, 20, 10),
                          child: Text(
                            a == null
                                ? 'Grown-ups: every animal call is one of the Safari sounds, so this counts as practice too.'
                                : 'Grown-ups: ${a.target.tip}${micOn ? '' : ' (No microphone: tap the animal.)'}',
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: ES.muted, fontSize: 14),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Positioned(top: 8, left: 8, child: KidBackButton(onTap: a == null ? null : _back)),
                  if (_phase == _Phase.listening)
                    Positioned(
                      top: 8,
                      right: 8,
                      child: RoundButton(
                        key: const ValueKey('animal-again'),
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

  void _back() {
    services.speech.hush();
    setState(() {
      _phase = _Phase.choosing;
      _animal = null;
      _scorer = null;
    });
  }

  static const _titleH = 72.0;

  Widget _grid(double w, double h) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: GridView.count(
        crossAxisCount: 2,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: (w - 36) / 2 / ((h - 24) / 3),
        physics: const NeverScrollableScrollPhysics(),
        children: [
          for (final an in animals)
            BouncyButton(
              key: ValueKey('animal-${an.id}'),
              label: '${an.name} says ${an.call}',
              onTap: () => _choose(an),
              child: Container(
                decoration: BoxDecoration(
                  color: ES.card,
                  borderRadius: BorderRadius.circular(ES.radius),
                  border: Border.all(color: _done.contains(an.id) ? ES.sunshine : an.target.color, width: 3),
                ),
                padding: const EdgeInsets.all(8),
                child: Column(
                  children: [
                    Expanded(child: Image.asset(an.asset, fit: BoxFit.contain)),
                    Text(
                      an.call,
                      style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: an.target.color),
                    ),
                    if (_done.contains(an.id)) const Icon(Icons.star_rounded, color: ES.sunshine, size: 22),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _stage(AnimalFriend a, double w, double h) {
    final size = math.min(w * 0.6, h * 0.36);
    // Particles are painted over the whole screen: offset by the title band.
    _animalCenter = Offset(w / 2, _titleH + h * 0.45);
    final celebrating = _phase == _Phase.celebrating;
    final tilt = celebrating ? math.sin(_t * 12) * 0.12 : math.sin(_t * 9) * 0.08 * _wiggle;
    final scale = 1 + (celebrating ? 0.08 : 0.06 * _wiggle);
    return Stack(
      children: [
        Positioned(
          top: h * 0.45 - size / 2,
          left: w / 2 - size / 2,
          child: GestureDetector(
            onTap: _tapAnimalPicture,
            child: Transform.rotate(
              angle: tilt,
              child: Transform.scale(
                scale: scale,
                child: Container(
                  width: size,
                  height: size,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: a.target.color.withValues(alpha: 0.15 + 0.45 * math.max(_wiggle, celebrating ? 1 : 0)),
                        blurRadius: 40,
                        spreadRadius: 6,
                      ),
                    ],
                  ),
                  child: Image.asset(a.asset, key: const ValueKey('animal-stage'), fit: BoxFit.contain),
                ),
              ),
            ),
          ),
        ),
        Positioned(
          top: h * 0.45 + size / 2 + 8,
          left: 0,
          right: 0,
          child: Column(
            children: [
              Text(
                a.call,
                style: TextStyle(fontSize: 48, fontWeight: FontWeight.w700, color: a.target.color, height: 1),
              ),
              const SizedBox(height: 8),
              // A soft progress heart: fills as the call is echoed. Never empties.
              SizedBox(
                width: 140,
                height: 10,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(5),
                  child: LinearProgressIndicator(
                    value: math.max(0.03, _scorer?.progress ?? 0),
                    backgroundColor: ES.cardLine,
                    color: a.target.color,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                switch (_phase) {
                  _Phase.modelling => 'Listen...',
                  _Phase.listening => 'Your turn!',
                  _Phase.celebrating => 'Yay!',
                  _Phase.choosing => '',
                },
                key: const ValueKey('animals-cue'),
                style: const TextStyle(fontSize: 26, color: ES.cream),
              ),
            ],
          ),
        ),
        Positioned(
          top: 0,
          right: 12,
          child: Pip(
            size: math.min(w * 0.28, 110),
            shape: celebrating ? MouthShape.ah : (a.target.releaseMouth ?? a.target.mouth),
            happy: celebrating,
            flap: celebrating ? math.sin(_t * 10) : _level * math.sin(_t * 12),
            glow: celebrating ? 0.8 : _wiggle * 0.6,
          ),
        ),
      ],
    );
  }
}
