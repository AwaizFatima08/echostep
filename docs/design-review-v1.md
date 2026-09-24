# EchoSteps V1: design review, tool-set critique and locked decisions

Reviewed against `docs/product-design-document-v1.md` (the owner's PDD). Where this file and the PDD disagree, **§0 below wins**.

## 0. Locked decisions

| # | Decision | Why |
|---|---|---|
| L1 | Package `com.homilabs.echosteps`, app name **EchoSteps**. Never change the package after the first Play upload. | Matches the owner's other apps (`com.homilabs.*`). |
| L2 | Flutter, **Android only**, English, portrait (`sensorPortrait`). | Toddlers rotate devices; a fixed layout is predictable (good for autistic children) and halves layout testing. |
| L3 | **Local-first data.** A JSON store on the device is the source of truth; Firestore is a mirror. The app never waits on the network. | Anonymous sign-in fails offline on first launch; the PDD's Firestore-only model would then have nowhere to write. |
| L4 | Firestore tree is `users/{uid}/children/{childId}/sessions/{sessionId}`, not a top-level `sessions` collection. No `parent_email` field. | Owner-only security rules become one line; the email already lives in Firebase Auth (data minimisation). |
| L5 | Account upgrade uses **email + password** linking (the anonymous UID is kept, so nothing is lost). Google sign-in is deferred to V1.1. | Google sign-in needs the Play app-signing SHA-1, which only exists after the first upload. |
| L6 | **Cloud backup can be switched off** by the parent, and onboarding says plainly what is uploaded. No audio ever leaves the device. | Families Policy and COPPA: disclose and minimise children's data. |
| L7 | In-app **"Delete account and all cloud data"**, plus a public deletion page. | Play's account-deletion policy applies once accounts can be created. |
| L8 | No Firebase Analytics, Crashlytics, ads or tracking SDKs. | Families Policy; the app needs none of them. |
| L9 | Characters (Milo the Bear, Pip the Bird) are **drawn in code** (Flutter `CustomPainter`), not Lottie. | No art pipeline is available (Gemini exhausted). Code-drawn characters can react to the voice live: Milo's mouth opens with the child's loudness, Pip's beak shows the target mouth shape. |
| L10 | AAC pictures are **Noto Color Emoji** PNGs (Apache 2.0, Google). | Consistent, clear, openly licensed pictograms without generative art. |
| L11 | Spoken prompts use the device's **text-to-speech**, slowed down (rate ~0.4). | No voice-generation service; TTS is offline on Android and the rate suits slow learners. |
| L12 | **Errorless**: no buzzers, crosses, scores, "try again" or timers visible to the child. Silence shows a gentle idle animation. | PDD §3, kept. |
| L13 | **Calm mode** (fewer particles, slower motion, no screen-wide bursts) and background music **off by default**. | The PDD's "neon glow" and "rainbow burst stars" risk sensory overload for some autistic children. |
| L14 | The app **never claims mastery by itself.** It records *practised* sounds; a parent or therapist taps to mark a sound *mastered*. | Consumer-grade acoustic analysis can't verify articulation; the SLP report must stay honest. |
| L15 | Core AAC cards (**more, help, all done, yes, no**) are always available; the rest unlock through Echo Safari, and a parent can unlock all. | AAC best practice: communication must never be locked behind speech performance. |
| L16 | Parent Zone is behind a **multiplication gate**, not a 3-second hold. | Toddlers hold buttons for 3 seconds easily; Play's Families Policy expects a real adult check. |
| L17 | The app is positioned as **educational practice, not a medical device or therapy**. | Play health-app policy; avoids medical-claim review. |

## 1. What the PDD gets right

- Rewarding *any* vocal exertion first (Sound Spark) and shaping toward targets second (Echo Safari) is the right order for minimally verbal children.
- Guest mode first, with no forced account, removes the biggest onboarding drop-off.
- Zero negative reinforcement, chunky targets and a dark, low-glare canvas.
- Linking vocal practice to AAC gives the practice a functional purpose.
- A parent view that makes small gains visible is the feature that keeps families using the app.

## 2. Improvements made

1. **Adaptive noise floor.** Instead of a fixed threshold, the analyser keeps tracking the room's background level, so a fan or TV doesn't make Milo react all the time and a very quiet child still gets through. A parent sensitivity slider fine-tunes it.
2. **Vocalization counting that means something.** A "vocalization" is a sound of at least 150 ms following a pause, so one long "aaah" counts once and background clicks don't count.
3. **Age-scaled goals.** Echo Safari's hold target is ~1.5 s for ages 2–3, 2.5 s for 4–5 and 3.5 s for 6+. Short holds come from voice time accumulated across attempts, never a single breath.
4. **Explore vs Practise level** (set by the parent). Explore: any voice grows the flower. Practise: the target sound grows it three times faster, and any other sound still grows it slowly (errorless).
5. **Syllable targets are about babbling, not consonant identity.** /ba/, /ma/ and /da/ are detected as repeated syllable onsets ("ba-ba-ba"), which is canonical babbling, a genuine milestone. Telling /b/ from /d/ acoustically on a phone is not reliable, and the app doesn't pretend it can.
6. **"Mmm" hum target** added: lip closure plus voicing is an early oral-motor goal and a stepping stone to /m/-words (more, mama).
7. **Sound-to-word bridge.** Each Echo Safari target unlocks cards that start with that sound (Ah → "all done"; Mmm → "more"; Ba → "ball", "bubbles").
8. **Echo safety.** The mic is ignored while the app is speaking, and echo cancellation is on, so the app's own prompts never count as the child's voice.
9. **Session rest.** An optional daily play-time limit ends with a calm goodbye; only a grown-up can extend it.
10. **Front-camera mirror deferred to V2.** Camera access for toddlers adds a permission, privacy review and on-device vision work. Pip's animated beak models the mouth shape instead.

## 3. Tool-set critique

| PDD choice | Verdict | Used instead / why |
|---|---|---|
| Flutter (Dart) | ✅ Keep | Proven on the owner's machine and in Sound Painter. |
| Firebase Firestore + Auth | ✅ Keep, with changes (L3–L7) | Firestore's offline cache is not enough on its own: first-launch offline sign-in fails, so the app is local-first. |
| `flutter_audio_capture` | ❌ Replace | Low maintenance and no echo-cancellation control. **`record`** streams PCM16 with Android's `VOICE_RECOGNITION` source and echo cancellation, and is already field-tested in Sound Painter. |
| `fftea` / autocorrelation | ❌ Replace | Plain autocorrelation makes octave errors on children's high voices. **YIN pitch detection** plus harmonic-fit vowel recognition (pure Dart, unit-tested in Sound Painter) is used instead; no FFT library needed. |
| Lottie | ❌ Replace | Needs After Effects-authored JSON that doesn't exist, and Lottie clips can't react to the live voice. `CustomPainter` characters (L9). |
| `fl_chart` | ✅ Keep | Weekly activity bars in the Parent Zone. |
| (missing) PDF export | ➕ Add | `pdf` builds the SLP report; `share_plus` hands it to email, WhatsApp or Drive. |
| (missing) TTS | ➕ Add | `flutter_tts` for spoken prompts and AAC card words (L11). |
| (missing) SFX/music | ➕ Add | `just_audio` for soft, code-synthesised chimes and droplets (no harsh tones). |
| (missing) Keep-awake | ➕ Add | `wakelock_plus` while listening: a vocalising child isn't touching the screen. |

## 4. Risks and open items

- **Real voices.** Detection is tuned on published children's formant averages and tested with synthetic voices; the emulator has no microphone. Tuning with consented recordings from real children (outside the app) is the most valuable V1.1 input.
- **Contact email** for the privacy policy and store listing: needs the owner's choice.
- **Play developer account type:** personal accounts created after Nov 2023 need a 14-day closed test with 12 testers before production.
- **Firebase API key restriction** (to the Android package and signing SHA-1s) should be applied in Google Cloud Console once the Play app-signing key exists.
