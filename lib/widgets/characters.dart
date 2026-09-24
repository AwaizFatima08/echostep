import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../core/content.dart';
import '../core/theme.dart';

/// Characters are drawn in code rather than shipped as animations, so they
/// react to the child's voice in real time: Milo's mouth opens with
/// loudness and his glow follows it; Pip's beak models the target mouth
/// shape.

/// Milo the Bear. Everything is relative to the square canvas side.
class MiloPainter extends CustomPainter {
  MiloPainter({this.awake = 1, this.mouth = 0, this.glow = 0, this.blink = 0, this.glowColor = ES.sunshine});

  /// 0 asleep (eyes closed) .. 1 wide awake.
  final double awake;

  /// 0 closed smile .. 1 wide open.
  final double mouth;

  /// 0..1 halo behind the head.
  final double glow;

  /// 0..1 eyelid closing for a blink (only when awake).
  final double blink;
  final Color glowColor;

  static const _fur = Color(0xFFC8946A);
  static const _furDark = Color(0xFFA9754F);
  static const _furLight = Color(0xFFDDB08A);
  static const _muzzle = Color(0xFFF4DCC2);
  static const _ink = Color(0xFF3B2A2A);

  @override
  void paint(Canvas canvas, Size size) {
    final s = math.min(size.width, size.height);
    final c = Offset(size.width / 2, size.height / 2 + s * 0.04);

    if (glow > 0.01) {
      final r = s * (0.42 + 0.1 * glow);
      canvas.drawCircle(
        c,
        r,
        Paint()
          ..shader = ui.Gradient.radial(
            c,
            r,
            [
              glowColor.withValues(alpha: 0.55 * glow),
              glowColor.withValues(alpha: 0.18 * glow),
              glowColor.withValues(alpha: 0),
            ],
            [0, 0.6, 1],
          ),
      );
    }

    // Ears.
    for (final dx in [-1.0, 1.0]) {
      final e = c + Offset(dx * s * 0.25, -s * 0.25);
      canvas.drawCircle(e, s * 0.105, Paint()..color = _furDark);
      canvas.drawCircle(e + Offset(-dx * s * 0.008, s * 0.008), s * 0.06, Paint()..color = const Color(0xFFF2C6A0));
    }

    // Head with a soft top light.
    final head = Rect.fromCircle(center: c, radius: s * 0.32);
    canvas.drawOval(
      head,
      Paint()
        ..shader = ui.Gradient.radial(
          c + Offset(-s * 0.08, -s * 0.12),
          s * 0.4,
          [_furLight, _fur, _furDark],
          [0, 0.6, 1],
        ),
    );

    // Cheeks.
    for (final dx in [-1.0, 1.0]) {
      canvas.drawCircle(
        c + Offset(dx * s * 0.2, s * 0.07),
        s * 0.048,
        Paint()..color = const Color(0xFFFF8A8A).withValues(alpha: 0.35 + 0.25 * awake),
      );
    }

    // Muzzle.
    final mz = c + Offset(0, s * 0.1);
    canvas.drawOval(Rect.fromCenter(center: mz, width: s * 0.3, height: s * 0.22), Paint()..color = _muzzle);

    // Mouth.
    final mc = mz + Offset(0, s * 0.045);
    if (mouth < 0.06) {
      final p = Paint()
        ..color = _ink
        ..style = PaintingStyle.stroke
        ..strokeWidth = s * 0.014
        ..strokeCap = StrokeCap.round;
      final path = Path()
        ..moveTo(mc.dx - s * 0.055, mc.dy - s * 0.004)
        ..quadraticBezierTo(mc.dx - s * 0.028, mc.dy + s * 0.03, mc.dx, mc.dy)
        ..quadraticBezierTo(mc.dx + s * 0.028, mc.dy + s * 0.03, mc.dx + s * 0.055, mc.dy - s * 0.004);
      canvas.drawPath(path, p);
    } else {
      final w = s * (0.07 + 0.05 * mouth);
      final h = s * (0.03 + 0.085 * mouth);
      final r = Rect.fromCenter(center: mc + Offset(0, h * 0.35), width: w, height: h);
      canvas.drawOval(r, Paint()..color = const Color(0xFF7A2E3A));
      canvas.save();
      canvas.clipPath(Path()..addOval(r));
      canvas.drawOval(
        Rect.fromCenter(center: Offset(r.center.dx, r.bottom), width: w * 0.8, height: h * 0.7),
        Paint()..color = const Color(0xFFFF8FA3),
      );
      canvas.restore();
    }

    // Nose.
    final nose = Rect.fromCenter(center: mz + Offset(0, -s * 0.035), width: s * 0.095, height: s * 0.065);
    canvas.drawRRect(RRect.fromRectAndRadius(nose, Radius.circular(s * 0.035)), Paint()..color = _ink);
    canvas.drawCircle(
      nose.center + Offset(-s * 0.018, -s * 0.012),
      s * 0.011,
      Paint()..color = Colors.white.withValues(alpha: 0.6),
    );

    // Eyes: closed arcs while asleep, round shiny eyes when awake.
    final open = (awake * (1 - blink)).clamp(0.0, 1.0);
    for (final dx in [-1.0, 1.0]) {
      final e = c + Offset(dx * s * 0.115, -s * 0.055);
      if (open < 0.25) {
        final p = Paint()
          ..color = _ink
          ..style = PaintingStyle.stroke
          ..strokeWidth = s * 0.016
          ..strokeCap = StrokeCap.round;
        canvas.drawArc(Rect.fromCenter(center: e, width: s * 0.08, height: s * 0.05), 0.2, math.pi - 0.4, false, p);
      } else {
        final h = s * 0.09 * open;
        canvas.drawOval(Rect.fromCenter(center: e, width: s * 0.078, height: h), Paint()..color = _ink);
        if (open > 0.6) {
          canvas.drawCircle(e + Offset(-s * 0.014, -s * 0.016), s * 0.014, Paint()..color = Colors.white);
        }
      }
    }
  }

