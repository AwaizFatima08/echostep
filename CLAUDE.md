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

## Status (2026-11-04)
v1.0.0 and v1.1.0 are live on Google Play (developer name HomiLabs; listing "EchoSteps: Speech Play Lab"). **v1.2.0 (versionCode 3)** adds **My Steps**: a guided path of 7 chapters × 3 lessons (`lib/core/lessons.dart`), each lesson three steps shown as a "first, then, then" picture schedule (`lib/views/steps/`: `path_view.dart`, `lesson_view.dart`). Steps reuse the free-play screens in a lesson mode (`lesson: true` / `lessonSeconds` / `only:`) that finish with `LessonContinueButton` (pops `true`), plus the new **First Words** step (`lib/views/words/word_step_view.dart`, session mode `word`): a picture card whose `AacCard.sound` sets the scored sound. Two new cards (`up`, `uh_oh`). Progress: `ChildProfile.lessonsDone` (`lessons_done` locally and in Firestore). Hub: My Steps banner above the activity grid. Parent Zone and the PDF show lessons finished. App version string: `lib/core/version.dart` (test checks it against pubspec).
- 2026-11-04: Firestore rules fixed and deployed: v1.1 session modes (`animals`, `turns`, `pitch`) were being rejected (their sessions never backed up, and a rejected session failed its whole upload batch). Rules now also accept `word` and `lessons_done`.
- 2026-11-04: v1.2 landing page (Play badge, My Steps features) live on Hostinger (`echosteps.homilabs.org` site in hPanel, not the homilabs.org `public_html`) and Firebase Hosting. v1.2 AAB: `releases/v1.2.0-3/` (Play upload by Homi).
- Artifacts: `releases/v1.<n>.0-<code>/` (AAB, APK, SHA256SUMS); gitignored, in the local and Drive backups.
- Next version: bump `version:` in pubspec.yaml **and** `appVersion` in `lib/core/version.dart`. Real-voice feedback from testers is still the top input (see `docs/testing.md`).

## Code map
- `lib/core/audio/`: `dsp.dart` (YIN pitch, harmonic-fit vowels ah/oh/oo/ee, hum detector, minimum-statistics noise floor), `voice_analyzer.dart` (frames, vocalization and syllable counting), `voice_engine.dart` (mic lifecycle with **owner + generation** guards for overlapping screens), `audio_input.dart` (mic + `SynthInput`), `synth_voice.dart`, `speech.dart` (TTS; mutes mic while speaking), `sound_player.dart` (SFX).
- `lib/core/content.dart`: the 12 Echo Safari targets, the AAC card catalogue (with each word's practice `sound`) and the Animal Friends list. `lib/core/lessons.dart`: My Steps chapters, lessons and steps. Ids in both are stored data: never rename.
- `lib/services/`: `store.dart`, `cloud_sync.dart` (Firestore mirror, account link/sign-in/restore/delete), `session_tracker.dart`, `progress.dart`, `report.dart` (SLP PDF).
- `lib/views/`: splash, onboarding, hub, steps (My Steps path + lesson runner), words (First Words step), spark (Sound Spark), safari (map + stop with `StopScorer`), animals, turns, pitch, cards (AAC wall), rest, parent (zone, progress/settings/family tabs, account, sound check).
- `lib/widgets/listening.dart`: base for every mic screen (wakelock, lifecycle, session, time limit).
- `firebase/`: `firestore.rules`, `rules-test/` (node tests).
- `website/`: landing page, privacy policy (with the account-deletion section, `#delete-account`) and terms. Hosted at https://echosteps.homilabs.org (Hostinger: upload manually, incl. `.htaccess`) and mirrored by Firebase Hosting at https://echosteps-homilabs.web.app (the app's in-app link). Update both after edits. Contact: homilabs.smc@gmail.com.

## Commands
- Tests: `flutter test` (host, 104, incl. all 21 lessons played through). Rules: `cd firebase/rules-test && npm install && JAVA_HOME=~/jdks/jdk-21.0.12.1+1 firebase emulators:exec --only firestore "npm test" --project demo-echosteps`.
- On-device: see `docs/testing.md` (build the test APK first, then `flutter drive --use-application-binary`).
- Emulator/demo without a mic: `--dart-define=ES_SYNTH_VOICE=true`.
- Graphics: `flutter test tool/make_graphics_test.dart` (icons, Play icon, feature graphic). Pictures: `python3 scripts/fetch_aac_pictures.py`. SFX: `python3 scripts/make_sfx.py`.
- Release: `flutter build appbundle --release` (signs via `android/key.properties` → `.secrets/echosteps-upload.keystore`).
- Deploy Firebase: `firebase deploy --only firestore:rules,auth,hosting --project echosteps-homilabs` (hosting serves `website/`).
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
