# EchoSteps: Speech & Imitation Lab

A vocal imitation practice app for young children who are minimally verbal, speech-delayed or autistic (ages 2–6+). Free, no ads, no tracking. Positioned as educational practice, **not** a medical device or therapy.

## Source of truth
- `docs/product-design-document-v1.md`: the owner's PDD (the starting point).
- `docs/design-review-v1.md`: critique, tool-set changes and **locked decisions (§0)**. §0 wins where the two conflict.

## Locked (see design review §0)
- Flutter, **Android only**, English, portrait. Package `com.homilabs.echosteps`: never change it after the first Play upload.
- Local-first: `lib/services/store.dart` (JSON on device) is the source of truth; Firestore mirrors it. The app never waits on the network.
- Firebase project `echosteps-homilabs` (Firestore `nam5`, delete protection on). Auth: anonymous + email/password. No Analytics/Crashlytics/ads SDKs.
- Mic audio is analysed on-device and never stored or sent.
- Errorless design: no fail states, buzzers or scores. The app never decides "mastered"; a grown-up does.
- No Gemini (quota exhausted 2026-09-24). Characters are drawn in code (`lib/widgets/characters.dart`); AAC pictures are Noto Color Emoji PNGs; speech is device TTS.

## Code map
- `lib/core/audio/`: `dsp.dart` (YIN pitch, harmonic-fit vowels ah/oh/oo/ee, hum detector, minimum-statistics noise floor), `voice_analyzer.dart` (frames, vocalization and syllable counting), `voice_engine.dart` (mic lifecycle with **owner + generation** guards for overlapping screens), `audio_input.dart` (mic + `SynthInput`), `synth_voice.dart`, `speech.dart` (TTS; mutes mic while speaking), `sound_player.dart` (SFX).
- `lib/core/content.dart`: the 8 Echo Safari targets and the AAC card catalogue (ids are stored data: never rename).
- `lib/services/`: `store.dart`, `cloud_sync.dart` (Firestore mirror, account link/sign-in/restore/delete), `session_tracker.dart`, `progress.dart`, `report.dart` (SLP PDF).
- `lib/views/`: splash, onboarding, hub, spark (Sound Spark), safari (map + stop with `StopScorer`), cards (AAC wall), rest, parent (zone, progress/settings/family tabs, account, sound check).
- `lib/widgets/listening.dart`: base for every mic screen (wakelock, lifecycle, session, time limit).
- `firebase/`: `firestore.rules`, `rules-test/` (node tests), `hosting/` (privacy + deletion pages at https://echosteps-homilabs.web.app, custom domain echosteps.homilabs.org once DNS is connected). Contact: homilabs.smc@gmail.com.

## Commands
- Tests: `flutter test` (host, 79). Rules: `cd firebase/rules-test && npm install && JAVA_HOME=~/jdks/jdk-21.0.12.1+1 firebase emulators:exec --only firestore "npm test" --project demo-echosteps`.
- On-device: see `docs/testing.md` (build the test APK first, then `flutter drive --use-application-binary`).
- Emulator/demo without a mic: `--dart-define=ES_SYNTH_VOICE=true`.
- Graphics: `flutter test tool/make_graphics_test.dart` (icons, Play icon, feature graphic). Pictures: `python3 scripts/fetch_aac_pictures.py`. SFX: `python3 scripts/make_sfx.py`.
- Release: `flutter build appbundle --release` (signs via `android/key.properties` → `.secrets/echosteps-upload.keystore`).
- Deploy Firebase: `firebase deploy --only firestore:rules,auth,hosting --project echosteps-homilabs`.
- Backup: `bash scripts/backup.sh` (commit first; the GitHub layer refuses untracked/uncommitted files).

## Locations
- Local backup: `/mnt/storage/project_backups/echostep_backup/`
- Google Drive: folder `18W5x9nHFwc-6Cu2EmIO9TLasf0IDCAKt` (rclone remote `gdrive`)
- GitHub (**public**): `https://github.com/AwaizFatima08/echostep`. `.secrets/` and `android/key.properties` are gitignored.

## Machine notes
- JDK 21 at `~/jdks/jdk-21.0.12.1+1` (Firebase emulators need it); system Java 17 builds Android.
- Use the dedicated AVD `echosteps_api35` on port 5580 (`ANDROID_AVD_HOME=/mnt/storage/projects/android-avd`, `-gpu swangle_indirect`). `pixel6_api35` is shared with other projects' sessions.
- Gradle builds starve the emulator (its hang watchdog kills it): build with the emulator off, or with `nice -n 19`. `./gradlew --stop` frees ~5 GB when idle.
- Don't `pkill -f` a pattern that also appears in your own command line.
- `uiautomator dump` fails on screens with continuous animation; use screenshots + coordinates.
