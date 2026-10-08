// Echo Turns (v1.1): my turn / your turn. Pip says the sound, Milo waits
// with a visible "your turn" ring, the child echoes, Pip claps; four turns
// make a round. Turn-taking is the backbone of early speech practice, and
// nothing here can be failed: a quiet child just hears the sound again.

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
import '../safari/safari_stop_view.dart' show StopScorer;

class EchoTurnsView extends StatefulWidget {
  const EchoTurnsView({super.key, this.target});

  /// Sound to practise; defaults to the child's suggested Safari sound.
  final SoundTarget? target;

  @override
  State<EchoTurnsView> createState() => _EchoTurnsViewState();
}

enum _Phase { pipTurn, yourTurn, clap, finished }

class _EchoTurnsViewState extends ListeningState<EchoTurnsView> {
  static const turnsPerRound = 4;

  late final SoundTarget target = widget.target ?? child.suggestedTarget;
  final _field = ParticleField(maxParticles: 50);
  _Phase _phase = _Phase.pipTurn;
  int _turn = 0;
  late StopScorer _scorer = _newScorer();
  double _t = 0;
  double _level = 0;
  double _quiet = 0;
  Offset _miloCenter = Offset.zero;

  @override
  String get mode => 'turns';

  @override
  String? get targetId => target.id;

  StopScorer _newScorer() => StopScorer(
    target: target,
    level: child.settings.level,
    // One echo per turn: shorter than a Safari hold.
    holdSeconds: math.max(1.0, child.holdSeconds * 0.6),
    syllablesNeeded: math.max(2, child.syllablesNeeded ~/ 2),
  );

  @override
  void onStarted() {
    services.session.attempt();
    unawaited(_pipTurn(first: true));
  }

  Future<void> _pipTurn({bool first = false}) async {
    if (!mounted || _phase == _Phase.finished) return;
    setState(() => _phase = _Phase.pipTurn);
    final sp = services.speech;
    if (first) await sp.prompt('Let\'s take turns! Pip first.');
    if (!mounted) return;
    await sp.say(target.spoken, rateOverride: 0.32);
    if (!mounted || _phase != _Phase.pipTurn) return;
    await sp.prompt('Your turn!');
    if (!mounted || _phase != _Phase.pipTurn) return;
    _quiet = 0;
    setState(() => _phase = _Phase.yourTurn);
  }

  @override
  void onFrames(VoiceFrame latest, List<VoiceFrame> frames, double dt) {
    _t += dt;
    _level = smoothTo(_level, latest.level, 10, dt);
    if (_phase == _Phase.yourTurn) {
      for (final f in frames) {
        _scorer.add(f);
      }
      _quiet = latest.voiced ? 0 : _quiet + dt;
      if (latest.voiced) _field.emit(_miloCenter, latest.level * 0.5, latest.pitchNorm, dt, calm: true);
      if (_scorer.done) {
        unawaited(_clap());
      } else if (_quiet > 8) {
        _quiet = 0;
        unawaited(_pipTurn());
      }
    }
    _field.step(dt);
    setState(() {});
  }

  void _tapMilo() {
    // Touch fallback without a microphone: a tap is a turn.
    if (_phase != _Phase.yourTurn || micOn) return;
    _scorer.progress = 1;
    services.sound.sfx(Sfx.droplet, volume: 0.5);
    unawaited(_clap());
  }

  Future<void> _clap() async {
    if (_phase == _Phase.clap || _phase == _Phase.finished) return;
    setState(() {
      _phase = _Phase.clap;
      _turn++;
    });
    services.sound.sfx(Sfx.chime, volume: 0.6);
    _field.burst(_miloCenter, count: 14, calm: child.settings.calmMode);
    await services.speech.prompt(_turn < turnsPerRound ? 'Nice! My turn.' : 'Yay! All the turns!');
    if (!mounted) return;
    if (_turn >= turnsPerRound) {
      services.session.completion();
      services.store.recordCompletion(child, target);
      services.sound.sfx(Sfx.bloom);
      setState(() => _phase = _Phase.finished);
      return;
    }
    _scorer = _newScorer();
    await Future<void>.delayed(const Duration(milliseconds: 500));
    unawaited(_pipTurn());
  }

  void _again() {
    services.speech.hush();
    setState(() {
      _turn = 0;
      _scorer = _newScorer();
      _phase = _Phase.pipTurn;
    });
    services.session.attempt();
    unawaited(_pipTurn(first: true));
  }

