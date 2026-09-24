# EchoSteps: Speech & Imitation Lab
## Product Design Document & Engineering Specification (V1 — Android)

---

## 1. Executive Summary & Core Objectives

**EchoSteps** is an early-intervention speech therapy and vocal imitation application designed for non-verbal, minimally verbal, and speech-delayed children (ages 2–8), including children on the Autism Spectrum and those with general developmental delays.

```
┌───────────────────────────────────────────────────────────┐
│                      CORE ENGINE                          │
│                                                           │
│   [ Minimal Vocal Input ]           [ Visual Motivation ] │
│   - Pitch / Volume / Vowels ──────► - Instant Glow        │
│   - Gentle Noise Floor              - Interactive Avatars │
│                                     - Parent Progress Map │
└───────────────────────────────────────────────────────────┘
```

### Primary Rehab Objectives
1. **Lower the Barrier to Vocalization:** Encourage non-verbal or shy children to make sounds by rewarding *any* vocal exertion (hums, clicks, open vowels) with vibrant visual feedback.
2. **Oral Motor & Imitation Practice:** Guide children through basic mouth movements, vowel shapes ($/a/$, $/o/$, $/u/$), and simple plosives ($/ba/$, $/ma/$).
3. **Bridge Vocalization to Functional Communication:** Connect basic vocal exercises directly to AAC (Augmentative and Alternative Communication) communication cards.
4. **Visual Therapy Tracking for Parents:** Provide parents and therapists with a clear, encouraging visual representation of vocal frequency, session duration, and developmental milestones.

---

## 2. Strategic Answers to Core Architecture Questions

### Q1: Do we need a login?
* **For V1: No mandatory upfront login.** 
* Force-registering an account creates high friction during early therapy onboarding. 
* **The Solution:** Use **Guest Mode First**. When the app opens for the first time, a quick 2-screen setup asks for the child's alias/nickname and age. An anonymous Firebase user ID is created silently behind the scenes.

### Q2: If the device is changed, will progress be stored?
* **Yes.** Because progress data is linked to the hidden Firebase UID (and optional Firebase Auth link later), data persists in the cloud.
* **Account Upgrading:** Inside the Parent Zone, an optional *"Save Progress across Devices"* button allows parents to link an Email/Google Account at any time without losing current data.

### Q3: Can we add a child alias with parent login?
* **Yes.** A single parent/guardian account supports **multiple child profiles (aliases)**.
* **Data Model:**
  $$ \text{Parent Account (UID)} \longrightarrow \text{Child Profiles (Sub-collection)} \longrightarrow \text{Session Data / Metrics} $$

### Q4: Will the app require backend and Firestore integration?
* **Yes, a light Firestore setup is required for V1.**
* **Why local-only isn't enough:**
  1. **Cross-device sync:** Preserves progress when changing or resetting devices.
  2. **Therapist export:** Allows parents to share session summary logs with speech-language pathologists (SLPs).
  3. **Offline support:** Firestore natively caches data locally when offline and syncs automatically when reconnected to Wi-Fi.

---

## 3. Vibrant, Catchy & Low-Stimulation Design System

To make the app visually engaging for children while remaining safe for neurodivergent users (preventing sensory overload), EchoSteps uses a **High-Contrast "Chubby Pastel & Neon Glow"** design system.

```
   [ Primary Accent ]         [ Secondary Accent ]         [ Soft Canvas ]
┌───────────────────────┐  ┌───────────────────────┐  ┌───────────────────────┐
│   Electric Coral      │  │    Bright Turquoise   │  │   Deep Slate Indigo   │
│      #FF6B6B          │  │        #4ECDC4        │  │        #1A1A2E        │
└───────────────────────┘  └───────────────────────┘  └───────────────────────┘
```

