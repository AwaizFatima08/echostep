import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/audio/audio_input.dart';
import '../../core/audio/sound_player.dart';
import '../../core/audio/voice_analyzer.dart';
import '../../core/theme.dart';
import '../../widgets/characters.dart';
import '../../widgets/effects.dart';
import '../../widgets/kid_widgets.dart';
import '../../widgets/listening.dart';

/// Sound Spark (PDD Screen 3): free play for children who make minimal or
/// very quiet sounds. Milo sleeps; any sound above the room's noise wakes
/// him, makes him glow and sends bubbles up. Whispers make small yellow
/// bubbles, louder sounds bigger rainbow ones and stars. Silence just lets
/// him doze off again: nothing is ever "wrong".
class SoundSparkView extends StatefulWidget {
  const SoundSparkView({super.key});

  @override
  State<SoundSparkView> createState() => _SoundSparkViewState();
}

class _SoundSparkViewState extends ListeningState<SoundSparkView> {
  final _field = ParticleField();
  final _rand = math.Random();

  double _level = 0; // smoothed loudness
  double _awake = 0;
  double _quiet = 99; // seconds since the last sound
  double _idle = 0; // seconds without any sound since the last nudge
  double _t = 0;
  double _blinkAt = 3;
  int _vocalizations = 0;
  int _praisedAt = 0;
  bool _wasAsleep = true;
  Offset _mouth = Offset.zero;
  double _pitch = 0.5;

  static const _praise = ['Wow!', 'Beautiful sound!', 'Yay!', 'I hear you!', 'More, more!', 'So good!'];

  @override
  String get mode => 'spark';

  @override
  void onStarted() {
    services.speech.prompt(micOn ? 'Milo is sleeping. Make a sound to wake him up!' : 'Tap Milo to wake him up!');
  }

  @override
  void onFrames(VoiceFrame latest, List<VoiceFrame> frames, double dt) {
    _t += dt;
    final calm = child.settings.calmMode;
    for (final f in frames) {
      _vocalizations += f.vocalizations;
    }
    final sounding = latest.voiced;
    _level = smoothTo(_level, latest.level, sounding ? 14 : 5, dt);
    if (latest.pitched) _pitch = smoothTo(_pitch, latest.pitchNorm, 6, dt);

    if (sounding) {
      _quiet = 0;
      _idle = 0;
      if (_wasAsleep) {
        _wasAsleep = false;
        services.sound.sfx(Sfx.wake, volume: 0.6);
      }
    } else {
      _quiet += dt;
      _idle += dt;
    }
    // Wake fast, doze off slowly after a few quiet seconds.
    final targetAwake = _quiet < 3.5 ? 1.0 : 0.0;
    _awake = smoothTo(_awake, targetAwake, targetAwake > _awake ? 6 : 0.8, dt);
    if (_awake < 0.15) _wasAsleep = true;

    _field.emit(_mouth, sounding ? math.max(latest.level, 0.08) : 0, _pitch, dt, calm: calm);
    _field.step(dt);

    // Sparse, short praise after a sound ends, so speech never talks over
    // the child (the mic is muted while the app speaks).
    if (_quiet > 1.0 && _quiet < 1.2 && _vocalizations >= _praisedAt + 3) {
      _praisedAt = _vocalizations;
      services.speech.prompt(_praise[_rand.nextInt(_praise.length)]);
    }
    // A gentle nudge after a long silence, at most every 25 s.
    if (_idle > 25) {
      _idle = 0;
      services.speech.prompt(micOn ? 'Can you say, ahhh?' : 'Tap Milo!');
    }
    if (_t > _blinkAt + 0.18) _blinkAt = _t + 2.5 + _rand.nextDouble() * 3;
    setState(() {});
  }

  void _tapMilo() {
    _quiet = 0;
    _idle = 0;
    _awake = math.max(_awake, 0.7);
    services.sound.sfx(Sfx.droplet, volume: 0.6);
    _field.burst(_mouth, count: 10, calm: child.settings.calmMode);
  }

