import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'core/audio/sound_player.dart';
import 'core/audio/speech.dart';
import 'core/audio/voice_engine.dart';
import 'core/theme.dart';
import 'services/cloud_sync.dart';
import 'services/services.dart';
import 'services/session_tracker.dart';
import 'services/store.dart';
import 'views/splash_view.dart';

class EchoStepsApp extends StatefulWidget {
  const EchoStepsApp({
    super.key,
    required this.store,
    required this.sound,
    required this.speech,
    required this.voice,
    required this.session,
    required this.cloud,
    this.home,
  });

  final Store store;
  final SoundPlayer sound;
  final Speech speech;
  final VoiceEngine voice;
  final SessionTracker session;
  final CloudSync cloud;

  /// Overrides the first screen (tests).
  final Widget? home;

  @override
  State<EchoStepsApp> createState() => _EchoStepsAppState();
}

class _EchoStepsAppState extends State<EchoStepsApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    Services.apply(store: widget.store, sound: widget.sound, speech: widget.speech, voice: widget.voice);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      widget.sound.pauseAll();
      widget.store.flush();
    } else if (state == AppLifecycleState.resumed) {
      widget.sound.resume();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Services(
      store: widget.store,
      sound: widget.sound,
      speech: widget.speech,
      voice: widget.voice,
      session: widget.session,
      cloud: widget.cloud,
      child: MaterialApp(
        title: 'EchoSteps',
        debugShowCheckedModeBanner: false,
        theme: ES.theme(),
        // Big, readable text for grown-ups, but never so big it breaks the
        // child screens' layouts.
        builder: (context, child) {
          final mq = MediaQuery.of(context);
          return MediaQuery(
            data: mq.copyWith(textScaler: mq.textScaler.clamp(minScaleFactor: 1, maxScaleFactor: 1.3)),
            child: child!,
          );
        },
        home: widget.home ?? const SplashView(),
      ),
    );
  }
}

/// Adds bundled asset licences to the app's licence page.
void registerLicenses() {
  LicenseRegistry.addLicense(() async* {
    yield LicenseEntryWithLineBreaks(['Andika font'], await rootBundle.loadString('assets/fonts/OFL.txt'));
    yield const LicenseEntryWithLineBreaks(
      ['Noto Color Emoji (AAC card pictures)'],
      'Copyright 2013 Google LLC.\n\n'
      'The AAC card pictures are images from Noto Color Emoji '
      '(https://github.com/googlefonts/noto-emoji), used under the Apache License, '
      'Version 2.0 (http://www.apache.org/licenses/LICENSE-2.0); the Noto Emoji font '
      'files are under the SIL Open Font License 1.1. Images were resized for this app.',
    );
  });
}
