import Foundation
import AppKit
import ApplicationServices

private typealias MTDeviceCreateDefaultFunc = @convention(c) () -> UnsafeMutableRawPointer?
private typealias MTDeviceGetDeviceIDFunc = @convention(c) (UnsafeMutableRawPointer, UnsafeMutablePointer<UInt64>) -> Int32
private typealias MTActuatorCreateFromDeviceIDFunc = @convention(c) (UInt64) -> UnsafeMutableRawPointer?
private typealias MTActuatorOpenFunc = @convention(c) (UnsafeMutableRawPointer) -> Int32
private typealias MTActuatorIsOpenFunc = @convention(c) (UnsafeMutableRawPointer) -> DarwinBoolean
private typealias MTActuatorActuateFunc = @convention(c) (UnsafeMutableRawPointer, Int32, UInt32, Float, Float) -> Int32

final class HapticEngine: @unchecked Sendable {
    static let shared = HapticEngine()

    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var globalMonitor: Any?

    private var accumulatedDeltaY: Double = 0.0
    private var lastScrollTime: Date = Date()
    private var recentVelocity: Double = 0.0
    private var lastTickTime: Date = Date.distantPast

    private var inertiaTimer: DispatchSourceTimer?
    private var simulatedVelocity: Double = 0.0
    private var simulatedAccumulatedDelta: Double = 0.0

    private var actuatorRef: UnsafeMutableRawPointer?
    private var mtActuate: MTActuatorActuateFunc?
    private var mtIsOpen: MTActuatorIsOpenFunc?

    private init() {
        setupPrivateActuator()
    }

    private func setupPrivateActuator() {
        guard let handle = dlopen("/System/Library/PrivateFrameworks/MultitouchSupport.framework/MultitouchSupport", RTLD_NOW) else { return }
        
        let createDefaultPtr = dlsym(handle, "MTDeviceCreateDefault")
        let getDeviceIDPtr = dlsym(handle, "MTDeviceGetDeviceID")
        let createFromIDPtr = dlsym(handle, "MTActuatorCreateFromDeviceID")
        let openPtr = dlsym(handle, "MTActuatorOpen")
        let isOpenPtr = dlsym(handle, "MTActuatorIsOpen")
        let actuatePtr = dlsym(handle, "MTActuatorActuate")

        if let createDefaultPtr = createDefaultPtr,
           let getDeviceIDPtr = getDeviceIDPtr,
           let createFromIDPtr = createFromIDPtr,
           let openPtr = openPtr,
           let actuatePtr = actuatePtr {
            
            let createDefault = unsafeBitCast(createDefaultPtr, to: MTDeviceCreateDefaultFunc.self)
            let getDeviceID = unsafeBitCast(getDeviceIDPtr, to: MTDeviceGetDeviceIDFunc.self)
            let createFromID = unsafeBitCast(createFromIDPtr, to: MTActuatorCreateFromDeviceIDFunc.self)
            let openFunc = unsafeBitCast(openPtr, to: MTActuatorOpenFunc.self)
            self.mtActuate = unsafeBitCast(actuatePtr, to: MTActuatorActuateFunc.self)
            
            if let isOpenPtr = isOpenPtr {
                self.mtIsOpen = unsafeBitCast(isOpenPtr, to: MTActuatorIsOpenFunc.self)
            }

            if let dev = createDefault() {
                var devID: UInt64 = 0
                if getDeviceID(dev, &devID) == 0 {
                    if let ref = createFromID(devID) {
                        if openFunc(ref) == 0 {
                            self.actuatorRef = ref
                        }
                    }
                }
            }

            if self.actuatorRef == nil {
                if let ref = createFromID(0x200000001000000) ?? createFromID(0) {
                    if openFunc(ref) == 0 {
                        self.actuatorRef = ref
                    }
                }
            }
        }
    }

    func start() {
        stop()

        let settings = SettingsManager.shared
        settings.checkAccessibilityPermissions()

        if settings.isAccessibilityGranted {
            startCGEventTap()
        } else {
            startGlobalNSEventMonitor()
        }
    }

    func stop() {
        stopInertiaSimulation()

        if let eventTap = eventTap {
            CGEvent.tapEnable(tap: eventTap, enable: false)
            if let runLoopSource = runLoopSource {
                CFRunLoopRemoveSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)
            }
            self.eventTap = nil
            self.runLoopSource = nil
        }

