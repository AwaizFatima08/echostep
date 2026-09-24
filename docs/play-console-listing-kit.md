# Play Console listing kit: EchoSteps

Copy-paste material for creating the app in Play Console. Everything here matches what v1.0.0 actually does.

## Upload

| Item | File |
|---|---|
| App bundle (signed with the upload key) | `releases/v1.0.0-1/echosteps-1.0.0-1.aab` |
| App icon 512×512 | `store-assets/icon-512.png` |
| Feature graphic 1024×500 | `store-assets/feature-graphic-1024x500.png` |
| Phone screenshots (9:18) | `store-assets/screenshots/phone/` |
| Privacy policy URL | https://echosteps-homilabs.web.app/privacy |
| Account deletion URL | https://echosteps-homilabs.web.app/delete-account |

Package `com.homilabs.echosteps` · version 1.0.0 (versionCode 1) · minSdk 24 · targetSdk 36.
Use **Play App Signing** (the default). `.secrets/echosteps-upload.keystore` is the upload key (credentials in `.secrets/echosteps-upload-keystore-credentials.txt`).

**After the first upload:** copy the *app signing key* SHA-1 and SHA-256 from Play Console → Test and release → App integrity, and add them to the Firebase Android app:
```
firebase apps:android:sha:create 1:1002720438311:android:171865da887cc59a538602 <SHA> --project echosteps-homilabs
```
Email/password and anonymous sign-in work without this; it is needed only if Google sign-in or App Check is added later.

## Main store listing

**App name** (30 max): `EchoSteps: Speech Play Lab` (26)

**Short description** (80 max):
`Every sound makes magic. Playful voice and imitation practice for little ones.` (78)

**Full description**:
```
EchoSteps turns any sound a child makes into something magical. It is made for young children who are not talking yet, talk only a little, or are learning at their own pace, including autistic children and children with speech delays.

SOUND SPARK: Milo the bear is fast asleep. A hum, a whisper, a click or a big "aaah" wakes him up: he glows and blows bubbles. Quiet sounds make small yellow bubbles; louder sounds make big rainbow ones. There is nothing to get wrong.

ECHO SAFARI: Pip the bird shows a sound and its mouth shape: Ah, Mmm, Oo, Ba, Ee, Ma, Oh and Da. As your child copies it, a flower grows and blooms, and new picture cards unlock.

MY CARDS: Tap a picture to hear the word: more, help, all done, yes, no, eat, drink, play, hug and more. Core words are always available. Communication is never locked or time-limited.

FOR GROWN-UPS (behind a question for adults)
• Vocal Growth Tree: roots for every sound, branches for every day of practice, flowers for every sound practised.
• A weekly chart of play time and voice time.
• Mark a sound as mastered when you or your therapist hear it reliably.
• A one-tap PDF report to share with a speech therapist.
• Explore or Practise level, microphone sensitivity, calm mode, daily time limit, speaking speed.
• Several children on one device.

GENTLE BY DESIGN
• No failing, no buzzers, no scores. Silence simply lets Milo doze.
• Calm mode: fewer bubbles and gentler motion for children who are easily overwhelmed.
• Adapts to the room's background noise, and reacts to very quiet voices.
• Spoken prompts, so no reading is needed.

PRIVATE
• The microphone is analysed on the device and never recorded or uploaded.
• No ads, no in-app purchases, no tracking.
• Optional cloud backup keeps progress safe if the device is lost, and can be switched off or deleted at any time.

EchoSteps is an educational practice app. It is not a medical device and does not replace speech and language therapy.
```

**App category**: Education · **Tags**: Educational, Kids, Language (or Early learning)
**Contact email**: your developer contact address (required and shown publicly; the privacy policy and deletion page point people to it).

## App content

| Section | Answer |
|---|---|
| Privacy policy | https://echosteps-homilabs.web.app/privacy |
| Ads | **No** |
| App access | **All functionality is available without special access** (no login needed; accounts are optional) |
| Content rating (IARC) | Category *Reference, news or educational*. Answer **No** to violence, sexuality, language, controlled substances, gambling, purchases. User interaction: **No** (users can't communicate with each other). Shares location: No. Expected: Everyone / PEGI 3 |
| Target audience | **Ages 5 and under** and **Ages 6–8**. This enrolls the app in the Families program; accept the Families Policy |
| News app | No |
| Government app | No |
| Financial features | None |
| Health | Health apps declaration: **none of the listed health features**. It is an educational app (the listing says it is not a medical device) |
| Account deletion | Accounts can be created: **Yes**. In-app deletion: Parent Zone → Family & account → *Delete account and all data*. Web link: https://echosteps-homilabs.web.app/delete-account |
| Permissions | `RECORD_AUDIO` (core feature, used only while a listening screen is open) and `INTERNET` (optional backup). No special declaration forms |

### Families Policy checklist (v1.0.0)
- No ads SDKs, no analytics or crash SDKs. Third-party packages: Flutter plus `record`, `just_audio`, `flutter_tts`, `permission_handler`, `path_provider`, `wakelock_plus`, `url_launcher`, `share_plus`, `pdf`, `fl_chart`, and Firebase Auth + Cloud Firestore (not ads or analytics).
- The advertising ID permission is explicitly removed from the manifest.
- Grown-up areas (settings, dashboard, report sharing, the privacy link, account screens) are behind a multiplication gate.
- No links out of the app in children's areas; no purchases.
- A nickname is optional and the setup asks for a nickname, not a name.

## Data safety form

**Does your app collect or share any of the required user data types?** → **Yes** (collected, not shared).

| Data type | Collected | Shared | Optional? | Purpose | Notes |
|---|---|---|---|---|---|
| Personal info → **Name** | Yes | No | Yes | App functionality | The child's nickname (optional) |
| Personal info → **Email address** | Yes | No | Yes | Account management | Only if the grown-up adds an account |
| Personal info → **User IDs** | Yes | No | Yes | App functionality, Account management | Firebase anonymous ID |
| App activity → **App interactions** | Yes | No | Yes | App functionality | Practice sessions: durations, sound counts, loudness averages, sounds practised |
| Audio | **No** | No | – | – | Processed only on the device, never stored or sent (not "collected" under Google's definition) |

- Optional: yes for all, since the grown-up can switch cloud backup off.
- **Is all user data encrypted in transit?** Yes (TLS to Firebase).
- **Can users request that their data is deleted?** Yes: in the app, and via the deletion web page.
- **Committed to the Families Policy?** Yes.

## Before production

1. Create an **Internal testing** release and upload the AAB. Play runs a pre-launch report on real devices within about an hour. Check crashes and accessibility warnings. The robot can pass the parent gate only by chance, which is expected.
2. **Personal developer accounts created after November 2023** need a closed test with at least 12 opted-in testers for 14 days before production access. Organisation accounts are exempt.
3. Do the manual real-voice check in `docs/testing.md` on at least one real phone: the emulator has no microphone.
4. Optional: restrict the Firebase Android API key to package `com.homilabs.echosteps` + the signing SHA-1s in Google Cloud Console → APIs & Services → Credentials.
