import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../core/audio/voice_analyzer.dart';
import '../models/child.dart';
import '../services/services.dart';
import '../views/rest_view.dart';
import 'kid_widgets.dart';

/// Base for child screens that listen: Sound Spark and an Echo Safari stop.
///
/// Turns the mic on when the screen opens and off when it closes or the app
/// goes to the background, keeps the screen awake (a vocalizing child isn't
/// touching it), records the visit, and calls [onFrames] every animation
/// frame with all voice frames analysed since the last one.
abstract class ListeningState<T extends StatefulWidget> extends State<T>
    with WidgetsBindingObserver, SingleTickerProviderStateMixin {
  late final Services services = Services.of(context);
  late final Ticker _ticker;
  Duration _last = Duration.zero;

  /// Whether the microphone is live. False means touch-only.
  bool micOn = false;
  bool _started = false;
  SessionRecord? _visit;

  ChildProfile get child => services.store.active!;

  /// Session mode recorded for this screen (spark / safari).
  String get mode;

  /// Echo Safari target id, for the synthetic voice and the session record.
  String? get targetId => null;

  /// Called every animation frame. [latest] is the newest analysis (silent
  /// when none), [frames] everything analysed since the previous tick.
  void onFrames(VoiceFrame latest, List<VoiceFrame> frames, double dt);

  /// Hook for screens that greet the child once listening starts.
  void onStarted() {}

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _ticker = createTicker(_onTick);
    WidgetsBinding.instance.addPostFrameCallback((_) => _open());
    Services.of(context).session.timeUp.addListener(_onTimeUp);
  }

  void _open() {
    if (!mounted) return;
    _visit = services.session.begin(child, mode, target: targetId);
    if (services.session.limitReached(child)) {
      _onTimeUp();
      return;
    }
    _startListening();
  }

  Future<void> _startListening() async {
    if (!mounted || _started) return;
    _started = true;
    services.sound.music(false);
    services.voice.sensitivity = child.settings.sensitivity;
    final ok = await services.voice.start(targetId: targetId, owner: this);
    if (!mounted) return;
    setState(() => micOn = ok);
    unawaited(WakelockPlus.enable().catchError((_) {}));
    _last = Duration.zero;
    services.voice.drain();
    if (!_ticker.isActive) _ticker.start();
    onStarted();
  }

  Future<void> _stopListening() async {
    if (!_started) return;
    _started = false;
    if (_ticker.isActive) _ticker.stop();
    await services.voice.stop(owner: this);
    unawaited(WakelockPlus.disable().catchError((_) {}));
  }

  void _onTick(Duration elapsed) {
    final dt = _last == Duration.zero ? 1 / 60 : (elapsed - _last).inMicroseconds / 1e6;
    _last = elapsed;
    final step = dt.clamp(0.0, 0.1);
    final frames = services.voice.drain();
    final hop = VoiceAnalyzer.hopSeconds;
    for (final f in frames) {
      services.session.onFrame(f, hop);
    }
    onFrames(frames.isEmpty ? services.voice.frame.value : frames.last, frames, step);
  }

  void _onTimeUp() {
    if (!mounted || !services.session.timeUp.value && !services.session.limitReached(child)) return;
    if (ModalRoute.of(context)?.isCurrent != true) return;
    _stopListening();
    services.speech.hush();
    Navigator.of(context).push(fadeRoute(const RestView())).then((extended) {
      if (!mounted) return;
      if (extended == true) {
        _startListening();
      } else {
        Navigator.of(context).maybePop();
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused || state == AppLifecycleState.hidden) {
      _stopListening();
      services.speech.hush();
      if (_visit != null) {
        services.session.end(_visit);
        _visit = null;
      }
    } else if (state == AppLifecycleState.resumed && ModalRoute.of(context)?.isCurrent == true) {
      _visit ??= services.session.begin(child, mode, target: targetId);
      _startListening();
    }
  }

  @override
  void dispose() {
    services.session.timeUp.removeListener(_onTimeUp);
    WidgetsBinding.instance.removeObserver(this);
    _ticker.dispose();
    // During a route change the next listening screen may already be up;
    // leave its speech alone.
    final successor = services.voice.owner != null && services.voice.owner != this;
    _stopListening();
    if (!successor) services.speech.hush();
    if (_visit != null) services.session.end(_visit);
    super.dispose();
  }
}