  @override
  bool shouldRepaint(MiloPainter old) =>
      old.awake != awake || old.mouth != mouth || old.glow != glow || old.blink != blink || old.glowColor != glowColor;
}

/// Pip the Bird. [beak] models a mouth shape; [flap] is -1..1 wing angle.
class PipPainter extends CustomPainter {
  PipPainter({this.beakOpen = 0.1, this.beakWidth = 0.5, this.flap = 0, this.happy = false, this.glow = 0});

  final double beakOpen;
  final double beakWidth;
  final double flap;
  final bool happy;
  final double glow;

  static const _body = Color(0xFF4ECDC4);
  static const _bodyDark = Color(0xFF2FA89F);
  static const _belly = Color(0xFFCFF7F2);
  static const _beak = Color(0xFFFFB347);
  static const _ink = Color(0xFF22303A);

  @override
  void paint(Canvas canvas, Size size) {
    final s = math.min(size.width, size.height);
    final c = Offset(size.width / 2, size.height / 2 + s * 0.02);

    if (glow > 0.01) {
      final r = s * 0.48;
      canvas.drawCircle(
        c,
        r,
        Paint()
          ..shader = ui.Gradient.radial(c, r, [
            ES.sunshine.withValues(alpha: 0.5 * glow),
            ES.sunshine.withValues(alpha: 0),
          ]),
      );
    }

    // Feet.
    final foot = Paint()
      ..color = _beak
      ..strokeWidth = s * 0.022
      ..strokeCap = StrokeCap.round;
    for (final dx in [-1.0, 1.0]) {
      final f = c + Offset(dx * s * 0.09, s * 0.3);
      canvas.drawLine(f, f + Offset(0, s * 0.06), foot);
      canvas.drawLine(f + Offset(0, s * 0.06), f + Offset(dx * s * 0.035, s * 0.075), foot);
    }

    // Wings behind the body.
    for (final dx in [-1.0, 1.0]) {
      canvas.save();
      final pivot = c + Offset(dx * s * 0.26, s * 0.02);
      canvas.translate(pivot.dx, pivot.dy);
      canvas.rotate(dx * (0.35 + 0.45 * flap));
      canvas.drawOval(
        Rect.fromCenter(center: Offset(dx * s * 0.07, s * 0.04), width: s * 0.2, height: s * 0.3),
        Paint()..color = _bodyDark,
      );
      canvas.restore();
    }

    // Tuft.
    final tuft = Paint()..color = ES.coral;
    for (var i = -1; i <= 1; i++) {
      canvas.save();
      canvas.translate(c.dx, c.dy - s * 0.3);
      canvas.rotate(i * 0.45);
      canvas.drawOval(Rect.fromCenter(center: Offset(0, -s * 0.06), width: s * 0.06, height: s * 0.14), tuft);
      canvas.restore();
    }

    // Body.
    final body = Rect.fromCircle(center: c, radius: s * 0.32);
    canvas.drawOval(
      body,
      Paint()
        ..shader = ui.Gradient.radial(
          c + Offset(-s * 0.1, -s * 0.12),
          s * 0.42,
          [const Color(0xFF7FE3DB), _body, _bodyDark],
          [0, 0.55, 1],
        ),
    );
    canvas.drawOval(
      Rect.fromCenter(center: c + Offset(0, s * 0.14), width: s * 0.36, height: s * 0.3),
      Paint()..color = _belly,
    );

    // Cheeks.
    for (final dx in [-1.0, 1.0]) {
      canvas.drawCircle(
        c + Offset(dx * s * 0.19, s * 0.02),
        s * 0.042,
        Paint()..color = const Color(0xFFFF8FA3).withValues(alpha: 0.55),
      );
    }

    // Eyes.
    for (final dx in [-1.0, 1.0]) {
      final e = c + Offset(dx * s * 0.11, -s * 0.09);
      if (happy) {
        final p = Paint()
          ..color = _ink
          ..style = PaintingStyle.stroke
          ..strokeWidth = s * 0.018
          ..strokeCap = StrokeCap.round;
        canvas.drawArc(
          Rect.fromCenter(center: e + Offset(0, s * 0.012), width: s * 0.08, height: s * 0.07),
          math.pi + 0.3,
          math.pi - 0.6,
          false,
          p,
        );
      } else {
        canvas.drawCircle(e, s * 0.045, Paint()..color = _ink);
        canvas.drawCircle(e + Offset(-s * 0.014, -s * 0.016), s * 0.015, Paint()..color = Colors.white);
      }
    }

    // Beak: width follows the mouth shape; the lower half drops as it opens.
    final bc = c + Offset(0, s * 0.02);
    final bw = s * (0.06 + 0.06 * beakWidth);
    final drop = s * 0.13 * beakOpen;
    if (beakOpen > 0.05) {
      canvas.drawOval(
        Rect.fromCenter(center: bc + Offset(0, drop * 0.55), width: bw * 1.5, height: drop * 1.2 + s * 0.02),
        Paint()..color = const Color(0xFF7A2E3A),
      );
    }
    final upper = Path()
      ..moveTo(bc.dx - bw, bc.dy)
      ..quadraticBezierTo(bc.dx, bc.dy - s * 0.07, bc.dx + bw, bc.dy)
      ..quadraticBezierTo(bc.dx, bc.dy + s * 0.05, bc.dx - bw, bc.dy)
      ..close();
    canvas.drawPath(upper, Paint()..color = _beak);
    final lowerTop = bc.dy + drop;
    final lower = Path()
      ..moveTo(bc.dx - bw * 0.85, lowerTop)
      ..quadraticBezierTo(bc.dx, lowerTop + s * 0.06, bc.dx + bw * 0.85, lowerTop)
      ..quadraticBezierTo(bc.dx, lowerTop - s * 0.015, bc.dx - bw * 0.85, lowerTop)
      ..close();
    canvas.drawPath(lower, Paint()..color = const Color(0xFFF29A2E));
  }

