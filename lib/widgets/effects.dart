import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../core/theme.dart';

/// Bubbles and stars rising from Milo while the child makes sound.
/// Whispers make small yellow bubbles; louder sounds make bigger, rainbow
/// ones and (outside calm mode) glowing stars (PDD Screen 3).
class Particle {
  Particle(this.pos, this.vel, this.radius, this.hue, this.star, this.life);
  Offset pos;
  Offset vel;
  final double radius;
  final double hue;
  final bool star;
  double life; // seconds left
  double age = 0;
  final double wobble = math.Random().nextDouble() * math.pi * 2;
}

class ParticleField extends ChangeNotifier {
  ParticleField({this.maxParticles = 90});

  final int maxParticles;
  final particles = <Particle>[];
  final _rand = math.Random();
  double _spawnDebt = 0;

  /// Emits for one frame: [level] 0..1 loudness, [hueShift] 0..1 pitch.
  void emit(Offset from, double level, double pitchNorm, double dt, {bool calm = false}) {
    if (level <= 0) return;
    final rate = calm ? 3 + 8 * level : 5 + 22 * level; // particles per second
    _spawnDebt += rate * dt;
    while (_spawnDebt >= 1) {
      _spawnDebt -= 1;
      if (particles.length >= (calm ? maxParticles ~/ 2 : maxParticles)) break;
      final loud = level > 0.55;
      // Soft sounds: warm yellows. Louder: the whole rainbow, pitch-tinted.
      final hue = loud ? (pitchNorm * 300 + _rand.nextDouble() * 60) % 360 : 42 + _rand.nextDouble() * 18;
      final r = (loud ? 14 + 26 * level : 7 + 14 * level) * (0.8 + 0.4 * _rand.nextDouble());
      final angle = -math.pi / 2 + (_rand.nextDouble() - 0.5) * (calm ? 1.2 : 2.2);
      final speed = (calm ? 60 : 90) + 140 * level * _rand.nextDouble();
      particles.add(
        Particle(
          from + Offset((_rand.nextDouble() - 0.5) * 40, 0),
          Offset(math.cos(angle), math.sin(angle)) * speed,
          r,
          hue,
          !calm && loud && _rand.nextDouble() < 0.35,
          2.6 + _rand.nextDouble() * 1.6,
        ),
      );
    }
  }

  /// A gentle ring of bubbles for celebrations.
  void burst(Offset at, {int count = 24, bool calm = false}) {
    final n = calm ? count ~/ 2 : count;
    for (var i = 0; i < n; i++) {
      final a = i / n * math.pi * 2;
      final speed = (calm ? 70 : 120) + _rand.nextDouble() * 80;
      particles.add(
        Particle(
          at,
          Offset(math.cos(a), math.sin(a)) * speed,
          10 + _rand.nextDouble() * 14,
          _rand.nextDouble() * 360,
          !calm && i.isEven,
          2.2 + _rand.nextDouble(),
        ),
      );
    }
  }

  void step(double dt) {
    if (particles.isEmpty) return;
    for (final p in particles) {
      p.age += dt;
      p.life -= dt;
      p.vel = Offset(p.vel.dx * 0.985 + math.sin(p.age * 2.4 + p.wobble) * 6 * dt * 10, p.vel.dy * 0.99 - 8 * dt);
      p.pos += p.vel * dt;
    }
    particles.removeWhere((p) => p.life <= 0);
    notifyListeners();
  }
}

class ParticlePainter extends CustomPainter {
  ParticlePainter(this.field) : super(repaint: field);
  final ParticleField field;

  @override
  void paint(Canvas canvas, Size size) {
    for (final p in field.particles) {
      final fade = (p.life / 0.8).clamp(0.0, 1.0) * (p.age / 0.15).clamp(0.0, 1.0);
      final color = HSVColor.fromAHSV(1, p.hue % 360, 0.55, 1).toColor();
      if (p.star) {
        _star(canvas, p.pos, p.radius, color, fade, p.age);
      } else {
        _bubble(canvas, p.pos, p.radius, color, fade);
      }
    }
  }

  void _bubble(Canvas canvas, Offset c, double r, Color color, double a) {
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..shader = ui.Gradient.radial(
          c + Offset(-r * 0.3, -r * 0.3),
          r * 1.2,
          [
            Colors.white.withValues(alpha: 0.5 * a),
            color.withValues(alpha: 0.45 * a),
            color.withValues(alpha: 0.12 * a),
          ],
          [0, 0.5, 1],
        ),
    );
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(1.5, r * 0.08)
        ..color = color.withValues(alpha: 0.8 * a),
    );
    canvas.drawCircle(
      c + Offset(-r * 0.35, -r * 0.35),
      r * 0.18,
      Paint()..color = Colors.white.withValues(alpha: 0.7 * a),
    );
  }

  void _star(Canvas canvas, Offset c, double r, Color color, double a, double age) {
    canvas.drawCircle(
      c,
      r * 1.8,
      Paint()..shader = ui.Gradient.radial(c, r * 1.8, [color.withValues(alpha: 0.4 * a), color.withValues(alpha: 0)]),
    );
    final path = Path();
    for (var i = 0; i < 10; i++) {
      final ang = -math.pi / 2 + i * math.pi / 5 + age * 0.8;
      final rr = i.isEven ? r : r * 0.45;
      final pt = c + Offset(math.cos(ang), math.sin(ang)) * rr;
      i == 0 ? path.moveTo(pt.dx, pt.dy) : path.lineTo(pt.dx, pt.dy);
    }
    path.close();
    canvas.drawPath(path, Paint()..color = Color.lerp(color, Colors.white, 0.35)!.withValues(alpha: a));
  }

  @override
  bool shouldRepaint(ParticlePainter old) => false;
}

