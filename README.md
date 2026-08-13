<div align="center">

# Tactus

**Tactile Haptic Feedback & Mechanical Sound Synthesizer for macOS**

*Redefining desktop interaction through physical Taptic Engine detents and real-time audio synthesis.*

---

</div>

## Overview

**Tactus** bridges the gap between digital interaction and physical feel. By combining low-level MultitouchSupport actuator access with low-latency synthetic audio generation, Tactus translates trackpad gestures into precise, satisfying mechanical detents and clicks.

Designed strictly using **Apple's Liquid Glass Design System**, Tactus integrates seamlessly into macOS with native vibrancy, translucent glass containers, and adaptive appearance modes.

---

## Key Features

- **Hardware-Level Taptic Haptics**  
  Directly actuates the trackpad's physical Taptic Engine—delivering tactile notch pulses during scrolling and click responses without requiring active finger pressure.

- **Adaptive Velocity Detent Engine**  
  Dynamic step distance and gain scaling according to scroll velocity:
  - *Precision Drag*: Fine micro-notches (~1.5pt) for pixel-accurate adjustments.
  - *Standard Scroll*: Natural mechanical wheel detents (~4.0pt).
  - *High-Speed Flick*: Expanded ratchet detents (~10pt+) to prevent haptic buzzing.

- **Flywheel Momentum Inertia**  
  Simulates physical wheel momentum when fingers lift off the trackpad, providing smooth decaying haptic feedback as scrolling decelerates.

- **Procedural Sound Synthesizer**  
  Real-time audio synthesis engine generating zero-latency mechanical click profiles:
  - `Nok` — Classic mechanical ratchet click.
  - `Tok` — Deep tactile wood snap.
  - `Vyl` — Crisp vinyl detent tick.
  - `Click` — Precise switch toggle.

- **Liquid Glass Interface**  
  Built with native macOS Liquid Glass components (`.glassEffect()`, `GlassEffectContainer`, `.buttonStyle(.glass)`), full desktop refraction, and seamless Dark/Light appearance support.

---

## System Requirements

- **Operating System**: macOS 14.0 or later (macOS 26+ recommended for Liquid Glass rendering)
- **Hardware**: Mac with Force Touch Trackpad (Apple Silicon M1–M4 or Intel)
- **Permissions**: Accessibility Permission required for global event monitoring

---

## Building from Source

### Prerequisites

- Xcode 15.0+ (Xcode 16+ or Xcode 26+ recommended)
- Swift 6.0 Toolchain

### Build Commands

Clone the repository and build using Swift Package Manager or the automated build script:

```bash
git clone https://github.com/GrimmDevel/tactus.git
cd tactus
chmod +x build.sh
./build.sh
```

The compiled application bundle will be generated in `./build/Tactus.app`.

---

## Architecture & Implementation

```
Sources/TapticScroll/
├── main.swift              # App entry point & NSStatusItem setup
├── ContentView.swift       # SwiftUI Liquid Glass preferences UI
├── SettingsManager.swift   # Observable state & UserDefaults persistence
├── HapticEngine.swift      # CGEvent tap & MultitouchSupport actuator driver
└── AudioEngine.swift       # AVAudioEngine procedural sound synthesizer
```

### Privacy & Performance

- **Zero Data Collection**: Tactus processes system scroll and click events entirely locally.
- **Low Footprint**: Ultra-lightweight event tap architecture operating with under 0.5% CPU overhead.

---

## License

Designed and created under the MIT License.