  @override
  bool shouldRepaint(PipPainter old) =>
      old.beakOpen != beakOpen ||
      old.beakWidth != beakWidth ||
      old.flap != flap ||
      old.happy != happy ||
      old.glow != glow;
}

/// A front view of lips: the visual cue card speech therapists use to show
/// a mouth shape.
class MouthPainter extends CustomPainter {
  MouthPainter({required this.open, required this.width, this.teeth = false, this.highlight = 0});

  /// 0 closed .. 1 wide open.
  final double open;

  /// 0 puckered .. 1 wide smile.
  final double width;
  final bool teeth;

  /// 0..1 glow when the child's sound matches.
  final double highlight;

  static const _lip = Color(0xFFE8697D);
  static const _lipDark = Color(0xFFC24C62);
  static const _inside = Color(0xFF4A1824);
  static const _skin = Color(0xFFF6D3B8);

  @override
  void paint(Canvas canvas, Size size) {
    final s = math.min(size.width, size.height);
    final c = Offset(size.width / 2, size.height / 2);

    // Skin disc as a neutral face patch.
    canvas.drawCircle(c, s * 0.46, Paint()..color = _skin);
    if (highlight > 0.01) {
      canvas.drawCircle(
        c,
        s * 0.46,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = s * 0.035
          ..color = ES.sunshine.withValues(alpha: highlight),
      );
    }

    final w = s * (0.2 + 0.5 * width);
    final innerH = s * 0.42 * open;
    final lip = s * (0.085 - 0.03 * width);

    // Outer lips: a rounded shape around the opening.
    final outer = Rect.fromCenter(center: c, width: w + lip * 2, height: innerH + lip * 2.4);
    canvas.drawRRect(
      RRect.fromRectAndRadius(outer, Radius.elliptical(outer.width / 2, outer.height / 2)),
      Paint()..shader = ui.Gradient.linear(outer.topCenter, outer.bottomCenter, [_lip, _lipDark]),
    );

    if (open < 0.04) {
      // Closed lips: a seam line.
      canvas.drawLine(
        c + Offset(-w / 2, 0),
        c + Offset(w / 2, 0),
        Paint()
          ..color = _inside
          ..strokeWidth = s * 0.018
          ..strokeCap = StrokeCap.round,
      );
      return;
    }

    final inner = Rect.fromCenter(center: c, width: w, height: innerH);
    final innerR = RRect.fromRectAndRadius(inner, Radius.elliptical(inner.width / 2, inner.height / 2));
    canvas.drawRRect(innerR, Paint()..color = _inside);
    canvas.save();
    canvas.clipRRect(innerR);
    if (teeth) {
      canvas.drawRect(
        Rect.fromLTWH(inner.left, inner.top, inner.width, inner.height * 0.42),
        Paint()..color = Colors.white,
      );
      canvas.drawRect(
        Rect.fromLTWH(inner.left, inner.bottom - inner.height * 0.3, inner.width, inner.height * 0.3),
        Paint()..color = const Color(0xFFF2F2F2),
      );
    } else if (open > 0.5) {
      canvas.drawRect(
        Rect.fromLTWH(inner.left, inner.top, inner.width, inner.height * 0.14),
        Paint()..color = Colors.white,
      );
    }
    if (!teeth) {
      canvas.drawOval(
        Rect.fromCenter(center: Offset(c.dx, inner.bottom), width: inner.width * 0.75, height: inner.height * 0.6),
        Paint()..color = const Color(0xFFFF8FA3),
      );
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(MouthPainter old) =>
      old.open != open || old.width != width || old.teeth != teeth || old.highlight != highlight;
}

/// Convenience widgets.
class Milo extends StatelessWidget {
  const Milo({super.key, this.size = 200, this.awake = 1, this.mouth = 0, this.glow = 0, this.blink = 0});
  final double size, awake, mouth, glow, blink;

  @override
  Widget build(BuildContext context) => SizedBox.square(
    dimension: size,
    child: CustomPaint(
      painter: MiloPainter(awake: awake, mouth: mouth, glow: glow, blink: blink),
    ),
  );
}

class Pip extends StatelessWidget {
  const Pip({
    super.key,
    this.size = 200,
    this.shape = MouthShape.closed,
    this.flap = 0,
    this.happy = false,
    this.glow = 0,
  });
  final double size, flap, glow;
  final MouthShape shape;
  final bool happy;

  @override
  Widget build(BuildContext context) => SizedBox.square(
    dimension: size,
    child: CustomPaint(
      painter: PipPainter(beakOpen: shape.open, beakWidth: shape.width, flap: flap, happy: happy, glow: glow),
    ),
  );
}

/// The child's chosen buddy as a static portrait.
class BuddyFace extends StatelessWidget {
  const BuddyFace({super.key, required this.pip, this.size = 64});
  final bool pip;
  final double size;

  @override
  Widget build(BuildContext context) => pip ? Pip(size: size, shape: MouthShape.closed, happy: true) : Milo(size: size);
}
