import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';

/// Spoken prompts and AAC words through the device's text-to-speech engine
/// (offline on Android). Slowed down for children who process language
/// slowly.
class Speech {
  Speech({this.enabled = true});

  /// False in widget tests, where no TTS platform exists.
  final bool enabled;

  FlutterTts? _tts;
  bool _ready = false;
  int _token = 0;

  /// True while the app is talking. The voice engine ignores the mic
  /// meanwhile.
  final speaking = ValueNotifier<bool>(false);

  /// Parent settings.
  bool promptsOn = true;
  double rate = 0.4; // Android: 0.5 is normal speed
  double volume = 1.0;

  Future<void> _init() async {
    if (_ready || !enabled) return;
    _ready = true;
    final t = FlutterTts();
    _tts = t;
    try {
      await t.awaitSpeakCompletion(true);
      await t.setLanguage('en-US');
      await t.setPitch(1.1);
    } catch (e) {
      debugPrint('tts init failed: $e');
    }
  }

  /// Says a coaching prompt; skipped when the parent turned prompts off.
  Future<void> prompt(String text) => promptsOn ? say(text) : Future.value();

  /// Says [text] regardless of the prompt setting (AAC card words: the child
  /// chose to hear them). Completes when finished or interrupted.
  Future<void> say(String text, {double? rateOverride}) async {
    final token = ++_token;
    if (!enabled || text.trim().isEmpty) return;
    await _init();
    final t = _tts;
    if (t == null) return;
    speaking.value = true;
    try {
      await t.stop();
      await t.setSpeechRate(rateOverride ?? rate);
      await t.setVolume(volume);
      // A guessed duration bounds a stuck engine, so the mic can never stay
      // muted.
      final guess = Duration(milliseconds: 1500 + text.length * 160);
      await t.speak(text).timeout(guess, onTimeout: () => t.stop());
    } catch (e) {
      debugPrint('tts failed: $e');
    } finally {
      if (token == _token) {
        // Let the room echo die away before listening again.
        await Future<void>.delayed(const Duration(milliseconds: 250));
        if (token == _token) speaking.value = false;
      }
    }
  }

  Future<void> hush() async {
    _token++;
    speaking.value = false;
    if (!enabled || _tts == null) return;
    try {
      await _tts!.stop();
    } catch (_) {}
  }
}