  @override
  Widget build(BuildContext context) {
    final calm = child.settings.calmMode;
    final pipTalking = _phase == _Phase.pipTurn;
    final yourTurn = _phase == _Phase.yourTurn;
    final happy = _phase == _Phase.clap || _phase == _Phase.finished;
    return Scaffold(
      body: Backdrop(
        calm: calm,
        top: const Color(0xFF2A1F3A),
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, box) {
              final w = box.maxWidth, h = box.maxHeight;
              final charSize = math.min(w * 0.4, h * 0.26);
              _miloCenter = Offset(w * 0.72, h * 0.42);
              final ringR = charSize * 0.62 * (1 + (calm ? 0.03 : 0.07) * math.sin(_t * 3));
              return Stack(
                children: [
                  Positioned.fill(
                    child: IgnorePointer(child: CustomPaint(painter: ParticlePainter(_field))),
                  ),
                  // Kept clear of the two round buttons on narrow phones.
                  Positioned(
                    top: 8,
                    left: 72,
                    right: 72,
                    height: 44,
                    child: Center(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          'Echo Turns: ${target.label}',
                          maxLines: 1,
                          style: TextStyle(fontSize: 28, fontWeight: FontWeight.w700, color: target.color),
                        ),
                      ),
                    ),
                  ),
                  // Turn dots: one per turn, filled when done.
                  Positioned(
                    top: 52,
                    left: 0,
                    right: 0,
                    child: Row(
                      key: const ValueKey('turn-dots'),
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        for (var i = 0; i < turnsPerRound; i++)
                          Container(
                            width: 18,
                            height: 18,
                            margin: const EdgeInsets.all(5),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: i < _turn ? ES.sunshine : ES.cardLine,
                              border: Border.all(color: ES.sunshine, width: 2),
                            ),
                          ),
                      ],
                    ),
                  ),
                  // Pip on the left (speaker), Milo on the right (the child's side).
                  Positioned(
                    top: h * 0.42 - charSize / 2,
                    left: w * 0.28 - charSize / 2,
                    child: Column(
                      children: [
                        Pip(
                          size: charSize,
                          shape: happy ? MouthShape.ah : (target.releaseMouth ?? target.mouth),
                          happy: happy,
                          flap: happy ? math.sin(_t * 10) : (pipTalking ? math.sin(_t * 14) * 0.8 : 0),
                          glow: pipTalking ? 0.6 : (happy ? 0.8 : 0.1),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          pipTalking ? 'Pip\'s turn' : 'Pip',
                          style: TextStyle(fontSize: 18, color: pipTalking ? ES.sunshine : ES.muted),
                        ),
                      ],
                    ),
                  ),
                  Positioned(
                    top: h * 0.42 - charSize / 2,
                    left: w * 0.72 - charSize / 2,
                    child: GestureDetector(
                      onTap: _tapMilo,
                      child: Column(
                        children: [
                          Stack(
                            alignment: Alignment.center,
                            children: [
                              if (yourTurn)
                                Container(
                                  width: ringR * 2,
                                  height: ringR * 2,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(color: ES.sunshine.withValues(alpha: 0.8), width: 5),
                                  ),
                                ),
                              Milo(size: charSize, awake: 1, mouth: yourTurn ? _level : 0, glow: yourTurn ? _scorer.match * 0.6 : 0),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            yourTurn ? 'Your turn!' : 'You',
                            key: const ValueKey('turn-cue'),
                            style: TextStyle(fontSize: 18, color: yourTurn ? ES.sunshine : ES.muted),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Positioned(
                    top: h * 0.42 + charSize / 2 + 40,
                    left: 0,
                    right: 0,
                    child: Text(
                      target.label,
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 56, fontWeight: FontWeight.w700, color: target.color, height: 1),
                    ),
                  ),
                  if (_phase == _Phase.finished) _finished(w),
                  Positioned(top: 8, left: 8, child: const KidBackButton()),
                  if (yourTurn)
                    Positioned(
                      top: 8,
                      right: 8,
                      child: RoundButton(
                        key: const ValueKey('turn-again'),
                        icon: Icons.hearing_rounded,
                        label: 'Hear it again',
                        size: 56,
                        color: ES.sunshine,
                        onTap: () => _pipTurn(),
                      ),
                    ),
                  Positioned(
                    left: 20,
                    right: 20,
                    bottom: 10,
                    child: Text(
                      micOn
                          ? 'Grown-ups: wait quietly on "Your turn" - the pause is where the child learns to take it.'
                          : 'Grown-ups: no microphone - tap Milo when the child has had a turn.',
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

  Widget _finished(double w) {
    return Positioned.fill(
      child: ColoredBox(
        color: ES.canvasDeep.withValues(alpha: 0.7),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Pip(size: 150, shape: MouthShape.ah, happy: true, glow: 0.8),
              const Text(
                'Great turns!',
                key: ValueKey('turns-done'),
                style: TextStyle(fontSize: 34, fontWeight: FontWeight.w700, color: ES.sunshine),
              ),
              const SizedBox(height: 28),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  RoundButton(
                    key: const ValueKey('turns-again'),
                    icon: Icons.replay_rounded,
                    label: 'Again',
                    color: ES.turquoise,
                    onTap: _again,
                  ),
                  const SizedBox(width: 28),
                  RoundButton(
                    key: const ValueKey('turns-home'),
                    icon: Icons.home_rounded,
                    label: 'Home',
                    color: ES.coral,
                    onTap: () => Navigator.of(context).maybePop(),
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
