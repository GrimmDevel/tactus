import SwiftUI
import AppKit

struct VisualEffectBackground: NSViewRepresentable {
    func makeNSView(context: Context) -> NSVisualEffectView {
        let v = NSVisualEffectView()
        v.material = .hudWindow
        v.blendingMode = .behindWindow
        v.state = .active
        return v
    }
    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {}
}

struct ContentView: View {
    @ObservedObject var settings = SettingsManager.shared

    var body: some View {
        ZStack {
            VisualEffectBackground()
                .ignoresSafeArea()

            VStack(spacing: 0) {
                headerBar
                    .padding(.horizontal, 24)
                    .padding(.top, 20)
                    .padding(.bottom, 12)

                ScrollView(showsIndicators: false) {
                    GlassEffectContainer(spacing: 16) {
                        VStack(spacing: 16) {
                            if !settings.isAccessibilityGranted {
                                permissionBanner
                            }
                            hapticControlsPanel
                            soundControlsPanel
                        }
                        .padding(.horizontal, 24)
                        .padding(.vertical, 16)
                    }
                }

                footerBar
                    .padding(.horizontal, 24)
                    .padding(.vertical, 10)
            }
        }
        .frame(width: 520, height: 680)
    }

    private var headerBar: some View {
        HStack(spacing: 14) {
            Group {
                if let path = Bundle.main.path(forResource: "AppIconOriginal", ofType: "png"),
                   let nsImage = NSImage(contentsOfFile: path) {
                    Image(nsImage: nsImage)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 38, height: 38)
                        .clipShape(Circle())
                } else {
                    Image(systemName: "hand.tap.fill")
                        .font(.system(size: 20, weight: .semibold))
                        .frame(width: 38, height: 38)
                }
            }
            .glassEffect(.regular.interactive(), in: .circle)

            VStack(alignment: .leading, spacing: 1) {
                Text("Tactus")
                    .font(.system(size: 20, weight: .bold, design: .rounded))

                Text("Tactile Feedback & Sound Synthesizer")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
            }

            Spacer()

            HStack(spacing: 5) {
                Circle()
                    .fill(settings.isAccessibilityGranted ? Color.green : Color.orange)
                    .frame(width: 7, height: 7)

                Text(settings.isAccessibilityGranted ? "Active" : "Needs Permission")
                    .font(.system(size: 10, weight: .semibold, design: .rounded))
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .glassEffect(.regular, in: .capsule)
        }
    }

