// Renders EchoSteps' launcher icons and Play Store graphics from the same
// code-drawn characters the app uses (no image generator needed).
//
//   flutter test tool/make_graphics_test.dart
//
// Writes:
//   android/app/src/main/res/drawable-*/ic_launcher_foreground.png  adaptive icon layer
//   android/app/src/main/res/drawable-*/ic_launcher_monochrome.png  themed (Android 13+) layer
//   android/app/src/main/res/mipmap-*/ic_launcher.png               legacy icons
//   store-assets/icon-512.png                                       Play icon
//   store-assets/feature-graphic-1024x500.png                       Play feature graphic
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:echosteps/core/content.dart';
import 'package:echosteps/core/theme.dart';
import 'package:echosteps/widgets/characters.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

const res = 'android/app/src/main/res';

Future<void> save(String path, int w, int h, void Function(Canvas c, Size s) draw) async {
  final rec = ui.PictureRecorder();
  draw(Canvas(rec), Size(w.toDouble(), h.toDouble()));
  final img = await rec.endRecording().toImage(w, h);
  final png = await img.toByteData(format: ui.ImageByteFormat.png);
  File(path)
    ..parent.createSync(recursive: true)
    ..writeAsBytesSync(png!.buffer.asUint8List());
}

void background(Canvas c, Size s) {
  final center = Offset(s.width * 0.5, s.height * 0.45);
  c.drawRect(
    Offset.zero & s,
    Paint()
      ..shader = ui.Gradient.radial(
        center,
        s.longestSide * 0.75,
        [const Color(0xFF34345E), ES.canvas, ES.canvasDeep],
        [0, 0.55, 1],
      ),
  );
}

/// A few soft bubbles, positioned relative to [box].
void bubbles(Canvas c, Rect box, {double scale = 1}) {
  final spots = [
    (0.80, 0.22, 0.060, ES.turquoise),
    (0.88, 0.40, 0.040, ES.sunshine),
    (0.14, 0.26, 0.048, ES.coral),
    (0.20, 0.12, 0.030, ES.lilac),
    (0.72, 0.08, 0.034, ES.mint),
  ];
  for (final (x, y, r, color) in spots) {
    final p = Offset(box.left + box.width * x, box.top + box.height * y);
    final rr = box.width * r * scale;
    c.drawCircle(
      p,
      rr,
      Paint()
        ..shader = ui.Gradient.radial(
          p + Offset(-rr * 0.3, -rr * 0.3),
          rr * 1.2,
          [Colors.white.withValues(alpha: 0.55), color.withValues(alpha: 0.55), color.withValues(alpha: 0.15)],
          [0, 0.5, 1],
        ),
    );
    c.drawCircle(
      p,
      rr,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = rr * 0.12
        ..color = color,
    );
    c.drawCircle(p + Offset(-rr * 0.35, -rr * 0.35), rr * 0.2, Paint()..color = Colors.white.withValues(alpha: 0.8));
  }
}

