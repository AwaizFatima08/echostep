import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/content.dart';
import '../core/theme.dart';
import '../models/child.dart';

/// Numbers that shape the Vocal Growth Tree.
class TreeStats {
  const TreeStats({
    required this.vocalizations,
    required this.minutes,
    required this.activeDays,
    required this.practised,
    required this.mastered,
  });

  factory TreeStats.of(ChildProfile c) {
    final days = <String>{};
    for (final s in c.sessions) {
      days.add('${s.start.year}-${s.start.month}-${s.start.day}');
    }
    return TreeStats(
      vocalizations: c.totalVocalizations,
      minutes: c.totalSeconds / 60,
      activeDays: days.length,
      practised: [
        for (final t in targets)
          if ((c.practised[t.id] ?? 0) > 0) t,
      ],
      mastered: [
        for (final t in targets)
          if (c.mastered.contains(t.id)) t,
      ],
    );
  }

  final int vocalizations;
  final double minutes;
  final int activeDays;
  final List<SoundTarget> practised;
  final List<SoundTarget> mastered;

  /// Branching depth: mostly from days of practice (consistency grows the
  /// canopy), with a head start on the first day so it never looks bare.
  int get depth => switch (activeDays) {
    0 => 0,
    1 => 2,
    2 || 3 => 3,
    < 10 => 4,
    _ => 5,
  };

  /// 0..1 trunk height from minutes played (log scale, ~5 hours for full).
  double get growth => (math.log(1 + minutes) / math.log(1 + 300)).clamp(0.0, 1.0);

  /// 0..1 root spread from vocalizations (log scale, ~2000 for full).
  double get rootSpread => (math.log(1 + vocalizations) / math.log(1 + 2000)).clamp(0.0, 1.0);
}

/// The parent's "Vocal Growth Tree": grows with practice, never shrinks.
class GrowthTreePainter extends CustomPainter {
  GrowthTreePainter(this.stats, {this.seed = 1});
  final TreeStats stats;
  final int seed;

  static const _bark = Color(0xFF8B5E3C);
  static const _barkLight = Color(0xFFA9784F);
  static const _leaf = Color(0xFF6FD08C);
  static const _leafDark = Color(0xFF3FAE6A);

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final ground = h * 0.78;
    final rand = math.Random(seed);

    // Roots (under the ground line): more vocalizations, more roots.
    final rootPaint = Paint()
      ..color = _bark.withValues(alpha: 0.7)
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    final roots = 2 + (stats.rootSpread * 9).round();
    for (var i = 0; i < roots; i++) {
      final t = roots == 1 ? 0.5 : i / (roots - 1);
      final dx = (t - 0.5) * w * (0.2 + 0.55 * stats.rootSpread);
      final dy = h * (0.08 + 0.1 * stats.rootSpread * (1 - (t - 0.5).abs()));
      rootPaint.strokeWidth = 2.5 + 3 * (1 - (t - 0.5).abs() * 2);
      canvas.drawPath(
        Path()
          ..moveTo(w / 2, ground)
          ..quadraticBezierTo(w / 2 + dx * 0.3, ground + dy * 0.9, w / 2 + dx, ground + dy),
        rootPaint,
      );
    }

    // Soil.
    canvas.drawOval(
      Rect.fromCenter(center: Offset(w / 2, ground), width: w * 0.7, height: h * 0.06),
      Paint()..color = const Color(0xFF5A3E2B),
    );

    // Trunk.
    final trunkH = h * (0.1 + 0.2 * stats.growth);
    final trunkW = w * (0.022 + 0.03 * stats.growth);
    final top = Offset(w / 2, ground - trunkH);
    canvas.drawPath(
      Path()
        ..moveTo(w / 2 - trunkW, ground)
        ..quadraticBezierTo(w / 2 - trunkW * 0.6, ground - trunkH * 0.5, top.dx - trunkW * 0.45, top.dy)
        ..lineTo(top.dx + trunkW * 0.45, top.dy)
        ..quadraticBezierTo(w / 2 + trunkW * 0.6, ground - trunkH * 0.5, w / 2 + trunkW, ground)
        ..close(),
      Paint()..color = _bark,
    );