    private var permissionBanner: some View {
        HStack(spacing: 14) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 22))
                .foregroundStyle(.orange)

            VStack(alignment: .leading, spacing: 2) {
                Text("Accessibility Permission Required")
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                Text("Enable in System Settings for system-wide haptics.")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button("Grant Access") {
                settings.promptAccessibilityPermissions()
                NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!)
            }
            .buttonStyle(.glassProminent)
        }
        .padding(16)
        .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 16))
    }

    private var hapticControlsPanel: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label("Haptic Engine", systemImage: "waveform.path.badge.plus")
                .font(.system(size: 14, weight: .bold, design: .rounded))

            toggleRow("Launch at Login",
                      subtitle: "Start Tactus automatically when logging into macOS",
                      isOn: $settings.isLaunchAtLoginEnabled)

            toggleRow("Scroll Wheel Haptics",
                      subtitle: "Ratchet detent pulse when scrolling",
                      isOn: $settings.isScrollHapticsEnabled)

            toggleRow("Inertia Momentum Haptics",
                      subtitle: "Decay haptics when fingers lift off",
                      isOn: $settings.isInertiaHapticsEnabled)

            toggleRow("Trackpad Click Haptics",
                      subtitle: "Haptic bump on click",
                      isOn: $settings.isClickHapticsEnabled)

            if settings.isClickHapticsEnabled {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Click Phase")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.secondary)
                    Picker("", selection: $settings.clickFeedbackMode) {
                        Text("Down + Up").tag(0)
                        Text("Down Only").tag(1)
                        Text("Up Only").tag(2)
                    }
                    .pickerStyle(.segmented)
                }
            }

            Divider()

            sliderRow("Scroll Step Distance",
                      value: $settings.scrollSensitivity,
                      range: 1.0...10.0, step: 0.5,
                      format: "%.1f px")

            VStack(alignment: .leading, spacing: 6) {
                Text("Haptic Strength")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary)
                Picker("", selection: $settings.hapticStrength) {
                    Text("Light").tag(1)
                    Text("Medium").tag(2)
                    Text("Strong").tag(3)
                }
                .pickerStyle(.segmented)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("Pattern Style")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary)
                Picker("", selection: $settings.hapticPatternRaw) {
                    Text("Alignment").tag(0)
                    Text("Generic").tag(1)
                }
                .pickerStyle(.segmented)
            }
        }
        .padding(18)
        .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 16))
    }

    private var soundControlsPanel: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label("Sound Synthesizer", systemImage: "speaker.wave.3.fill")
                .font(.system(size: 14, weight: .bold, design: .rounded))

            toggleRow("Sound Effects",
                      subtitle: "Mechanical ratchet click sounds",
                      isOn: $settings.isSoundEnabled)

            sliderRow("Volume",
                      value: Binding(
                          get: { Double(settings.soundVolume) },
                          set: { settings.soundVolume = Float($0) }
                      ),
                      range: 0.0...1.0, step: 0.01,
                      format: { "\(Int($0 * 100))%" })

            VStack(alignment: .leading, spacing: 6) {
                Text("Sound Profile")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary)
                Picker("", selection: $settings.soundStyleRaw) {
                    Text("Nok").tag(0)
                    Text("Tok").tag(1)
                    Text("Vyl").tag(2)
                    Text("Click").tag(3)
                }
                .pickerStyle(.segmented)
            }

            HStack {
                Spacer()
                Button(action: testHapticAndSound) {
                    Label("Test", systemImage: "hand.tap.fill")
                }
                .buttonStyle(.glass)
            }
        }
        .padding(18)
        .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 16))
    }

    private var footerBar: some View {
        HStack {
            let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
            Text("Tactus v\(version)")
                .font(.system(size: 10, weight: .medium, design: .rounded))
                .foregroundStyle(.tertiary)
            Spacer()
            Button(action: {
                settings.checkAccessibilityPermissions()
                HapticEngine.shared.start()
            }) {
                Label("Re-check", systemImage: "arrow.clockwise")
                    .font(.system(size: 10, weight: .semibold, design: .rounded))
            }
            .buttonStyle(.glass)
        }
    }

    private func toggleRow(_ title: String, subtitle: String, isOn: Binding<Bool>) -> some View {
        Toggle(isOn: isOn) {
            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                Text(subtitle)
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
            }
        }
        .tint(.accentColor)
    }

    private func sliderRow(_ title: String, value: Binding<Double>,
                           range: ClosedRange<Double>, step: Double,
                           format: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(title)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                Text(String(format: format, value.wrappedValue))
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
            }
            Slider(value: value, in: range, step: step)
                .tint(.accentColor)
        }
    }

    private func sliderRow(_ title: String, value: Binding<Double>,
                           range: ClosedRange<Double>, step: Double,
                           format: @escaping (Double) -> String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(title)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                Text(format(value.wrappedValue))
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
            }
            Slider(value: value, in: range, step: step)
                .tint(.accentColor)
        }
    }

    private func testHapticAndSound() {
        let strength = settings.hapticStrength
        let pattern = settings.hapticPattern
        let style = settings.soundStyleRaw
        let baseVol = settings.soundVolume
        let volMultiplier: Float = strength == 1 ? 0.5 : (strength == 3 ? 1.4 : 1.0)
        DispatchQueue.main.async {
            HapticEngine.shared.triggerTestHaptic(strength: strength, pattern: pattern)
            AudioEngine.shared.playScrollTick(style: style, volume: baseVol * volMultiplier)
        }
    }
}