/// Echo Safari's target meter: a stem grows from a pot as the child holds
/// the sound, then the flower blooms (PDD Screen 4).
class FlowerPainter extends CustomPainter {
  FlowerPainter({required this.progress, required this.bloom, required this.color, this.sway = 0});

  /// 0..1 stem growth.
  final double progress;

  /// 0..1 petals opening after completion.
  final double bloom;
  final Color color;

  /// -1..1 gentle sway.
  final double sway;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final base = Offset(w / 2, h * 0.9);

    // Pot.
    final pot = Path()
      ..moveTo(base.dx - w * 0.2, base.dy - h * 0.08)
      ..lineTo(base.dx + w * 0.2, base.dy - h * 0.08)
      ..lineTo(base.dx + w * 0.15, base.dy + h * 0.08)
      ..lineTo(base.dx - w * 0.15, base.dy + h * 0.08)
      ..close();
    canvas.drawPath(pot, Paint()..color = const Color(0xFFD9825B));
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: base + Offset(0, -h * 0.085), width: w * 0.46, height: h * 0.05),
        const Radius.circular(8),
      ),
      Paint()..color = const Color(0xFFE99A74),
    );

    final stemTop = base + Offset(sway * w * 0.05 * progress, -h * 0.08 - h * 0.62 * progress);
    final stem = Path()
      ..moveTo(base.dx, base.dy - h * 0.1)
      ..quadraticBezierTo(base.dx - w * 0.08 + sway * w * 0.03, (base.dy + stemTop.dy) / 2, stemTop.dx, stemTop.dy);
    canvas.drawPath(
      stem,
      Paint()
        ..color = const Color(0xFF5CC46F)
        ..style = PaintingStyle.stroke
        ..strokeWidth = w * 0.045
        ..strokeCap = StrokeCap.round,
    );

    // Leaves appear as the stem passes them.
    for (final (at, side) in [(0.35, -1.0), (0.6, 1.0)]) {
      if (progress < at) continue;
      final grow = ((progress - at) / 0.15).clamp(0.0, 1.0);
      final y = base.dy - h * 0.1 - h * 0.62 * at * 0.95;
      canvas.save();
      canvas.translate(base.dx + side * w * 0.02 - w * 0.04 * (1 - at), y);
      canvas.rotate(side * 0.7);
      canvas.drawOval(
        Rect.fromCenter(center: Offset(side * w * 0.09 * grow, 0), width: w * 0.2 * grow, height: w * 0.09 * grow),
        Paint()..color = const Color(0xFF7ED68A),
      );
      canvas.restore();
    }

    // Bud, then petals.
    if (progress > 0.05) {
      final petals = 7;
      final open = bloom;
      final pr = w * (0.05 + 0.13 * open);
      for (var i = 0; i < petals; i++) {
        final a = i / petals * math.pi * 2 + sway * 0.1;
        final pc = stemTop + Offset(math.cos(a), math.sin(a)) * pr * 0.9 * open;
        canvas.drawOval(
          Rect.fromCenter(center: pc, width: pr * (0.9 + 0.5 * open), height: pr * (0.9 + 0.5 * open)),
          Paint()..color = Color.lerp(color, Colors.white, 0.1 * (i % 2))!.withValues(alpha: 0.35 + 0.65 * open),
        );
      }
      canvas.drawCircle(stemTop, w * (0.045 + 0.04 * open), Paint()..color = ES.sunshine);
    }
  }

  @override
  bool shouldRepaint(FlowerPainter old) =>
      old.progress != progress || old.bloom != bloom || old.color != color || old.sway != sway;
}

/// Calm night-sky backdrop with a few softly twinkling dots.
class Backdrop extends StatefulWidget {
  const Backdrop({
    super.key,
    required this.child,
    this.calm = false,
    this.top = ES.canvas,
    this.bottom = ES.canvasDeep,
  });
  final Widget child;
  final bool calm;
  final Color top, bottom;

  @override
  State<Backdrop> createState() => _BackdropState();
}

class _BackdropState extends State<Backdrop> with SingleTickerProviderStateMixin {
  late final AnimationController _t = AnimationController(vsync: this, duration: const Duration(seconds: 8));

  @override
  void initState() {
    super.initState();
    if (!widget.calm) _t.repeat();
  }

  @override
  void dispose() {
    _t.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [widget.top, widget.bottom],
        ),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          IgnorePointer(
            child: RepaintBoundary(child: CustomPaint(painter: _StarsPainter(_t))),
          ),
          widget.child,
        ],
      ),
    );
  }
}

class _StarsPainter extends CustomPainter {
  _StarsPainter(this.t) : super(repaint: t);
  final Animation<double> t;

  @override
  void paint(Canvas canvas, Size size) {
    final r = math.Random(7);
    for (var i = 0; i < 38; i++) {
      final p = Offset(r.nextDouble() * size.width, r.nextDouble() * size.height * 0.85);
      final phase = r.nextDouble() * math.pi * 2;
      final a = 0.18 + 0.22 * (0.5 + 0.5 * math.sin(t.value * math.pi * 2 + phase));
      canvas.drawCircle(p, 1 + r.nextDouble() * 1.8, Paint()..color = Colors.white.withValues(alpha: a));
    }
  }

  @override
  bool shouldRepaint(_StarsPainter old) => false;
}
