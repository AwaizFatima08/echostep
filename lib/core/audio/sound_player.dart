import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';

/// Soft sound effects bundled in assets/audio/sfx/ (synthesised by
/// scripts/make_sfx.py). Nothing harsh: no buzzers, no alarms.
enum Sfx { pop, droplet, chime, bloom, sparkle, wake }

/// Plays sound effects and the optional ambient pad.
class SoundPlayer {
  SoundPlayer({this.enabled = true});

  /// False in widget tests, where no audio platform exists.
  final bool enabled;

  final _sfx = [AudioPlayer(), AudioPlayer(), AudioPlayer()];
  final _music = AudioPlayer();
  int _next = 0;

  /// Parent settings plus the child's in-game mute button.
  bool sfxOn = true;
  double sfxVolume = 0.7;
  bool musicOn = false; // off by default (sensory load)
  double musicVolume = 0.25;
  bool _musicWanted = false;

  Future<void> sfx(Sfx s, {double volume = 1.0}) async {
    if (!enabled || !sfxOn) return;
    final p = _sfx[_next];
    _next = (_next + 1) % _sfx.length;
    try {
      await p.setAsset('assets/audio/sfx/${s.name}.wav');
      await p.setVolume((volume * sfxVolume).clamp(0.0, 1.0));
      unawaited(p.play());
    } catch (e) {
      debugPrint('sfx ${s.name} failed: $e');
    }
  }

  /// Ambient pad, only on screens where the mic is off.
  Future<void> music(bool on) async {
    _musicWanted = on;
    if (!enabled) return;
    try {
      if (on && musicOn && musicVolume > 0) {
        if (_music.audioSource == null) {
          await _music.setAsset('assets/audio/sfx/pad_loop.wav');
          await _music.setLoopMode(LoopMode.one);
        }
        await _music.setVolume(musicVolume);
        if (!_music.playing) unawaited(_music.play());
      } else if (_music.playing) {
        await _music.pause();
      }
    } catch (e) {
      debugPrint('music failed: $e');
    }
  }

  void apply({required bool sfxEnabled, required bool musicEnabled}) {
    sfxOn = sfxEnabled;
    musicOn = musicEnabled;
    music(_musicWanted);
  }

  Future<void> pauseAll() async {
    if (!enabled) return;
    for (final p in _sfx) {
      await p.stop();
    }
    await _music.pause();
  }

  Future<void> resume() => music(_musicWanted);
}
