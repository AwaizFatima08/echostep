// My Steps path: every chapter and its lessons as stepping stones. Finished
// stones get a star; the suggested lesson glows and has a big button at the
// top. Every lesson can be opened at any time.

import 'package:flutter/material.dart';

import '../../core/lessons.dart';
import '../../core/theme.dart';
import '../../services/services.dart';
import '../../widgets/effects.dart';
import '../../widgets/kid_widgets.dart';
import 'lesson_view.dart';

class PathView extends StatefulWidget {
  const PathView({super.key});

  @override
  State<PathView> createState() => _PathViewState();
}

class _PathViewState extends State<PathView> {
  late final Services _s;

  @override
  void initState() {
    super.initState();
    _s = Services.of(context);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _s.speech.prompt('Let\'s take some steps!');
    });
  }

  Future<void> _open(Lesson l) async {
    await _s.speech.hush();
    if (!mounted) return;
    await Navigator.of(context).push(fadeRoute(LessonView(lesson: l)));
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final c = _s.store.active!;
    final done = c.lessonsDone;
    final next = nextLesson(done);
    final nextChapter = chapterOf(next);
    return Scaffold(
      body: Backdrop(
        calm: c.settings.calmMode,
        top: const Color(0xFF22304A),
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
                        'My Steps',
                        style: TextStyle(fontSize: 30, fontWeight: FontWeight.w700, color: ES.sunshine),
                      ),
                    ),
                    Text(
                      '${lessonsFinished(done)} / ${allLessons.length}',
                      key: const ValueKey('path-count'),
                      style: const TextStyle(fontSize: 18, color: ES.muted, fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
                child: Pulse(
                  amount: 0.03,
                  child: BouncyButton(
                    label: 'Next lesson: ${next.title}',
                    onTap: () => _open(next),
                    child: Container(
                      key: const ValueKey('path-next'),
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                      decoration: BoxDecoration(
                        color: nextChapter.color,
                        borderRadius: BorderRadius.circular(ES.radius),
                        boxShadow: [BoxShadow(color: nextChapter.color.withValues(alpha: 0.4), blurRadius: 20)],
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.play_arrow_rounded, size: 48, color: ES.canvasDeep),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  nextChapter.title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontSize: 15, color: ES.canvasDeep),
                                ),
                                Text(
                                  next.title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 26,
                                    fontWeight: FontWeight.w700,
                                    color: ES.canvasDeep,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: ListView.builder(
                  key: const ValueKey('path-list'),
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                  itemCount: chapters.length,
                  itemBuilder: (context, i) {
                    final ch = chapters[i];
                    final chDone = ch.lessons.where((l) => (done[l.id] ?? 0) > 0).length;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 14),
                      child: Container(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
                        decoration: BoxDecoration(
                          color: ES.card,
                          borderRadius: BorderRadius.circular(ES.radius),
                          border: Border.all(color: ch.color.withValues(alpha: 0.7), width: 2),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    '${i + 1}. ${ch.title}',
                                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: ch.color),
                                  ),
                                ),
                                Text('$chDone / ${ch.lessons.length}', style: const TextStyle(color: ES.muted)),
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text(ch.subtitle, style: const TextStyle(fontSize: 13, color: ES.muted)),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                for (final l in ch.lessons)
                                  Expanded(
                                    child: _Stone(
                                      lesson: l,
                                      color: ch.color,
                                      times: done[l.id] ?? 0,
                                      suggested: l.id == next.id,
                                      onTap: () => _open(l),
                                    ),
                                  ),
                              ],
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

class _Stone extends StatelessWidget {
  const _Stone({
    required this.lesson,
    required this.color,
    required this.times,
    required this.suggested,
    required this.onTap,
  });

  final Lesson lesson;
  final Color color;
  final int times;
  final bool suggested;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final done = times > 0;
    final stone = Container(
      width: 72,
      height: 72,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: done ? color : ES.canvasDeep,
        border: Border.all(color: color, width: suggested ? 5 : 3),
        boxShadow: suggested ? [BoxShadow(color: color.withValues(alpha: 0.6), blurRadius: 20)] : null,
      ),
      child: Icon(done ? Icons.star_rounded : Icons.play_arrow_rounded, size: 40, color: done ? ES.canvasDeep : color),
    );
    return BouncyButton(
      label: '${lesson.title}${done ? ', done' : ''}',
      onTap: onTap,
      child: Column(
        key: ValueKey('stone-${lesson.id}'),
        children: [
          suggested ? Pulse(amount: 0.08, child: stone) : stone,
          const SizedBox(height: 6),
          Text(
            lesson.title,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 14, height: 1.15),
          ),
        ],
      ),
    );
  }
}