void milo(Canvas c, Rect box, {double mouth = 0.55}) {
  c.save();
  c.translate(box.left, box.top);
  MiloPainter(awake: 1, mouth: mouth, glow: 0.85).paint(c, box.size);
  c.restore();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    final loader = FontLoader('Andika')
      ..addFont(rootBundle.load('assets/fonts/Andika-Regular.ttf'))
      ..addFont(rootBundle.load('assets/fonts/Andika-Bold.ttf'));
    await loader.load();
  });

  test('launcher icons', () async {
    // Adaptive icon foreground: 108 dp canvas, content inside the 66 dp safe
    // zone (the launcher masks to a circle or squircle).
    const fg = {'mdpi': 108, 'hdpi': 162, 'xhdpi': 216, 'xxhdpi': 324, 'xxxhdpi': 432};
    for (final e in fg.entries) {
      final n = e.value;
      await save('$res/drawable-${e.key}/ic_launcher_foreground.png', n, n, (c, s) {
        final box = Rect.fromCenter(center: s.center(Offset.zero), width: s.width * 0.62, height: s.height * 0.62);
        milo(c, box, mouth: 0.5);
      });
      // Themed icon: a single-colour silhouette the system tints.
      await save('$res/drawable-${e.key}/ic_launcher_monochrome.png', n, n, (c, s) {
        final box = Rect.fromCenter(center: s.center(Offset.zero), width: s.width * 0.62, height: s.height * 0.62);
        c.saveLayer(Offset.zero & s, Paint());
        c.translate(box.left, box.top);
        MiloPainter(awake: 1, mouth: 0.5).paint(c, box.size);
        c.restore();
        c.drawRect(
          Offset.zero & s,
          Paint()
            ..blendMode = BlendMode.srcIn
            ..color = Colors.white,
        );
      });
    }
    // Legacy square icons (pre-Android 8).
    const legacy = {'mdpi': 48, 'hdpi': 72, 'xhdpi': 96, 'xxhdpi': 144, 'xxxhdpi': 192};
    for (final e in legacy.entries) {
      final n = e.value;
      await save('$res/mipmap-${e.key}/ic_launcher.png', n, n, (c, s) {
        c.clipRRect(RRect.fromRectAndRadius(Offset.zero & s, Radius.circular(s.width * 0.22)));
        background(c, s);
        milo(c, Rect.fromCenter(center: s.center(Offset.zero), width: s.width * 0.86, height: s.height * 0.86));
      });
    }
    File('$res/mipmap-anydpi-v26/ic_launcher.xml')
      ..parent.createSync(recursive: true)
      ..writeAsStringSync('''<?xml version="1.0" encoding="utf-8"?>
<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">
    <background android:drawable="@color/ic_launcher_background" />
    <foreground android:drawable="@drawable/ic_launcher_foreground" />
    <monochrome android:drawable="@drawable/ic_launcher_monochrome" />
</adaptive-icon>
''');
  });

  test('play store icon', () async {
    await save('store-assets/icon-512.png', 512, 512, (c, s) {
      background(c, s);
      bubbles(c, Offset.zero & s);
      milo(c, Rect.fromCenter(center: s.center(const Offset(0, 14)), width: s.width * 0.9, height: s.height * 0.9));
    });
  });

  test('feature graphic', () async {
    await save('store-assets/feature-graphic-1024x500.png', 1024, 500, (c, s) {
      background(c, s);
      final art = Rect.fromLTWH(560, 20, 460, 460);
      bubbles(c, art, scale: 1.1);
      milo(c, Rect.fromLTWH(560, 70, 330, 330), mouth: 0.7);
      c.save();
      c.translate(820, 230);
      final pipShape = targets.first.mouth;
      PipPainter(
        beakOpen: pipShape.open,
        beakWidth: pipShape.width,
        flap: 0.4,
        glow: 0.4,
      ).paint(c, const Size(190, 190));
      c.restore();

      void text(String t, double x, double y, double size, Color color, {FontWeight weight = FontWeight.w700}) {
        final tp = TextPainter(
          text: TextSpan(
            text: t,
            style: TextStyle(fontFamily: 'Andika', fontSize: size, fontWeight: weight, color: color, height: 1.1),
          ),
          textDirection: TextDirection.ltr,
        )..layout(maxWidth: 540);
        tp.paint(c, Offset(x, y));
      }

      text('EchoSteps', 56, 120, 92, ES.cream);
      text('Speech & Imitation Lab', 60, 232, 38, ES.turquoise);
      text('Every sound makes magic', 60, 300, 32, ES.sunshine, weight: FontWeight.w400);
      // Small colour dots echoing the voice meter.
      for (var i = 0; i < 9; i++) {
        final h = 10 + 26 * (0.5 + 0.5 * math.sin(i * 0.9));
        c.drawRRect(
          RRect.fromRectAndRadius(Rect.fromLTWH(62 + i * 20.0, 400 - h, 12, h), const Radius.circular(6)),
          Paint()..color = [ES.coral, ES.sunshine, ES.turquoise, ES.lilac][i % 4],
        );
      }
    });
  });
}
