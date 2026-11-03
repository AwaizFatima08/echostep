// One My Steps lesson: a "first, then, then" picture schedule of three steps.
// The child (or grown-up) taps Go, the step opens, and coming back with the
// step finished ticks it off. Leaving a step early just keeps the schedule
// where it was: nothing is lost and nothing is "wrong".

import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/audio/sound_player.dart';
import '../../core/content.dart';
import '../../core/lessons.dart';
import '../../core/theme.dart';
import '../../services/services.dart';
import '../../widgets/characters.dart';
import '../../widgets/effects.dart';
import '../../widgets/kid_widgets.dart';
import '../animals/animal_friends_view.dart';
import '../pitch/pitch_slide_view.dart';
import '../safari/safari_stop_view.dart';
import '../spark/sound_spark_view.dart';
import '../turns/echo_turns_view.dart';
import '../words/word_step_view.dart';

/// The screen a lesson step opens. Every one of them returns `true` when the
/// step was finished.
Widget stepScreen(LessonStep s) => switch (s.kind) {
  StepKind.spark => SoundSparkView(lessonSeconds: s.seconds),
  StepKind.pitch => PitchSlideView(lessonSeconds: s.seconds),
  StepKind.stop => SafariStopView(target: s.target!, lesson: true),
  StepKind.turns => EchoTurnsView(target: s.target!, lesson: true),
  StepKind.animal => AnimalFriendsView(only: animalById(s.ref!)),
  StepKind.word => WordStepView(card: cardById(s.ref!)!),
};

class LessonView extends StatefulWidget {
  const LessonView({super.key, required this.lesson, this.open = stepScreen});

  final Lesson lesson;

  /// Builds each step's screen (tests replace it).
  final Widget Function(LessonStep) open;

  @override
  State<LessonView> createState() => _LessonViewState();
}

class _LessonViewState extends State<LessonView> {
  late final Services _s;
  int _current = 0;
  bool _busy = false;

  Lesson get lesson => widget.lesson;
  bool get _finished => _current >= lesson.steps.length;

