import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/content.dart';
import '../../core/theme.dart';
import '../../services/services.dart';
import '../../widgets/characters.dart';
import '../../widgets/effects.dart';
import '../../widgets/kid_widgets.dart';
import 'safari_stop_view.dart';

/// The Echo Safari route: eight sound stops along a winding path. Every stop
/// is open; the next suggested one gently pulses.
class SafariMapView extends StatefulWidget {
  const SafariMapView({super.key});

  @override
  State<SafariMapView> createState() => _SafariMapViewState();
}

class _SafariMapViewState extends State<SafariMapView> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) Services.of(context).speech.prompt('Pick a sound!');
    });
  }

  Future<void> _open(SoundTarget t) async {
    final s = Services.of(context);
    await s.speech.hush();
    if (!mounted) return;
    var current = t;
    // A stop can hand over to the next one ("next sound" button).
    while (mounted) {
      final next = await Navigator.of(context).push<SoundTarget>(fadeRoute(SafariStopView(target: current)));
      if (next == null) break;
      current = next;
    }
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final s = Services.of(context);
    final c = s.store.active!;
    final suggested = c.suggestedTarget;
    return Scaffold(
      body: Backdrop(
        calm: c.settings.calmMode,
        top: const Color(0xFF16263A),
        bottom: ES.canvasDeep,
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 8, 16, 0),
                child: Row(
                  children: [
                    const KidBackButton(),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        'Echo Safari',
                        style: TextStyle(fontSize: 30, fontWeight: FontWeight.w700, color: ES.turquoise),
                      ),
                    ),
                    Bob(child: Pip(size: 70, shape: suggested.releaseMouth ?? suggested.mouth, happy: true)),
                  ],
                ),
              ),
              Expanded(
                child: LayoutBuilder(
                  builder: (context, box) {
                    const rowH = 132.0;
                    final w = box.maxWidth;
                    final points = [
                      for (var i = 0; i < targets.length; i++)
                        Offset(w * (0.5 + 0.28 * math.sin(i * 1.15)), 70 + i * rowH),
                    ];
                    return SingleChildScrollView(
                      padding: const EdgeInsets.only(bottom: 24),
                      child: SizedBox(
                        height: 70 + targets.length * rowH,
                        child: Stack(
                          children: [
                            Positioned.fill(child: CustomPaint(painter: _PathPainter(points))),
                            for (var i = 0; i < targets.length; i++)
                              Positioned(
                                left: points[i].dx - 52,
                                top: points[i].dy - 52,
                                child: _Stop(
                                  target: targets[i],
                                  completions: c.practised[targets[i].id] ?? 0,
                                  suggested: targets[i].id == suggested.id,
                                  onTap: () => _open(targets[i]),
                                ),
                              ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Stop extends StatelessWidget {
  const _Stop({required this.target, required this.completions, required this.suggested, required this.onTap});
  final SoundTarget target;
  final int completions;
  final bool suggested;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final shape = target.releaseMouth ?? target.mouth;
    return Pulse(
      enabled: suggested,
      amount: 0.07,
      child: BouncyButton(
        label: 'Say ${target.label}',
        onTap: onTap,
        child: SizedBox(
          key: ValueKey('stop-${target.id}'),
          width: 104,
          height: 118,
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.topCenter,
            children: [
              Container(
                width: 104,
                height: 104,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: ES.card,
                  border: Border.all(color: target.color, width: suggested ? 6 : 4),
                  boxShadow: [
                    BoxShadow(
                      color: target.color.withValues(alpha: suggested ? 0.6 : 0.25),
                      blurRadius: suggested ? 24 : 10,
                    ),
                  ],
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox.square(
                      dimension: 46,
                      child: CustomPaint(
                        painter: MouthPainter(open: shape.open, width: shape.width, teeth: shape.teeth),
                      ),
                    ),
                    Text(
                      target.label,
                      style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: target.color, height: 1.1),
                    ),
                  ],
                ),
              ),
              if (completions > 0)
                Positioned(
                  bottom: 0,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(color: ES.canvasDeep, borderRadius: BorderRadius.circular(12)),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        for (var i = 0; i < math.min(completions, 3); i++)
                          const Icon(Icons.local_florist_rounded, size: 18, color: ES.sunshine),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PathPainter extends CustomPainter {
  _PathPainter(this.points);
  final List<Offset> points;

  @override
  void paint(Canvas canvas, Size size) {
    if (points.length < 2) return;
    final path = Path()..moveTo(points.first.dx, points.first.dy);
    for (var i = 1; i < points.length; i++) {
      final a = points[i - 1], b = points[i];
      path.cubicTo(a.dx, (a.dy + b.dy) / 2, b.dx, (a.dy + b.dy) / 2, b.dx, b.dy);
    }
    final dash = Paint()
      ..color = ES.cardLine
      ..style = PaintingStyle.stroke
      ..strokeWidth = 10
      ..strokeCap = StrokeCap.round;
    for (final m in path.computeMetrics()) {
      for (var d = 0.0; d < m.length; d += 30) {
        canvas.drawPath(m.extractPath(d, math.min(d + 14, m.length)), dash);
      }
    }
  }

  @override
  bool shouldRepaint(_PathPainter old) => old.points != points;
}
