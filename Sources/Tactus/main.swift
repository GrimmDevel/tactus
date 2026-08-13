import AppKit
import SwiftUI

class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem!
    var window: NSWindow?
    let settings = SettingsManager.shared

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        if let path = Bundle.main.path(forResource: "AppIconOriginal", ofType: "png"),
           let iconImage = NSImage(contentsOfFile: path) {
            NSApp.applicationIconImage = iconImage
        }

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "hand.tap.fill", accessibilityDescription: "Tactus")
            button.action = #selector(statusItemClicked)
            button.target = self
        }

        buildStatusBarMenu()
        HapticEngine.shared.start()

        if !settings.isAccessibilityGranted {
            showWindow()
        }
    }

    @objc func statusItemClicked() {
        showWindow()
    }

    func buildStatusBarMenu() {
        let menu = NSMenu()

        let headerItem = NSMenuItem(title: "Tactus", action: nil, keyEquivalent: "")
        headerItem.isEnabled = false
        menu.addItem(headerItem)
        menu.addItem(NSMenuItem.separator())

        let scrollItem = NSMenuItem(title: "Scroll Haptics", action: #selector(toggleScrollHaptics), keyEquivalent: "")
        scrollItem.target = self
        scrollItem.state = settings.isScrollHapticsEnabled ? .on : .off
        menu.addItem(scrollItem)

        let clickItem = NSMenuItem(title: "Click Haptics", action: #selector(toggleClickHaptics), keyEquivalent: "")
        clickItem.target = self
        clickItem.state = settings.isClickHapticsEnabled ? .on : .off
        menu.addItem(clickItem)

        let soundItem = NSMenuItem(title: "Sound Effects", action: #selector(toggleSound), keyEquivalent: "")
        soundItem.target = self
        soundItem.state = settings.isSoundEnabled ? .on : .off
        menu.addItem(soundItem)

        let loginItem = NSMenuItem(title: "Launch at Login", action: #selector(toggleLaunchAtLogin), keyEquivalent: "")
        loginItem.target = self
        loginItem.state = settings.isLaunchAtLoginEnabled ? .on : .off
        menu.addItem(loginItem)

        menu.addItem(NSMenuItem.separator())

        let settingsItem = NSMenuItem(title: "Preferences…", action: #selector(showWindow), keyEquivalent: "s")
        settingsItem.target = self
        menu.addItem(settingsItem)

        menu.addItem(NSMenuItem.separator())

        let quitItem = NSMenuItem(title: "Quit Tactus", action: #selector(quitApp), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)

        statusItem.menu = menu
    }

    @objc func toggleScrollHaptics() {
        settings.isScrollHapticsEnabled.toggle()
        buildStatusBarMenu()
    }

    @objc func toggleClickHaptics() {
        settings.isClickHapticsEnabled.toggle()
        buildStatusBarMenu()
    }

    @objc func toggleSound() {
        settings.isSoundEnabled.toggle()
        buildStatusBarMenu()
    }

    @objc func toggleLaunchAtLogin() {
        settings.isLaunchAtLoginEnabled.toggle()
        buildStatusBarMenu()
    }

    @objc func showWindow() {
        if window == nil {
            let contentView = ContentView()
            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 520, height: 680),
                styleMask: [.titled, .closable, .miniaturizable, .fullSizeContentView],
                backing: .buffered,
                defer: false
            )
            window.center()
            window.title = "Tactus"
            window.titlebarAppearsTransparent = true
            window.titleVisibility = .hidden
            window.isMovableByWindowBackground = true
            window.backgroundColor = .clear
            window.contentView = NSHostingView(rootView: contentView)
            window.isReleasedWhenClosed = false
            self.window = window
        }
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc func quitApp() {
        NSApplication.shared.terminate(nil)
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.run()