  @override
  void initState() {
    super.initState();
    _s = Services.of(context);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _s.sound.music(false);
      final names = [for (final st in lesson.steps) st.label];
      _s.speech.prompt('First, ${names[0]}. Then, ${names[1]}. Then, ${names[2]}.');
    });
  }

  @override
  void dispose() {
    _s.speech.hush();
    super.dispose();
  }

  Future<void> _go() async {
    if (_busy || _finished) return;
    _busy = true;
    await _s.speech.hush();
    if (!mounted) return;
    final ok = await Navigator.of(context).push<bool>(fadeRoute(widget.open(lesson.steps[_current])));
    _busy = false;
    if (!mounted || ok != true) return;
    setState(() => _current++);
    if (_finished) {
      _s.store.recordLesson(_s.store.active!, lesson.id);
      _s.sound.sfx(Sfx.bloom);
      unawaited(_s.speech.prompt('You did the whole lesson!'));
    } else {
      _s.sound.sfx(Sfx.chime, volume: 0.6);
      unawaited(_s.speech.prompt('Next, ${lesson.steps[_current].label}!'));
    }
  }

  void _nextLesson() {
    final next = nextLesson(_s.store.active!.lessonsDone);
    Navigator.of(context).pushReplacement(fadeRoute(LessonView(lesson: next, open: widget.open)));
  }

  @override
  Widget build(BuildContext context) {
    final c = _s.store.active!;
    final chapter = chapterOf(lesson);
    final n = chapters.indexOf(chapter) + 1;
    return Scaffold(
      body: Backdrop(
        calm: c.settings.calmMode,
        top: const Color(0xFF22304A),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
            child: Column(
              children: [
                Row(
                  children: [
                    const KidBackButton(),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Chapter $n · ${chapter.title}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: 15, color: chapter.color, fontWeight: FontWeight.w700),
                          ),
                          Text(
                            lesson.title,
                            key: const ValueKey('lesson-title'),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w700),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Expanded(
                  child: Column(
                    children: [
                      for (var i = 0; i < lesson.steps.length; i++) ...[
                        Expanded(
                          child: _StepTile(
                            key: ValueKey('step-$i'),
                            step: lesson.steps[i],
                            number: i + 1,
                            state: i < _current
                                ? _TileState.done
                                : i == _current
                                ? _TileState.now
                                : _TileState.later,
                            onTap: i == _current ? _go : null,
                          ),
                        ),
                        if (i < lesson.steps.length - 1) const SizedBox(height: 10),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                if (!_finished)
                  Pulse(
                    child: BouncyButton(
                      label: 'Go',
                      onTap: _go,
                      child: Container(
                        key: const ValueKey('lesson-go'),
                        padding: const EdgeInsets.symmetric(horizontal: 56, vertical: 18),
                        decoration: BoxDecoration(
                          color: ES.coral,
                          borderRadius: BorderRadius.circular(40),
                          boxShadow: [BoxShadow(color: ES.coral.withValues(alpha: 0.45), blurRadius: 22)],
                        ),
                        child: const Text(
                          'Go!',
                          style: TextStyle(fontSize: 30, fontWeight: FontWeight.w700, color: ES.canvasDeep),
                        ),
                      ),
                    ),
                  )
                else
                  Column(
                    children: [
                      const Text(
                        'Lesson done!',
                        key: ValueKey('lesson-done'),
                        style: TextStyle(fontSize: 32, fontWeight: FontWeight.w700, color: ES.sunshine),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          RoundButton(
                            key: const ValueKey('lesson-home'),
                            icon: Icons.home_rounded,
                            label: 'Back to My Steps',
                            color: ES.turquoise,
                            onTap: () => Navigator.of(context).maybePop(),
                          ),
                          const SizedBox(width: 28),
                          RoundButton(
                            key: const ValueKey('lesson-next'),
                            icon: Icons.arrow_forward_rounded,
                            label: 'Next lesson',
                            color: ES.coral,
                            onTap: _nextLesson,
                          ),
                        ],
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

enum _TileState { done, now, later }

class _StepTile extends StatelessWidget {
  const _StepTile({super.key, required this.step, required this.number, required this.state, this.onTap});

  final LessonStep step;
  final int number;
  final _TileState state;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final now = state == _TileState.now;
    final done = state == _TileState.done;
    final tile = AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: ES.card.withValues(alpha: state == _TileState.later ? 0.6 : 1),
        borderRadius: BorderRadius.circular(ES.radius),
        border: Border.all(color: now ? step.color : (done ? ES.sunshine : ES.cardLine), width: now ? 4 : 2),
        boxShadow: now ? [BoxShadow(color: step.color.withValues(alpha: 0.35), blurRadius: 18)] : null,
      ),
      child: Row(
        children: [
          Text(
            number == 1 ? 'First' : 'Then',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: now ? step.color : ES.muted),
          ),
          const SizedBox(width: 12),
          SizedBox.square(
            dimension: 72,
            child: FittedBox(child: StepArt(step: step)),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              step.label,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w700,
                color: state == _TileState.later ? ES.muted : ES.cream,
              ),
            ),
          ),
          if (done) const Icon(Icons.star_rounded, color: ES.sunshine, size: 44),
        ],
      ),
    );
    return Semantics(
      label: '${number == 1 ? 'First' : 'Then'}: ${step.label}${done ? ', done' : ''}',
      button: onTap != null,
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onTap,
        child: now ? Pulse(amount: 0.02, child: tile) : tile,
      ),
    );
  }
}

/// The picture for a step: the same character or card the step shows.
class StepArt extends StatelessWidget {
  const StepArt({super.key, required this.step});
  final LessonStep step;

  @override
  Widget build(BuildContext context) {
    switch (step.kind) {
      case StepKind.spark:
        return const Milo(size: 80, awake: 0, glow: 0.3);
      case StepKind.pitch:
        return const Pip(size: 80, shape: MouthShape.ah, glow: 0.4);
      case StepKind.stop:
        final shape = step.target!.releaseMouth ?? step.target!.mouth;
        return SizedBox.square(
          dimension: 80,
          child: CustomPaint(
            painter: MouthPainter(open: shape.open, width: shape.width, teeth: shape.teeth),
          ),
        );
      case StepKind.turns:
        return const SizedBox(
          width: 80,
          height: 80,
          child: Stack(
            children: [
              Positioned(left: 0, top: 10, child: Pip(size: 46, shape: MouthShape.ah)),
              Positioned(right: 0, bottom: 4, child: Milo(size: 46)),
            ],
          ),
        );
      case StepKind.animal:
        return Image.asset(animalById(step.ref!)!.asset, width: 80, height: 80);
      case StepKind.word:
        return Image.asset(cardById(step.ref!)!.asset, width: 80, height: 80);
    }
  }
}
