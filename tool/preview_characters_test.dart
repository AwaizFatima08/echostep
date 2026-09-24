import 'dart:io';
import 'dart:ui' as ui;

import 'package:echosteps/core/content.dart';
import 'package:echosteps/widgets/characters.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Renders character poses to build/preview/characters.png for a visual check.
void main() {
  test('render characters', () async {
    const cell = 220.0;
    final painters = <CustomPainter>[
      MiloPainter(awake: 0),
      MiloPainter(awake: 1, mouth: 0, glow: 0.3),
      MiloPainter(awake: 1, mouth: 0.9, glow: 1),
      PipPainter(beakOpen: MouthShape.closed.open, beakWidth: MouthShape.closed.width, happy: true),
      for (final m in [MouthShape.ah, MouthShape.oo, MouthShape.ee]) PipPainter(beakOpen: m.open, beakWidth: m.width),
      for (final m in MouthShape.values) MouthPainter(open: m.open, width: m.width, teeth: m.teeth),
    ];
    const cols = 4;
    final rows = (painters.length / cols).ceil();
    final rec = ui.PictureRecorder();
    final canvas = Canvas(rec);
    canvas.drawRect(const Rect.fromLTWH(0, 0, cell * cols, cell * 4), Paint()..color = const Color(0xFF1A1A2E));
    for (var i = 0; i < painters.length; i++) {
      canvas.save();
      canvas.translate((i % cols) * cell, (i ~/ cols) * cell);
      painters[i].paint(canvas, const Size(cell, cell));
      canvas.restore();
    }
    final img = await rec.endRecording().toImage((cell * cols).toInt(), (cell * rows).toInt());
    final png = await img.toByteData(format: ui.ImageByteFormat.png);
    Directory('build/preview').createSync(recursive: true);
    File('build/preview/characters.png').writeAsBytesSync(png!.buffer.asUint8List());
  });
}
