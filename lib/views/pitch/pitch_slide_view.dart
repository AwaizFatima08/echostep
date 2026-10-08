// Pitch Slide (v1.1): Pip flies higher with a high voice and lower with a
// low one, leaving a glowing trail across a slow mountain path. Any
// vocalisation works; there is nothing to score, only sky to explore. Calm
// mode flattens the hills and slows the scroll.

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/audio/audio_input.dart' show smoothTo;
import '../../core/audio/voice_analyzer.dart';
import '../../core/content.dart';
import '../../core/theme.dart';
import '../../widgets/characters.dart';
import '../../widgets/effects.dart';
import '../../widgets/kid_widgets.dart';
import '../../widgets/listening.dart';

class PitchSlideView extends StatefulWidget {
  const PitchSlideView({super.key});

  @override
  State<PitchSlideView> createState() => _PitchSlideViewState();
}

/// Pure state for the trail and the guide path, unit-testable.
class PitchTrail {
  PitchTrail({this.calm = false});

  final bool calm;

  /// Normalised height 0 (low) .. 1 (high) of the last ~6 seconds, newest last.
  final List<double?> points = [];
  double scroll = 0;
  double height = 0.5;
  double _hold = 0;

  static const seconds = 6.0;
  static const perSecond = 20;

  /// Guide path: gentle hills the child can follow (or ignore).
  double guideAt(double x) {
    final amp = calm ? 0.18 : 0.3;
    return 0.5 + amp * math.sin(x * 2 * math.pi / 8) + amp * 0.3 * math.sin(x * 2 * math.pi / 3.1);
  }

  void step(VoiceFrame f, double dt) {
    final speed = calm ? 0.45 : 0.8;
    scroll += dt * speed;
    if (f.voiced && f.pitched) {
      // Follow the voice quickly, drift down slowly in silence.
      height = smoothTo(height, f.pitchNorm, 12, dt);
      _hold = 0.6;
    } else {
      _hold -= dt;
      if (_hold < 0) height = smoothTo(height, 0.5, 1.2, dt);
    }
    points.add(f.voiced ? height : null);
    final max = (seconds * perSecond).round();
    while (points.length > max) {
      points.removeAt(0);
    }
  }
}

class _PitchSlideViewState extends ListeningState<PitchSlideView> {
  final _trail = PitchTrail();
  late final PitchTrail _calmTrail = PitchTrail(calm: true);
  final _field = ParticleField(maxParticles: 60);
  double _t = 0;
  double _level = 0;
  double _acc = 0;
  int _voicedFrames = 0;
  Offset _pip = Offset.zero;
  bool _welcomed = false;

  PitchTrail get trail => child.settings.calmMode ? _calmTrail : _trail;

  @override
  String get mode => 'pitch';

  @override
  void onStarted() {
    if (_welcomed) return;
    _welcomed = true;
    services.speech.prompt('Sing high, sing low. Pip flies with you!');
  }

  @override
  void onFrames(VoiceFrame latest, List<VoiceFrame> frames, double dt) {
    _t += dt;
    _level = smoothTo(_level, latest.level, 10, dt);
    // The trail samples at a fixed rate so it scrolls evenly.
    _acc += dt;
    while (_acc >= 1 / PitchTrail.perSecond) {
      _acc -= 1 / PitchTrail.perSecond;
      trail.step(latest, 1 / PitchTrail.perSecond);
    }
    if (latest.voiced) {
      _voicedFrames++;
      _field.emit(_pip, latest.level * 0.6, latest.pitchNorm, dt, calm: child.settings.calmMode);
    }
    _field.step(dt);
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final calm = child.settings.calmMode;
    final tr = trail;
    return Scaffold(
      body: Backdrop(
        calm: calm,
        top: const Color(0xFF1B2B4A),
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, box) {
              final w = box.maxWidth, h = box.maxHeight;
              // Leave room for the grown-ups' note (up to three lines).
              final top = 70.0, bottom = h - 100;
              final pipX = w * 0.7;
              final pipY = bottom - (bottom - top) * tr.height;
              _pip = Offset(pipX, pipY);
              return Stack(
                children: [
                  Positioned.fill(
                    child: CustomPaint(painter: _SkyPainter(tr, top: top, bottom: bottom, pipX: pipX)),
                  ),
                  Positioned.fill(
                    child: IgnorePointer(child: CustomPaint(painter: ParticlePainter(_field))),
                  ),
                  Positioned(
                    left: pipX - 50,
                    top: pipY - 50,
                    child: Pip(
                      key: const ValueKey('pitch-pip'),
                      size: 100,
                      shape: _level > 0.08 ? MouthShape.ah : MouthShape.closed,
                      flap: math.sin(_t * (6 + 10 * _level)),
                      glow: _level * 0.8,
                    ),
                  ),
                  Positioned(
                    top: 8,
                    left: 72,
                    right: 72,
                    height: 44,
                    child: Center(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          _voicedFrames == 0 ? 'Make a sound to fly!' : (tr.height > 0.65 ? 'High!' : tr.height < 0.35 ? 'Low!' : 'Flying...'),
                          key: const ValueKey('pitch-cue'),
                          maxLines: 1,
                          style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w700, color: ES.sunshine),
                        ),
                      ),
                    ),
                  ),
                  Positioned(top: 8, left: 8, child: const KidBackButton()),
                  Positioned(
                    left: 20,
                    right: 20,
                    bottom: 10,
                    child: Text(
                      micOn
                          ? 'Grown-ups: slide your own voice up and down ("wheee", "oooh") and let the child copy the ride.'
                          : 'Grown-ups: no microphone - Pip rests on the hills. Allow the mic in Settings to fly.',
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
}

class _SkyPainter extends CustomPainter {
  _SkyPainter(this.trail, {required this.top, required this.bottom, required this.pipX});
  final PitchTrail trail;
  final double top, bottom, pipX;

  @override
  void paint(Canvas canvas, Size size) {
    final span = bottom - top;
    double yOf(double n) => bottom - span * n;
    // Guide hills: dotted, scrolling left, drawn across the whole width.
    final guide = Paint()
      ..color = ES.lilac.withValues(alpha: 0.35)
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    const dots = 60;
    for (var i = 0; i < dots; i++) {
      final x = size.width * i / dots;
      final worldX = trail.scroll + (x - pipX) / size.width * PitchTrail.seconds;
      canvas.drawCircle(Offset(x, yOf(trail.guideAt(worldX))), 3, guide);
    }
    // The child's trail: newest point sits at Pip's x, older ones to the left.
    final pts = trail.points;
    if (pts.length < 2) return;
    final px = pipX / (PitchTrail.seconds * PitchTrail.perSecond);
    final line = Paint()
      ..strokeWidth = 6
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    Path? path;
    for (var i = 0; i < pts.length; i++) {
      final p = pts[i];
      final x = pipX - (pts.length - 1 - i) * px;
      if (p == null) {
        path = null;
        continue;
      }
      final o = Offset(x, yOf(p));
      if (path == null) {
        path = Path()..moveTo(o.dx, o.dy);
      } else {
        path.lineTo(o.dx, o.dy);
        final a = (i / pts.length).clamp(0.15, 1.0);
        line.color = Color.lerp(ES.turquoise, ES.sunshine, p)!.withValues(alpha: a);
        canvas.drawPath(path, line);
        path = Path()..moveTo(o.dx, o.dy);
      }
    }
  }

  @override
  bool shouldRepaint(_SkyPainter old) => true;
}