### Design Principles for Low Cognitive Load
* **Chubby Touch Targets:** All interactive buttons are minimum $72 \times 72 \text{ dp}$ with thick, rounded borders ($24\text{ px}$ corner radius).
* **High Contrast on Dark Canvas:** Dark canvas backgrounds (#1A1A2E) allow colorful particle effects and characters to pop without high screen brightness.
* **Zero Negative Reinforcement:** No error buzzers, red crosses, or "Try Again" screens. Silence yields gentle floating idle animations; sound triggers visual celebrations.

---

## 4. App Structure & Complete Screen Layouts

```
                            ┌───────────────────┐
                            │   Splash Screen   │
                            └─────────┬─────────┘
                                      │
                            ┌─────────▼─────────┐
                            │ Onboarding Setup  │
                            │ (Alias & Age)     │
                            └─────────┬─────────┘
                                      │
                            ┌─────────▼─────────┐
                            │   Main Hub        │
                            └─────────┬─────────┘
                                      │
         ┌────────────────────────────┼────────────────────────────┐
         │                            │                            │
┌────────▼────────┐          ┌────────▼────────┐          ┌────────▼────────┐
│ Mode 1: Sound   │          │ Mode 2: Echo    │          │ Parent &        │
│ Spark (Free)    │          │ Safari (Phonics)│          │ Progress Zone   │
└─────────────────┘          └─────────────────┘          └─────────────────┘
```

### Screen 1: Quick Onboarding (Child Alias)
* **Header:** Friendly vector avatar.
* **Inputs:** 
  * "What should we call our superstar?" (TextField with large text).
  * Age Selector pills: `2-3` | `4-5` | `6+`.
* **Action:** Large pulsing **"Start Playing"** button.

### Screen 2: Main Hub (Child Mode)
* **Layout:** Simple, clean vertical grid featuring large cards:
  1. **"Sound Spark" (Free Play):** "Make sound, see magic!"
  2. **"Echo Safari" (Guided Practice):** "Help Pip say 'Ah'!"
  3. **"My AAC Card Wall":** Unlocked speech cards.
* **Top Right:** Lock icon leading to the **Parent Zone** (protected by a 3-second hold or math gate).

### Screen 3: "Sound Spark" (Minimal Input Free Play)
* **Concept:** Designed for children who make minimal or very quiet sounds.
* **Mechanics:**
  * Background features a sleeping character (e.g., *Milo the Bear*).
  * **Microphone Input:** Any sound above background noise causes Milo to wake up, glow, and blow colorful bubble streams across the screen.
  * **Visual Scale:** Quiet whispers create small yellow bubbles; louder sounds generate large rainbow burst stars.

```
+-------------------------------------------------------------+
|  [Back]                                       [Mute SFX]    |
|                                                             |
|                         (   )                               |
|                        ( Milo )  <-- Grows & Glows with     |
|                         (   )        Vocal Volume           |
|                                                             |
|           o  O   o                                          |
|         o   o  O   o  <-- Dynamic Vocal Bubbles             |
|                                                             |
|  +-------------------------------------------------------+  |
|  | [||||||||||..........]  Mic Sensitivity Level          |  |
|  +-------------------------------------------------------+  |
+-------------------------------------------------------------+
```

### Screen 4: "Echo Safari" (Guided Phonics & Imitation)
* **Concept:** Target specific oral movements and vowel sounds.
* **Mechanics:**
  1. **Character Model:** Front camera video frame (optional mask overlay) or character model showing open mouth position for $/a/$ (*"Say AAAAA"*).
  2. **Target Meter:** As the child holds the sound, a visual flower stems upward.
  3. **Completion:** The flower blooms, plays a cheerful chime, and unlocks an AAC Picture Card for the child's collection.

---

## 5. Visual Learning Curve & Progress Map for Parents

Parents of differently abled children often struggle to notice tiny daily improvements. The Parent Dashboard translates raw acoustic metrics into an encouraging, visual **"Vocal Growth Tree"**.

```
           PARENT DASHBOARD: VOCAL GROWTH TREE
           
                     ( Milestone: /ba/ Mastered! )
                                \  
                                 [Leaf]
                                  /
                          [Branch: 15 mins Today]
                            /
                           /
                        [Trunk]
                          /
        ( Root System: 140 Vocalizations Captured )
```

### Parent Dashboard Features
1. **The Growth Tree:** An interactive tree that sprouts new leaves and colorful flowers based on total session time and vocalization counts.
2. **Weekly Vocal Activity Chart:** Simple bar graph showing active vocal minutes per day.
3. **Phoneme Spectrum:** Visual tags showing which sounds the child has attempted ($/a/$, $/e/$, $/o/$, $/ba/$, $/ma/$).
4. **SLP Report Exporter:** One-tap button generating a clean PDF summary to show speech therapists during clinical visits.

---

## 6. Asset Requirements & Required Tools

### Required Software Tools & Frameworks

| Category | Tool / Library | Purpose |
| :--- | :--- | :--- |
| **Framework** | Flutter (Dart) | Cross-platform framework targeting Android V1. |
| **Backend & Sync** | Firebase Firestore & Auth | Anonymous authentication, cloud data persistence, and offline caching. |
| **Audio Capture** | `flutter_audio_capture` | Low-latency raw PCM mic buffer processing. |
| **DSP Analysis** | `fftea` or Custom Autocorrelation | Real-time pitch extraction and RMS volume calculation. |
| **Animations** | Lottie for Flutter (`lottie`) | Smooth, lightweight vector character animations. |
| **Charts** | `fl_chart` | Parent dashboard graphs and vocal frequency trends. |

### Required Art & Audio Assets
1. **Character Animations (Lottie JSON):**
   * *Milo the Bear:* Idle sleeping, waking up, glowing, celebrating.
   * *Pip the Bird:* Flying, singing, mouth open shapes ($/a/$, $/o/$, $/m/$).
2. **Visual Particles:** High-resolution SVG vectors for bubbles, glowing stars, flowers, and musical notes.
3. **Audio / SFX:** Soft acoustic chimes, water droplet sounds, warm background ambient pads, and zero harsh alert tones.

---

## 7. Data Model & Firestore Schema

```json
{
  "users": {
    "PARENT_USER_ID_123": {
      "parent_email": "parent@example.com",
      "created_at": "2026-09-24T12:45:25Z",
      "children": {
        "CHILD_ALIAS_01": {
          "nickname": "Leo",
          "age_group": "3-4",
          "avatar_id": "milo_bear",
          "created_at": "2026-09-24T12:45:25Z",
          "stats": {
            "total_vocalizations": 420,
            "total_minutes_played": 85,
            "mastered_sounds": ["/a/", "/o/", "/ba/"]
          }
        }
      }
    }
  },
  "sessions": [
    {
      "child_id": "CHILD_ALIAS_01",
      "timestamp": "2026-09-24T10:30:00Z",
      "duration_seconds": 360,
      "vocalization_count": 48,
      "avg_volume_db": -18.2,
      "target_sound": "/a/",
      "success_rate": 0.85
    }
  ]
}
```