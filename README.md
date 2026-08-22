<div align="center">

# 🥤 Pour

**A dark, animation-driven drink-pouring experience built with Flutter.**

Swipe through bottles, pick a cup size, tap to pour — watch the cup fill,
the screen wash in the drink's color, and bubbles rise like a cold-drink ad.

![Flutter](https://img.shields.io/badge/Flutter-3.x-02569B?style=flat&logo=flutter&logoColor=white)
![Dart](https://img.shields.io/badge/Dart-3.12-0175C2?style=flat&logo=dart&logoColor=white)
![State](https://img.shields.io/badge/State-Riverpod-4051B5?style=flat)
![Platform](https://img.shields.io/badge/Platform-Android%20%7C%20Web%20%7C%20Windows-informational?style=flat)
![Status](https://img.shields.io/badge/Status-In%20Development-yellow?style=flat)

</div>

---

## 📑 Table of Contents

- [Screenshots](#screenshots)
- [Demo](#demo)
- [Features](#features)
- [Tech Stack](#tech-stack)
- [Project Structure](#project-structure)
- [Getting Started](#getting-started)
- [Customization](#customization)
  - [Dropping in real assets](#dropping-in-real-assets)
  - [Tuning the cup art alignment](#tuning-the-cup-art-alignment)
- [Architecture](#architecture)
  - [How cup size affects fill math](#how-cup-size-affects-fill-math)
  - [How state flows](#how-state-flows)
- [Contributing](#contributing)
- [License](#license)

---

## 📸 Screenshots

<!--
Drop images in docs/screenshots/ and reference them here, e.g.:
<p align="center">
  <img src="docs/screenshots/carousel.png" width="220" />
  <img src="docs/screenshots/pour.png" width="220" />
  <img src="docs/screenshots/full.png" width="220" />
</p>
-->

*Coming soon.*

## 🎬 Demo

<!-- Drop a GIF at docs/demo.gif and reference it here, e.g. ![demo](docs/demo.gif) -->

*Coming soon.*

---

## ✨ Features

- **Swipeable bottle carousel** — four drinks, center bottle sharp and full-size, side bottles dimmed and scaled down; drag, or tap a side bottle to bring it to center.
- **Tilt-to-pour animation** — the centered bottle tips toward the cup, a liquid stream falls, and the cup fills to a level computed from real fill math (see [below](#how-cup-size-affects-fill-math)).
- **Three cup sizes (S / M / L)** — each with its own capacity; switching size resizes the cup with a spring animation and always starts it empty.
- **Full-screen color wash + ambient bubbles** — the whole screen tints in the drink's brand color while there's liquid in the cup, with bubbles drifting up across the screen, cold-drink-ad style.
- **"Cup full" celebration** — a haptic pulse and a badge animation when a pour tops off the cup.
- **Empty cup control** — dump the current cup and start over without changing size.
- **Per-drink color split** — a drink's liquid color (what's poured) and its screen/brand color (what washes the background) are independently configurable, so a can's brand color doesn't have to match what's actually inside it.
- **Tactile polish** — press-down scale feedback on every tappable control, haptics on pour/select/empty, grounding shadows under the bottle and cup, and a glass-shine highlight on the cup.
- **Resilient to missing art** — every image falls back to a labeled placeholder if the asset isn't there yet, so the app never crashes waiting on final art.

---

## 🛠️ Tech Stack

| Layer | Choice |
|---|---|
| Framework | [Flutter](https://flutter.dev) (Dart) |
| State management | [flutter_riverpod](https://pub.dev/packages/flutter_riverpod) — a single `StateNotifier` as the source of truth |
| Animation | [flutter_animate](https://pub.dev/packages/flutter_animate) for readable animation chains, plus hand-rolled `AnimationController`s for the tilt/pour sequence where precise curve/timing control was needed |
| Custom rendering | `CustomPainter` for the liquid's sine-wave surface, `CustomClipper` for the tapered cup fill region |
| Typography | [google_fonts](https://pub.dev/packages/google_fonts) (Space Grotesk + Outfit) |
| Haptics | `flutter/services` `HapticFeedback` |
| Testing | `flutter_test` |

---

## 📁 Project Structure

```
lib/
├── main.dart                        # Entry point, theme, mouse-drag ScrollBehavior
├── config/
│   └── tunables.dart                # Every tunable geometry/timing constant, in one place
├── models/
│   ├── drink_model.dart             # The drink lineup: name, art, liquid color, screen color
│   └── cup_size_config.dart         # S/M/L sizing, scale, and capacity
├── providers/
│   └── pour_state_provider.dart     # Riverpod StateNotifier — the single source of truth
├── animations/
│   ├── liquid_surface_painter.dart  # Sine-wave liquid surface + foam strip
│   └── cup_trapezoid_clipper.dart   # Tapered clip region matching the cup art
├── widgets/                         # Presentational widgets (carousel, cup, bubbles, nav bar, ...)
└── screens/
    └── pour_screen.dart             # Composes everything, orchestrates the pour sequence
```

---

## 🚀 Getting Started

### ✅ Prerequisites

- [Flutter SDK](https://docs.flutter.dev/get-started/install) (Dart `^3.12.2` — see `environment.sdk` in `pubspec.yaml`)
- A target to run on: an Android emulator/device, Chrome, or Windows desktop (desktop builds need the Visual Studio C++ toolchain installed)

### ⚙️ Setup

```bash
git clone <your-repo-url>
cd pour_flutter
flutter pub get
```

### ▶️ Run

```bash
flutter run              # runs on whatever device is connected/selected
flutter run -d chrome    # web
flutter run -d windows   # desktop (requires the MSVC toolchain)
```

### 🧪 Quality checks

```bash
flutter analyze
flutter test
```

---

## 🎨 Customization

### 🖼️ Dropping in real assets

Art already in the repo renders as-is; replace in place to upgrade quality:

```
assets/bottles/fanta.png         # Fanta Orange
assets/bottles/pepsi.png         # Pepsi
assets/bottles/mountaindew.png   # Mountain Dew
assets/bottles/fantapurple.png   # Fanta Purple / Grape
assets/cup/cup.png               # single cup art, reused at all 3 sizes
```

If any of these files are missing, the app doesn't crash — `SafeAssetImage`
(`lib/widgets/safe_asset_image.dart`) falls back to a labeled placeholder
box so the layout still reads correctly.

Every drink lives in one place, `lib/models/drink_model.dart`, as an entry
in the `kDrinks` list. Adding a 5th drink is a one-line addition there — no
other file needs to change.

### 📐 Tuning the cup art alignment

The cup's liquid layer is a separate widget stacked *in front of* `cup.png`
(clipped to the cup's shape, at reduced opacity) rather than baked into the
art. Where exactly the liquid sits — how far below the rim it starts, how
far above the base it stops, how far the glass walls taper in from the
edges — is controlled entirely by fractional constants in
**`lib/config/tunables.dart`**:

```dart
class CupFillGeometry {
  static const double topY = 0.13;        // liquid starts here (rim)
  static const double bottomY = 0.83;     // liquid stops here (base)
  static const double topInset = 0.20;    // side inset at the rim
  static const double bottomInset = 0.30; // side inset at the base
}
```

These are fractions (0.0–1.0) of the cup image's own bounding box, not raw
pixels — so they don't need to change when the cup is resized between S/M/L.
They were measured directly off `cup.png`'s alpha channel (its opaque
bounding box, and the left/right opaque bounds at a couple of chosen
top/bottom rows). If you swap in new art, re-measure the same way rather
than guessing — a few percent of error here is what makes liquid spill
outside the glass walls.

The same file also holds:

- `kCupAspectRatio` — **must** match the real `cup.png`'s own width/height
  ratio (not just the cup's silhouette), since that's the box `BoxFit.contain`
  fits the image into; any mismatch letterboxes the image and throws off
  every fractional measurement above.
- `kCupBaseDisplayHeight` — the Medium cup's on-screen height in logical
  pixels.
- `kCupOpacity` — how translucent the cup art itself renders, so it reads
  as plastic rather than a flat opaque shape.

Tune the aspect ratio and base height first if the cup's silhouette looks
stretched or too small/large, before touching the fill geometry.

---

## 🏗️ Architecture

### 🥛 How cup size affects fill math

Three sizes are defined in `lib/models/cup_size_config.dart`:

| Size | Scale | Capacity (units) |
|---|---|---|
| Small | 0.75x | 150 |
| Medium | 1.0x | 250 |
| Large | 1.3x | 400 |

Every tap on the bottle adds a **fixed pour volume** (`kPourVolumeUnits =
90`, in `lib/config/tunables.dart`) rather than a fixed fill percentage.
The actual fill delta is computed relative to the *current* cup's capacity:

```dart
delta = kPourVolumeUnits / capacityUnits(selectedCupSize)
fillLevel = clamp(fillLevel + delta, 0.0, 1.0)
```

So the same pour fills Small by 60% (90/150), Medium by 36% (90/250), and
Large by 22.5% (90/400) — a bigger cup visibly takes more taps to fill,
without any renderer-side faking. Switching cup size always resets
`fillLevel` to 0 (you start the new size empty), and the size selector is
disabled while a pour animation is in flight so you can't swap sizes
mid-pour.

### 🔄 How state flows

State lives in one Riverpod `StateNotifier`, `pourStateProvider`
(`lib/providers/pour_state_provider.dart`), holding:

- `selectedDrinkIndex` — which of the drinks is active
- `selectedCupSize` — `CupSize.small` / `.medium` / `.large`
- `fillLevel` — 0.0–1.0, relative to the *current* size's capacity
- `isPouring` — true for the duration of the tilt/stream/fill animation

Widgets read it via `ref.watch(pourStateProvider)` and mutate it only
through the notifier's methods (`selectDrink`, `selectCupSize`,
`startPour`, `applyPourFill`, `endPour`, `emptyCup`) — there's no direct
field mutation anywhere else.

`PourScreen` (`lib/screens/pour_screen.dart`) is the only place that owns
animation controllers (the bottle tilt) and orchestrates a pour:

1. Tapping the centered bottle calls `_handlePour`, which calls
   `notifier.startPour()` and starts the tilt `AnimationController`.
2. A listener on that controller watches its progress: partway through the
   downward tilt it flips the liquid stream visible, spawns a bubble batch,
   and calls `notifier.applyPourFill()` (this is the one point where
   `fillLevel` actually changes) — as the bottle swings back upright, the
   stream is hidden again. If that fill reaches 100%, a "cup full"
   celebration triggers alongside it.
3. `CupWithLiquid` reads the *new* `fillLevel` from the provider and tweens
   its liquid layer to that value over ~900ms independently, so the pour
   and the fill animation stay visually in sync without being the same
   animation.
4. Once the tilt finishes, `notifier.endPour()` re-enables the carousel and
   size selector. The background wash doesn't time out — it stays at an
   ambient intensity (`kWashAmbientIntensity`) for as long as the cup holds
   liquid, and only drops to zero once the cup is genuinely empty (a fresh
   size, or an explicit "Empty cup" tap).

Everything else (`BottleCarousel`, `CupSizeSelector`, `LiquidStream`,
`BubbleField`, `AmbientBubbles`, `BackgroundWash`, `PourNavBar`,
`CarouselDots`, `FillReadout`, `EmptyCupButton`) is a pure function of
provider state plus the props `PourScreen` hands it — no widget besides
`PourScreen` reaches into the provider to *drive* a pour, they only read
it.

---

## 🤝 Contributing

1. Fork the repo and branch off `main`: `git checkout -b feature/your-feature`.
2. Keep changes focused — one feature or fix per pull request.
3. Before opening a PR, make sure both of these are clean:
   ```bash
   flutter analyze
   flutter test
   ```
4. Follow the existing conventions:
   - Tunable numbers (geometry, timing, opacity) belong in
     `lib/config/tunables.dart`, not scattered through widget code.
   - All state changes go through `PourStateNotifier` — never mutate
     `PourState` directly from a widget.
   - New widgets should stay presentational: read state via props, don't
     reach into the provider to drive a pour (that's `PourScreen`'s job).
5. Open a PR describing what changed and why. Screenshots or a short GIF
   are appreciated for anything visual.

## 📄 License

No license has been specified yet for this project. Add a `LICENSE` file
and update this section before distributing or accepting external
contributions.
