import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app.dart';
import 'core/audio/sound_player.dart';
import 'core/audio/speech.dart';
import 'core/audio/voice_engine.dart';
import 'firebase_options.dart';
import 'services/cloud_sync.dart';
import 'services/session_tracker.dart';
import 'services/store.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  registerLicenses();

  final store = await Store.open();

  // Firebase is optional: without it (no Play services, first launch
  // offline, a failure) the app works fully on the device.
  FirebaseAuth? auth;
  FirebaseFirestore? db;
  try {
    await Firebase.initializeApp(options: firebaseOptions).timeout(const Duration(seconds: 8));
    auth = FirebaseAuth.instance;
    db = FirebaseFirestore.instance;
  } catch (e) {
    debugPrint('Firebase unavailable: $e');
  }
  final cloud = CloudSync(store: store, auth: auth, db: db);
  unawaited(cloud.start());

  final speech = Speech();
  final sound = SoundPlayer();
  runApp(
    EchoStepsApp(
      store: store,
      sound: sound,
      speech: speech,
      voice: VoiceEngine(appSpeaking: speech.speaking),
      session: SessionTracker(store),
      cloud: cloud,
    ),
  );
}