    // Branches fork right at the trunk top. Their length is sized so the
    // whole canopy fits the space above, however deep it gets.
    final tips = <Offset>[];
    final branchPaint = Paint()
      ..color = _barkLight
      ..strokeCap = StrokeCap.round;
    const shrink = 0.72;
    void branch(Offset from, double angle, double len, double width, int depth) {
      final to = from + Offset(math.sin(angle), -math.cos(angle)) * len;
      branchPaint.strokeWidth = width;
      canvas.drawLine(from, to, branchPaint);
      if (depth <= 1) {
        tips.add(to);
        return;
      }
      final spread = 0.38 + rand.nextDouble() * 0.18;
      branch(to, angle - spread, len * shrink, width * 0.7, depth - 1);
      branch(to, angle + spread, len * shrink, width * 0.7, depth - 1);
    }

    final depth = stats.depth;
    if (depth == 0) {
      tips.add(top);
    } else {
      var reach = 0.0;
      for (var k = 0; k < depth; k++) {
        reach += math.pow(shrink, k) * 0.85; // branches lean, so less than full height
      }
      final len = math.min((top.dy - h * 0.17) / reach, h * 0.2);
      final width = trunkW * 0.9;
      for (final a in [-0.45, 0.45]) {
        branch(top, a + (rand.nextDouble() - 0.5) * 0.1, len, width, depth);
      }
      if (depth >= 3) branch(top, (rand.nextDouble() - 0.5) * 0.15, len * 0.9, width * 0.9, depth - 1);
    }

    // Leaves: clusters at the tips, fuller with more vocalizations.
    final perTip = (2 + stats.vocalizations / (8 * tips.length)).clamp(2, 6).round();
    for (final tip in tips) {
      for (var k = 0; k < perTip; k++) {
        final a = rand.nextDouble() * math.pi * 2;
        final r = w * 0.018 * k;
        final p = tip + Offset(math.cos(a), math.sin(a)) * r;
        final lw = w * (0.035 + 0.02 * rand.nextDouble());
        canvas.save();
        canvas.translate(p.dx, p.dy);
        canvas.rotate(a);
        canvas.drawOval(
          Rect.fromCenter(center: Offset.zero, width: lw, height: lw * 0.6),
          Paint()..color = rand.nextBool() ? _leaf : _leafDark,
        );
        canvas.restore();
      }
    }

    // Flowers for practised sounds, stars for mastered ones.
    final order = List<int>.generate(tips.length, (i) => i)..shuffle(math.Random(seed + 1));
    for (var i = 0; i < stats.practised.length; i++) {
      // More flowers than tips: ring the extra ones around the tip.
      final ring = i ~/ tips.length;
      final a = ring * 2.1;
      final tip = tips[order[i % tips.length]] + Offset(math.cos(a), math.sin(a)) * (w * 0.035 * ring);
      _flower(canvas, tip, w * 0.028, stats.practised[i].color);
    }
    for (var i = 0; i < stats.mastered.length; i++) {
      final tip = tips[order[(i + stats.practised.length) % tips.length]];
      _star(canvas, tip + Offset(0, -w * 0.05), w * 0.03);
    }
  }

  void _flower(Canvas canvas, Offset c, double r, Color color) {
    for (var i = 0; i < 5; i++) {
      final a = i / 5 * math.pi * 2;
      canvas.drawCircle(c + Offset(math.cos(a), math.sin(a)) * r * 0.7, r * 0.6, Paint()..color = color);
    }
    canvas.drawCircle(c, r * 0.45, Paint()..color = ES.sunshine);
  }

  void _star(Canvas canvas, Offset c, double r) {
    final path = Path();
    for (var i = 0; i < 10; i++) {
      final a = -math.pi / 2 + i * math.pi / 5;
      final rr = i.isEven ? r : r * 0.45;
      final p = c + Offset(math.cos(a), math.sin(a)) * rr;
      i == 0 ? path.moveTo(p.dx, p.dy) : path.lineTo(p.dx, p.dy);
    }
    canvas.drawPath(path..close(), Paint()..color = ES.sunshine);
  }

  @override
  bool shouldRepaint(GrowthTreePainter old) => true;
}
