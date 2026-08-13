import Foundation
import Combine
import ServiceManagement
@preconcurrency import AppKit

final class SettingsManager: ObservableObject {
    nonisolated(unsafe) static let shared = SettingsManager()

    @Published var isLaunchAtLoginEnabled: Bool {
        didSet {
            UserDefaults.standard.set(isLaunchAtLoginEnabled, forKey: "isLaunchAtLoginEnabled")
            updateLaunchAtLogin(enabled: isLaunchAtLoginEnabled)
        }
    }

    @Published var isScrollHapticsEnabled: Bool {
        didSet { UserDefaults.standard.set(isScrollHapticsEnabled, forKey: "isScrollHapticsEnabled") }
    }

    @Published var isInertiaHapticsEnabled: Bool {
        didSet { UserDefaults.standard.set(isInertiaHapticsEnabled, forKey: "isInertiaHapticsEnabled") }
    }

    @Published var isClickHapticsEnabled: Bool {
        didSet { UserDefaults.standard.set(isClickHapticsEnabled, forKey: "isClickHapticsEnabled") }
    }

    @Published var clickFeedbackMode: Int {
        didSet { UserDefaults.standard.set(clickFeedbackMode, forKey: "clickFeedbackMode") }
    }

    @Published var isSoundEnabled: Bool {
        didSet { UserDefaults.standard.set(isSoundEnabled, forKey: "isSoundEnabled") }
    }

    @Published var scrollSensitivity: Double {
        didSet { UserDefaults.standard.set(scrollSensitivity, forKey: "scrollSensitivity") }
    }

    @Published var hapticStrength: Int {
        didSet { UserDefaults.standard.set(hapticStrength, forKey: "hapticStrength") }
    }

    @Published var soundVolume: Float {
        didSet { UserDefaults.standard.set(soundVolume, forKey: "soundVolume") }
    }

    @Published var hapticPatternRaw: Int {
        didSet { UserDefaults.standard.set(hapticPatternRaw, forKey: "hapticPatternRaw") }
    }

    @Published var soundStyleRaw: Int {
        didSet { UserDefaults.standard.set(soundStyleRaw, forKey: "soundStyleRaw") }
    }

    @Published var isAccessibilityGranted: Bool = false

    private init() {
        let defaults = UserDefaults.standard
        defaults.register(defaults: [
            "isLaunchAtLoginEnabled": false,
            "isScrollHapticsEnabled": true,
            "isInertiaHapticsEnabled": true,
            "isClickHapticsEnabled": true,
            "clickFeedbackMode": 0,
            "isSoundEnabled": true,
            "scrollSensitivity": 4.0,
            "hapticStrength": 2,
            "soundVolume": 0.8,
            "hapticPatternRaw": 0,
            "soundStyleRaw": 0
        ])

        self.isLaunchAtLoginEnabled = SMAppService.mainApp.status == .enabled
        self.isScrollHapticsEnabled = defaults.bool(forKey: "isScrollHapticsEnabled")
        self.isInertiaHapticsEnabled = defaults.bool(forKey: "isInertiaHapticsEnabled")
        self.isClickHapticsEnabled = defaults.bool(forKey: "isClickHapticsEnabled")
        self.clickFeedbackMode = defaults.integer(forKey: "clickFeedbackMode")
        self.isSoundEnabled = defaults.bool(forKey: "isSoundEnabled")
        self.scrollSensitivity = defaults.double(forKey: "scrollSensitivity")
        let val = defaults.integer(forKey: "hapticStrength")
        self.hapticStrength = val == 0 ? 2 : val
        self.soundVolume = defaults.float(forKey: "soundVolume")
        self.hapticPatternRaw = defaults.integer(forKey: "hapticPatternRaw")
        self.soundStyleRaw = defaults.integer(forKey: "soundStyleRaw")

        checkAccessibilityPermissions()
    }

    private func updateLaunchAtLogin(enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
        }
    }

    func checkAccessibilityPermissions() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: false]
        self.isAccessibilityGranted = AXIsProcessTrustedWithOptions(options as CFDictionary)
    }

    func promptAccessibilityPermissions() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
        _ = AXIsProcessTrustedWithOptions(options as CFDictionary)
    }

    var hapticPattern: NSHapticFeedbackManager.FeedbackPattern {
        switch hapticPatternRaw {
        case 1: return .generic
        default: return .alignment
        }
    }
}
