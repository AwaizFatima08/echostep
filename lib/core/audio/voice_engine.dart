import 'dart:async';

import 'package:flutter/foundation.dart';

import 'audio_input.dart';
import 'voice_analyzer.dart';

/// Owns the microphone while a listening screen is open.
///
/// The mic runs only on screens that need it (Sound Spark, an Echo Safari
/// stop, the parent's sound check) and stops when they close. Samples are
/// analysed on the fly and dropped: nothing is recorded or stored.
class VoiceEngine {
  VoiceEngine({required this.appSpeaking, AudioInput Function(String? targetId)? inputFactory})
    : _inputFactory = inputFactory ?? _defaultInput {
    appSpeaking.addListener(_syncMute);
  }

  /// Build with `--dart-define=ES_SYNTH_VOICE=true` to drive the app from a
  /// synthetic voice (emulator, screenshots, demos).
  static const synthVoice = bool.fromEnvironment('ES_SYNTH_VOICE');

  static AudioInput _defaultInput(String? targetId) {
    if (!synthVoice) return MicInput();
    return SynthInput(script: targetId == null ? null : SynthInput.targetScript(targetId));
  }

  /// True while the app itself is talking; the mic is ignored meanwhile so
  /// prompts never count as the child's voice.
  final ValueListenable<bool> appSpeaking;
  final AudioInput Function(String? targetId) _inputFactory;

  /// Latest analysis.
  final frame = ValueNotifier<VoiceFrame>(VoiceFrame.silent);

  final analyzer = VoiceAnalyzer();
  final _pending = <VoiceFrame>[];
  AudioInput? _input;
  StreamSubscription<Float32List>? _sub;
  bool _running = false;

  /// The screen currently using the mic. Screens overlap during route
  /// transitions (a new stop opens before the old one is disposed), so a
  /// stale screen's stop() must not switch off its successor's mic.
  Object? _owner;
  int _gen = 0;

  bool get running => _running;

  /// The screen that holds the mic, if any.
  Object? get owner => _owner;

  set sensitivity(double s) => analyzer.sensitivity = s;

  /// Starts listening. Returns false when the mic isn't available (no
  /// permission or no hardware); screens then work by touch alone.
  ///
  /// Ownership is claimed before any await, and every start/stop bumps a
  /// generation, so a start or stop that was overtaken while waiting backs
  /// off instead of touching its successor's input.
  Future<bool> start({String? targetId, Object? owner}) async {
    if (_running && _owner == owner) return true;
    _owner = owner;
    final gen = ++_gen;
    if (_input != null) await _stop();
    if (gen != _gen) return false;
    final input = _inputFactory(targetId);
    if (input is MicInput && !await MicInput.granted()) return false;
    if (gen != _gen) return false;
    try {
      final stream = await input.start();
      if (gen != _gen) {
        await input.stop();
        return false;
      }
      _input = input;
      _running = true;
      _syncMute();
      _sub = stream.listen(_onSamples, onError: (Object e) => debugPrint('mic stream error: $e'));
      return true;
    } catch (e) {
      debugPrint('mic start failed: $e');
      try {
        await input.stop();
      } catch (_) {}
      return false;
    }
  }

  /// Stops listening, unless [owner] is given and another screen has taken
  /// the mic since.
  Future<void> stop({Object? owner}) async {
    if (owner != null && owner != _owner) return;
    _owner = null;
    _gen++;
    await _stop();
  }

  Future<void> _stop() async {
    _running = false;
    final input = _input, sub = _sub;
    _input = null;
    _sub = null;
    // Stop the microphone first: waiting on the subscription's cancel before
    // it would leave the mic open a little after the screen closed.
    try {
      await input?.stop();
    } catch (e) {
      debugPrint('mic stop failed: $e');
    }
    // Nothing depends on the cancel finishing; awaiting it can stall when
    // the input has already closed its stream.
    unawaited(sub?.cancel());
    _pending.clear();
    frame.value = VoiceFrame.silent;
  }

  /// Takes every frame analysed since the last call, so counters (syllables,
  /// vocalizations) are never lost between animation ticks.
  List<VoiceFrame> drain() {
    final out = List<VoiceFrame>.of(_pending);
    _pending.clear();
    return out;
  }

  /// Feeds samples directly (unit tests).
  @visibleForTesting
  void feed(Float32List samples) => _onSamples(samples);

  void _syncMute() => analyzer.muted = appSpeaking.value;

  void _onSamples(Float32List samples) {
    final frames = analyzer.add(samples);
    if (frames.isEmpty) return;
    _pending.addAll(frames);
    // Bound memory if nobody drains (e.g. a paused ticker).
    if (_pending.length > 200) _pending.removeRange(0, _pending.length - 200);
    frame.value = frames.last;
  }

  void dispose() => appSpeaking.removeListener(_syncMute);
}
