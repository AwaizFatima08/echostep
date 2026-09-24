import 'dart:io';
import 'dart:ui' as ui;

import 'package:echosteps/core/content.dart';
import 'package:echosteps/core/theme.dart';
import 'package:echosteps/widgets/growth_tree.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Renders the growth tree at several stages to build/preview/trees.png.
void main() {
  test('render trees', () async {
    final stages = [
      const TreeStats(vocalizations: 0, minutes: 0, activeDays: 0, practised: [], mastered: []),
      TreeStats(vocalizations: 0, minutes: 2, activeDays: 1, practised: targets.take(2).toList(), mastered: const []),
      TreeStats(vocalizations: 60, minutes: 12, activeDays: 3, practised: targets.take(4).toList(), mastered: const []),
      TreeStats(
        vocalizations: 400,
        minutes: 90,
        activeDays: 9,
        practised: targets.take(6).toList(),
        mastered: [targets[0]],
      ),
      TreeStats(
        vocalizations: 2500,
        minutes: 400,
        activeDays: 30,
        practised: targets,
        mastered: targets.take(4).toList(),
      ),
    ];
    const w = 360.0, h = 288.0;
    final rec = ui.PictureRecorder();
    final c = Canvas(rec);
    c.drawRect(Rect.fromLTWH(0, 0, w * stages.length, h), Paint()..color = ES.card);
    for (var i = 0; i < stages.length; i++) {
      c.save();
      c.translate(i * w, 0);
      GrowthTreePainter(stages[i], seed: 7).paint(c, const Size(w, h));
      c.restore();
    }
    final img = await rec.endRecording().toImage((w * stages.length).toInt(), h.toInt());
    Directory('build/preview').createSync(recursive: true);
    File(
      'build/preview/trees.png',
    ).writeAsBytesSync((await img.toByteData(format: ui.ImageByteFormat.png))!.buffer.asUint8List());
  });
}
