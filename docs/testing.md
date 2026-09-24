# Testing EchoSteps

## Automated (no microphone needed)

| Suite | Command | What it proves |
|---|---|---|
| Host unit + widget tests (79) | `flutter test` | YIN pitch without octave errors; vowel recognition (ah/oh/oo/ee) at child pitches; hum vs "ee"/"oo"; vocalization and babble-syllable counting; adaptive noise gate and sensitivity; mic muted while the app speaks; Echo Safari scoring (Explore: any sound; Practise: the target is >2× faster, other sounds still finish); store persistence, corrupt files, caps, merge; session tracker incl. screen-overlap guard and daily limit; progress, growth tree and PDF report; cloud sync against fake Firebase (silent guest backup, PDD field names, no email stored, backlog upload, deletion, backup off, restore on a second device); full app flows (onboarding, Sound Spark, Echo Safari incl. "Next sound" mic hand-over, cards, parent gate, Parent Zone, daily limit) |
| Firestore security rules (8) | `cd firebase/rules-test && npm install && JAVA_HOME=~/jdks/jdk-21.0.12.1+1 firebase emulators:exec --only firestore "npm test" --project demo-echosteps` | Owner-only access; signed-out and other families denied; unknown fields (email, real name, audio) rejected; field types and ranges enforced; sessions filed under the right child; deletion allowed |
| End-to-end on a device | see below | Real Android plugins (TTS, audio, files, PDF) with a synthetic child voice: setup → Sound Spark → Echo Safari ×2 → cards → Parent Zone → report → restart |
| Cloud end-to-end on a device | see below | Real Firebase SDKs + rules on the local emulators: guest backup → add email (same UID) → sign out → wrong password refused → restore on a "new device" → delete account; another family can't read |
| Stress | `adb shell monkey -p com.homilabs.echosteps --pct-syskeys 0 --throttle 120 -v 3000` | Thousands of random taps and swipes, like a toddler mashing the screen |

### Running the device tests on this machine
Gradle builds starve the emulator (its hang watchdog kills it), and `pixel6_api35` is shared with other projects. So: use the dedicated AVD, and build before driving.

```
# 1. build the test APK (emulator may be off)
nice -n 19 flutter build apk --debug --target integration_test/app_flow_test.dart
# 2. start the dedicated emulator
ANDROID_AVD_HOME=/mnt/storage/projects/android-avd ~/Android/Sdk/emulator/emulator -avd echosteps_api35 -port 5580 -gpu swangle_indirect -cores 3 -memory 2560 -no-audio &
# 3. drive it
flutter drive --driver test_driver/integration_test.dart --target integration_test/app_flow_test.dart --use-application-binary build/app/outputs/flutter-apk/app-debug.apk -d emulator-5580
```
For `cloud_test.dart`, first start `firebase emulators:start --only auth,firestore --project demo-echosteps` (JDK 21) and run `adb -s emulator-5580 reverse tcp:9099 tcp:9099` and `adb -s emulator-5580 reverse tcp:8085 tcp:8085`, then steps 1 and 3 with that target. It never touches the production project.

To play the app on an emulator without a microphone: `flutter build apk --debug --dart-define=ES_SYNTH_VOICE=true` (a synthetic child hums, babbles and says vowels).

## Manual real-voice check (about 15 minutes, needs a person and a real phone)

The emulator has no microphone, so the device's real mic, echo cancellation and a real child's voice must be checked by hand. Use **Parent Zone → Settings → Test the microphone**, then play normally.

| # | Do this | Expect |
|---|---|---|
| 1 | Microphone check: stay quiet for 10 s (a fan or TV on is fine) | "Quiet (below the noise gate)"; the bar stays empty |
| 2 | Speak softly, then loudly | Bar rises; loud reaches the top; vocalizations count up once per sound |
| 3 | Hold "aaah", "ooo", "eee", "oh" | "Sounds like" shows the vowel most of the time |
| 4 | Hum "mmm" with lips closed | "Sounds like: mmm (hum)" |
| 5 | Say "ba-ba-ba" | Syllables counts 3 |
| 6 | Sound Spark: whisper, then shout | Small yellow bubbles, then big rainbow bubbles and stars; Milo wakes, and dozes after ~4 s of quiet |
| 7 | While the app is speaking, stay silent | Its own voice does **not** wake Milo or grow flowers |
| 8 | Echo Safari (Explore), any sound | Flower grows and blooms; cards unlock |
| 9 | Settings → Practise; hold the right sound vs a different one | Right sound grows the flower clearly faster |
| 10 | Calm mode on | Fewer bubbles, no stars |
| 11 | Daily play time 10 min, keep playing | Milo says goodnight; lock → 10 more minutes works; My Cards still opens |
| 12 | Background the app mid-Sound Spark, return | Mic indicator (Android's green dot) off while away |
| 13 | Deny the microphone during setup | Everything works by touch (tap Milo, tap the flower) |
| 14 | Family & account → Save progress across devices; then on a second phone "I already have an account" | Same child and progress appear |
| 15 | Delete account and all data | Returns to setup; signing in with that email fails |

Note the phone model, Android version and anything odd.

## Real-voice tuning (before v1.1)

The vowel and hum detectors are tuned on published children's formant averages and tested with a synthetic voice. The most valuable next step is feedback, with consent and supervision, from the tester families: does Sound Spark react to each child (including very quiet ones), and does Practise level recognise each target? The app records no audio; if recordings are wanted for tuning, collect them separately with parental consent.