        if let monitor = globalMonitor {
            NSEvent.removeMonitor(monitor)
            globalMonitor = nil
        }
    }

    private func computeDynamicStepThreshold(baseSensitivity: Double, strength: Int, velocity: Double) -> (threshold: Double, gain: Float) {
        let base = max(1.2, baseSensitivity * 0.8)

        let velocityScale: Double
        let gainMultiplier: Float

        if velocity < 100.0 {
            let norm = max(0.0, velocity / 100.0)
            velocityScale = 0.45 + norm * 0.55
            gainMultiplier = Float(0.85 + norm * 0.35)
        } else if velocity <= 600.0 {
            let norm = (velocity - 100.0) / 500.0
            velocityScale = 1.0 + norm * 1.4
            gainMultiplier = Float(1.2 + norm * 0.5)
        } else {
            let norm = min(1.0, (velocity - 600.0) / 800.0)
            velocityScale = 2.4 + norm * 2.2
            gainMultiplier = Float(1.7 + norm * 0.6)
        }

        let baseGain: Float = strength == 1 ? 0.9 : (strength == 3 ? 2.4 : 1.6)
        let finalGain = baseGain * gainMultiplier
        let finalThreshold = max(0.8, base * velocityScale)

        return (finalThreshold, finalGain)
    }

    private func stopInertiaSimulation() {
        inertiaTimer?.cancel()
        inertiaTimer = nil
        simulatedVelocity = 0.0
        simulatedAccumulatedDelta = 0.0
    }

    private func startInertiaSimulation(initialVelocity: Double) {
        stopInertiaSimulation()
        guard SettingsManager.shared.isInertiaHapticsEnabled else { return }
        guard abs(initialVelocity) > 20.0 else { return }

        simulatedVelocity = min(1600.0, abs(initialVelocity))
        let settings = SettingsManager.shared

        let timer = DispatchSource.makeTimerSource(queue: DispatchQueue.main)
        timer.schedule(deadline: .now() + .milliseconds(16), repeating: .milliseconds(16))

        timer.setEventHandler { [weak self] in
            guard let self = self else { return }

            self.simulatedVelocity *= 0.94

            if self.simulatedVelocity < 12.0 {
                self.stopInertiaSimulation()
                return
            }

            let frameDelta = self.simulatedVelocity * 0.016
            self.simulatedAccumulatedDelta += frameDelta

            let strength = settings.hapticStrength
            let baseSensitivity = settings.scrollSensitivity
            let (stepThreshold, dynamicGain) = self.computeDynamicStepThreshold(baseSensitivity: baseSensitivity, strength: strength, velocity: self.simulatedVelocity)

            if self.simulatedAccumulatedDelta >= stepThreshold {
                self.simulatedAccumulatedDelta = 0.0

                let pattern = settings.hapticPattern
                let style = settings.soundStyleRaw
                let baseVol = settings.soundVolume
                let volMultiplier: Float = strength == 1 ? 0.6 : (strength == 3 ? 1.3 : 1.0)

                self.triggerHaptic(strength: strength, pattern: pattern, customGain: dynamicGain)
                AudioEngine.shared.playScrollTick(style: style, volume: baseVol * volMultiplier)
            }
        }

        self.inertiaTimer = timer
        timer.resume()
    }

    private func startCGEventTap() {
        let eventMask = (1 << CGEventType.scrollWheel.rawValue) |
                        (1 << CGEventType.leftMouseDown.rawValue) |
                        (1 << CGEventType.rightMouseDown.rawValue) |
                        (1 << CGEventType.leftMouseUp.rawValue) |
                        (1 << CGEventType.rightMouseUp.rawValue)

        let selfPtr = Unmanaged.passUnretained(self).toOpaque()

        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: CGEventMask(eventMask),
            callback: { (proxy, type, event, refcon) -> Unmanaged<CGEvent>? in
                guard let refcon = refcon else { return Unmanaged.passUnretained(event) }
                let engine = Unmanaged<HapticEngine>.fromOpaque(refcon).takeUnretainedValue()
                engine.handleCGEvent(type: type, event: event)
                return Unmanaged.passUnretained(event)
            },
            userInfo: selfPtr
        ) else {
            startGlobalNSEventMonitor()
            return
        }

        self.eventTap = tap
        let runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        self.runLoopSource = runLoopSource
        CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)

        startGlobalNSEventMonitor()
    }

    private func startGlobalNSEventMonitor() {
        if globalMonitor != nil { return }
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.scrollWheel, .leftMouseDown, .rightMouseDown, .leftMouseUp, .rightMouseUp]) { [weak self] event in
            guard let self = self else { return }
            let type: CGEventType
            switch event.type {
            case .scrollWheel: type = .scrollWheel
            case .leftMouseDown: type = .leftMouseDown
            case .rightMouseDown: type = .rightMouseDown
            case .leftMouseUp: type = .leftMouseUp
            case .rightMouseUp: type = .rightMouseUp
            default: return
            }
            if let cgEvent = event.cgEvent {
                self.handleCGEvent(type: type, event: cgEvent)
            }
        }
    }

    func triggerTestHaptic(strength: Int, pattern: NSHapticFeedbackManager.FeedbackPattern) {
        triggerHaptic(strength: strength, pattern: pattern)
    }

    func triggerHaptic(strength: Int, pattern: NSHapticFeedbackManager.FeedbackPattern, customGain: Float? = nil) {
        if let actuator = actuatorRef, let actuate = mtActuate {
            if let isOpen = mtIsOpen, !isOpen(actuator).boolValue {
            } else {
                let actID: Int32 = strength == 1 ? 2 : (strength == 3 ? 3 : 6)
                let gain: Float = customGain ?? (strength == 1 ? 0.9 : (strength == 3 ? 2.4 : 1.6))
                _ = actuate(actuator, actID, 0, gain, 1.0)
            }
        }

        switch strength {
        case 1:
            NSHapticFeedbackManager.defaultPerformer.perform(.generic, performanceTime: .now)
        case 3:
            NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .now)
        default:
            NSHapticFeedbackManager.defaultPerformer.perform(.levelChange, performanceTime: .now)
        }
    }

    private func handleCGEvent(type: CGEventType, event: CGEvent) {
        let settings = SettingsManager.shared

        if type == .leftMouseDown || type == .rightMouseDown {
            stopInertiaSimulation()
            if settings.isClickHapticsEnabled && (settings.clickFeedbackMode == 0 || settings.clickFeedbackMode == 1) {
                let now = Date()
                if now.timeIntervalSince(lastTickTime) < 0.012 { return }
                lastTickTime = now

                let strength = settings.hapticStrength
                let pattern = settings.hapticPattern
                let baseVol = settings.soundVolume
                let volMultiplier: Float = strength == 1 ? 0.6 : (strength == 3 ? 1.3 : 1.0)
                
                DispatchQueue.main.async {
                    self.triggerHaptic(strength: strength, pattern: pattern)
                    AudioEngine.shared.playClickSound(volume: baseVol * volMultiplier)
                }
            }
            return
        }

        if type == .leftMouseUp || type == .rightMouseUp {
            if settings.isClickHapticsEnabled && (settings.clickFeedbackMode == 0 || settings.clickFeedbackMode == 2) {
                let now = Date()
                if now.timeIntervalSince(lastTickTime) < 0.012 { return }
                lastTickTime = now

                let strength = settings.hapticStrength
                let pattern: NSHapticFeedbackManager.FeedbackPattern = .levelChange
                let baseVol = settings.soundVolume
                let volMultiplier: Float = strength == 1 ? 0.4 : (strength == 3 ? 0.9 : 0.65)
                let releaseGain: Float = strength == 1 ? 0.6 : (strength == 3 ? 1.6 : 1.0)
                
                DispatchQueue.main.async {
                    self.triggerHaptic(strength: strength, pattern: pattern, customGain: releaseGain)
                    AudioEngine.shared.playClickSound(volume: baseVol * volMultiplier)
                }
            }
            return
        }

        if type == .scrollWheel {
            guard settings.isScrollHapticsEnabled else { return }

            let scrollPhase = event.getIntegerValueField(CGEventField(rawValue: 99)!)
            let momentumPhase = event.getIntegerValueField(CGEventField(rawValue: 123)!)

            let pointDelta = Double(event.getIntegerValueField(.scrollWheelEventPointDeltaAxis1))
            let rawDelta = Double(event.getIntegerValueField(.scrollWheelEventDeltaAxis1))
            let fixedDeltaField = CGEventField(rawValue: 93)!
            let fixedDelta = event.getDoubleValueField(fixedDeltaField)

            var deltaY: Double = 0.0
            if abs(fixedDelta) > 0.0001 {
                deltaY = fixedDelta
            } else if abs(pointDelta) > 0.0001 {
                deltaY = pointDelta
            } else {
                deltaY = rawDelta * 6.0
            }

            let absDelta = abs(deltaY)

            if absDelta > 0.001 {
                let now = Date()
                let dt = max(0.005, now.timeIntervalSince(lastScrollTime))
                lastScrollTime = now
                let instVel = absDelta / dt
                recentVelocity = max(recentVelocity * 0.4, instVel)
            }

            if scrollPhase == 1 || scrollPhase == 2 {
                stopInertiaSimulation()
            }

            if scrollPhase == 4 || momentumPhase == 1 || momentumPhase == 2 {
                if recentVelocity > 20.0 && inertiaTimer == nil {
                    let vel = recentVelocity
                    recentVelocity = 0.0
                    startInertiaSimulation(initialVelocity: vel)
                }
                if inertiaTimer != nil { return }
            }

            guard absDelta > 0.001 else { return }

            if inertiaTimer == nil {
                let strength = settings.hapticStrength
                let baseSensitivity = settings.scrollSensitivity
                let (stepThreshold, dynamicGain) = computeDynamicStepThreshold(baseSensitivity: baseSensitivity, strength: strength, velocity: recentVelocity)

                accumulatedDeltaY += absDelta

                if accumulatedDeltaY >= stepThreshold {
                    if Date().timeIntervalSince(lastTickTime) < 0.004 { return }
                    lastTickTime = Date()
                    accumulatedDeltaY = 0.0

                    let pattern = settings.hapticPattern
                    let style = settings.soundStyleRaw
                    let baseVol = settings.soundVolume
                    let volMultiplier: Float = strength == 1 ? 0.6 : (strength == 3 ? 1.3 : 1.0)

                    DispatchQueue.main.async {
                        self.triggerHaptic(strength: strength, pattern: pattern, customGain: dynamicGain)
                        AudioEngine.shared.playScrollTick(style: style, volume: baseVol * volMultiplier)
                    }
                }
            }
        }
    }
}