  Future<void> _toggleSfx() async {
    final st = services.store.settings;
    st.sfxOn = !st.sfxOn;
    services.store.save();
    services.applySettings();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final calm = child.settings.calmMode;
    final blink = (_t > _blinkAt && _t < _blinkAt + 0.18) ? 1.0 : 0.0;
    final breathe = _awake < 0.5 ? 1 + 0.025 * math.sin(_t * 1.6) : 1 + 0.06 * _level;
    return Scaffold(
      body: Backdrop(
        calm: calm,
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, box) {
              final size = math.min(box.maxWidth * 0.78, box.maxHeight * 0.42);
              final center = Offset(box.maxWidth / 2, box.maxHeight * 0.42);
              _mouth = center + Offset(0, size * 0.1);
              return Stack(
                children: [
                  Positioned.fill(
                    child: IgnorePointer(child: CustomPaint(painter: ParticlePainter(_field))),
                  ),
                  Positioned(
                    left: center.dx - size / 2,
                    top: center.dy - size / 2,
                    child: GestureDetector(
                      onTap: _tapMilo,
                      child: Semantics(
                        label: 'Milo the bear',
                        button: true,
                        child: Transform.scale(
                          scale: breathe,
                          child: Milo(
                            size: size,
                            awake: _awake,
                            mouth: _awake > 0.5 ? _level : 0,
                            glow: math.max(_awake * 0.35, _level),
                            blink: blink,
                          ),
                        ),
                      ),
                    ),
                  ),
                  if (_awake < 0.3) _Zzz(anchor: center + Offset(size * 0.3, -size * 0.35), t: _t),
                  Positioned(top: 8, left: 8, child: const KidBackButton()),
                  Positioned(
                    top: 8,
                    right: 8,
                    child: RoundButton(
                      icon: services.store.settings.sfxOn ? Icons.volume_up_rounded : Icons.volume_off_rounded,
                      label: services.store.settings.sfxOn ? 'Mute sounds' : 'Turn sounds on',
                      size: 64,
                      color: ES.sunshine,
                      onTap: _toggleSfx,
                    ),
                  ),
                  Positioned(
                    left: 16,
                    right: 16,
                    bottom: 12,
                    child: _MicMeter(level: _level, micOn: micOn),
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

/// Floating "z"s while Milo sleeps.
class _Zzz extends StatelessWidget {
  const _Zzz({required this.anchor, required this.t});
  final Offset anchor;
  final double t;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        for (var i = 0; i < 3; i++)
          Builder(
            builder: (_) {
              final phase = ((t * 0.4) + i / 3) % 1.0;
              return Positioned(
                left: anchor.dx + phase * 40 + i * 6,
                top: anchor.dy - phase * 70,
                child: Opacity(
                  opacity: math.sin(phase * math.pi).clamp(0.0, 1.0),
                  child: Text(
                    'z',
                    style: TextStyle(fontSize: 22 + i * 8.0, fontWeight: FontWeight.w700, color: ES.lilac),
                  ),
                ),
              );
            },
          ),
      ],
    );
  }
}

/// The "mic level" bar from the PDD mock-up: shows the grown-up that sound
/// is getting through.
class _MicMeter extends StatelessWidget {
  const _MicMeter({required this.level, required this.micOn});
  final double level;
  final bool micOn;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: ES.card.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(ES.radius),
        border: Border.all(color: ES.cardLine, width: 2),
      ),
      child: Row(
        children: [
          Icon(micOn ? Icons.mic_rounded : Icons.mic_off_rounded, color: micOn ? ES.turquoise : ES.muted, size: 30),
          const SizedBox(width: 12),
          Expanded(
            child: micOn
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: SizedBox(
                      height: 22,
                      child: Stack(
                        children: [
                          Container(color: ES.canvasDeep),
                          FractionallySizedBox(
                            widthFactor: level.clamp(0.02, 1.0),
                            child: Container(
                              decoration: const BoxDecoration(
                                gradient: LinearGradient(colors: [ES.sunshine, ES.coral, ES.lilac]),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                : const Text('Tap Milo to play', style: TextStyle(fontSize: 18)),
          ),
        ],
      ),
    );
  }
}
