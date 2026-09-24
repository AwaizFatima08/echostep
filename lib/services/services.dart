import 'package:flutter/widgets.dart';

import '../core/audio/sound_player.dart';
import '../core/audio/speech.dart';
import '../core/audio/voice_engine.dart';
import 'cloud_sync.dart';
import 'session_tracker.dart';
import 'store.dart';

/// The app's long-lived services, available to every screen.
class Services extends InheritedWidget {
  const Services({
    super.key,
    required this.store,
    required this.sound,
    required this.speech,
    required this.voice,
    required this.session,
    required this.cloud,
    required super.child,
  });

  final Store store;
  final SoundPlayer sound;
  final Speech speech;
  final VoiceEngine voice;
  final SessionTracker session;
  final CloudSync cloud;

  static Services of(BuildContext context) => context.getInheritedWidgetOfExactType<Services>()!;

  /// Pushes the active child's and device settings into the audio services.
  void applySettings() => apply(store: store, sound: sound, speech: speech, voice: voice);

  static void apply({
    required Store store,
    required SoundPlayer sound,
    required Speech speech,
    required VoiceEngine voice,
  }) {
    final st = store.settings;
    sound.apply(sfxEnabled: st.sfxOn, musicEnabled: st.musicOn);
    speech.rate = st.speechRate;
    final c = store.active;
    if (c != null) {
      speech.promptsOn = c.settings.promptsOn;
      voice.sensitivity = c.settings.sensitivity;
    }
  }

  @override
  bool updateShouldNotify(Services oldWidget) => false;
}
