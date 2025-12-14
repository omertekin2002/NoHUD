//
//  MediaKeySuppressor.swift
//  NoHUD
//
//  Intercepts media key events at the HID level and consumes them so macOS never
//  triggers the system volume/brightness HUD. Since macOS won't handle the keys,
//  we adjust volume/brightness ourselves.
//

import AppKit
import ApplicationServices
import Combine
import CoreAudio
import CoreGraphics
import Foundation
import os

@MainActor
final class MediaKeySuppressor {
    private enum NXKeyType: Int {
        case soundUp = 0
        case soundDown = 1
        case brightnessUp = 2
        case brightnessDown = 3
        case mute = 7
    }

    private static let systemDefinedEventTypeRawValue: Int = 14 // NX_SYSDEFINED / kCGEventSystemDefined

    /// Static callback for CGEvent tap. Bridges to instance method.
    private static let eventTapCallback: CGEventTapCallBack = { _, type, cgEvent, userInfo in
        guard let userInfo else {
            return Unmanaged.passRetained(cgEvent)
        }

        let suppressor = Unmanaged<MediaKeySuppressor>.fromOpaque(userInfo).takeUnretainedValue()

        // Handle tap disabled events
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            Task { @MainActor in
                suppressor.reenableTapIfNeeded()
            }
            return Unmanaged.passRetained(cgEvent)
        }

        // Only handle system-defined events
        guard type.rawValue == MediaKeySuppressor.systemDefinedEventTypeRawValue else {
            return Unmanaged.passRetained(cgEvent)
        }

        // Process the event and determine if we should consume it
        return suppressor.handleEvent(cgEvent)
    }

    private let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "NoHUD",
        category: "MediaKeySuppressor"
    )

    private let audio = AudioController()
    private var brightnessController: BrightnessController?

    /// Standard step (1/16th, matching macOS default)
    private let standardStep: Float = 1.0 / 16.0

    /// Fine step when Option+Shift is held (1/64th)
    private let fineStep: Float = 1.0 / 64.0

    @Published private(set) var isRunning: Bool = false
    @Published private(set) var lastError: String?

    /// Guards access to the nonisolated interception flags which are read on the CGEvent tap thread.
    private nonisolated let interceptionFlagsLock = NSLock()

    /// Whether volume interception is currently working (resets on device change or app restart).
    private nonisolated(unsafe) var volumeInterceptionWorkingStorage: Bool = true
    /// Whether brightness interception is currently working (resets on display change or app restart).
    private nonisolated(unsafe) var brightnessInterceptionWorkingStorage: Bool = true

    var volumeInterceptionWorking: Bool { getVolumeInterceptionWorking() }
    var brightnessInterceptionWorking: Bool { getBrightnessInterceptionWorking() }

    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?

    /// Last known audio device ID for detecting device changes
    private var lastKnownAudioDeviceID: AudioDeviceID = kAudioObjectUnknown
    /// Timer for polling audio device changes
    private var audioDevicePollingTimer: Timer?
    /// Whether we're observing display configuration changes
    private var isObservingDisplayChanges = false

    // MARK: Public

    /// Start intercepting media key events. Returns true if the tap was created.
    @discardableResult
    func start() -> Bool {
        guard !isRunning else { return true }

        // Reset fallback states on start (allows re-testing each launch)
        setInterceptionWorking(volume: true, brightness: true)

        // Check accessibility permissions first
        guard AXIsProcessTrusted() else {
            lastError = "Accessibility permission not granted. NoHUD cannot intercept media keys."
            logger.warning("\(self.lastError ?? "Accessibility not trusted")")
            return false
        }

        // Ensure DisplayServices is available early; if not, allow brightness keys to pass through.
        brightnessController = BrightnessController()
        if brightnessController?.isAvailable != true {
            setBrightnessInterceptionWorking(false)
            logger.warning("DisplayServices unavailable; brightness keys will pass through to system.")
        }

        // Create the event tap (HID level, default tap so we can consume events)
        let systemDefinedMask: CGEventMask = 1 << Self.systemDefinedEventTypeRawValue
        let userInfo = Unmanaged.passUnretained(self).toOpaque()

        guard
            let tap = CGEvent.tapCreate(
                tap: .cghidEventTap,
                place: .headInsertEventTap,
                options: .defaultTap,
                eventsOfInterest: systemDefinedMask,
                callback: MediaKeySuppressor.eventTapCallback,
                userInfo: userInfo
            )
        else {
            lastError = "Failed to create CGEvent tap. Check Accessibility (and possibly Input Monitoring) permissions."
            logger.error("\(self.lastError ?? "Failed to create event tap")")
            brightnessController = nil
            return false
        }

        eventTap = tap
        runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)

        guard let source = runLoopSource else {
            lastError = "Failed to create run loop source for event tap."
            logger.error("\(self.lastError ?? "Failed to create run loop source")")
            eventTap = nil
            brightnessController = nil
            return false
        }

        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)

        isRunning = true
        lastError = nil

        startDeviceChangeMonitoring()
        logger.info("Media key suppression started.")
        return true
    }

    /// Stop intercepting media key events.
    func stop() {
        guard isRunning else { return }

        stopDeviceChangeMonitoring()

        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: false)
        }
        if let source = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes)
        }

        runLoopSource = nil
        eventTap = nil

        brightnessController?.close()
        brightnessController = nil

        isRunning = false
        logger.info("Media key suppression stopped.")
    }

    // MARK: Event handling

    private func reenableTapIfNeeded() {
        guard let tap = eventTap else { return }
        CGEvent.tapEnable(tap: tap, enable: true)
    }

    /// Handle a system-defined CGEvent. Returns nil to consume the event.
    private nonisolated func handleEvent(_ cgEvent: CGEvent) -> Unmanaged<CGEvent>? {
        guard
            let nsEvent = NSEvent(cgEvent: cgEvent),
            nsEvent.type == .systemDefined,
            nsEvent.subtype.rawValue == 8
        else {
            return Unmanaged.passRetained(cgEvent)
        }

        let data1 = nsEvent.data1
        let keyCode = (data1 & 0xFFFF_0000) >> 16
        let keyFlags = data1 & 0x0000_FFFF
        let keyState = (keyFlags & 0xFF00) >> 8

        // 0x0A = key down, 0x0B = key up
        guard keyState == 0x0A else {
            return Unmanaged.passRetained(cgEvent)
        }

        guard let keyType = NXKeyType(rawValue: Int(keyCode)) else {
            return Unmanaged.passRetained(cgEvent)
        }

        // Option+Shift = fine step
        let modifierFlags = nsEvent.modifierFlags
        let useFineStep = modifierFlags.contains(.option) && modifierFlags.contains(.shift)

        let (volumeWorking, brightnessWorking) = getInterceptionWorking()

        switch keyType {
        case .soundUp, .soundDown, .mute:
            guard volumeWorking else {
                return Unmanaged.passRetained(cgEvent)
            }

            Task { @MainActor [weak self] in
                self?.handleVolumeKey(keyType: keyType, useFineStep: useFineStep)
            }
            return nil // consume to suppress system HUD

        case .brightnessUp, .brightnessDown:
            guard brightnessWorking else {
                return Unmanaged.passRetained(cgEvent)
            }

            Task { @MainActor [weak self] in
                self?.handleBrightnessKey(keyType: keyType, useFineStep: useFineStep)
            }
            return nil // consume to suppress system HUD
        }
    }

    // MARK: Private - Key handlers

    private func handleVolumeKey(keyType: NXKeyType, useFineStep: Bool) {
        let step = useFineStep ? fineStep : standardStep

        switch keyType {
        case .soundUp:
            adjustVolume(delta: step)
        case .soundDown:
            adjustVolume(delta: -step)
        case .mute:
            toggleMute()
        default:
            break
        }
    }

    private func handleBrightnessKey(keyType: NXKeyType, useFineStep: Bool) {
        let step = useFineStep ? fineStep : standardStep

        switch keyType {
        case .brightnessUp:
            adjustBrightness(delta: step)
        case .brightnessDown:
            adjustBrightness(delta: -step)
        default:
            break
        }
    }

    // MARK: Private - Volume control

    private func adjustVolume(delta: Float) {
        guard let deviceID = audio.getDefaultOutputDevice() else {
            disableVolumeInterception(reason: "cannot get audio device")
            return
        }

        guard let currentVolume = audio.getCurrentVolume(deviceID: deviceID) else {
            disableVolumeInterception(reason: "cannot read volume")
            return
        }

        // Calculate expected new volume with quantization
        let steps = 1.0 / abs(delta)
        var expectedVolume = currentVolume + delta
        expectedVolume = round(expectedVolume * steps) / steps
        expectedVolume = max(0.0, min(1.0, expectedVolume))

        // Boundary check (where change isn't expected)
        let atBoundary = (currentVolume <= 0.001 && delta < 0) || (currentVolume >= 0.999 && delta > 0)

        // If muted and adjusting volume, unmute first
        if let isMuted = audio.getMuteState(deviceID: deviceID), isMuted, delta != 0 {
            _ = audio.setMuteState(false, deviceID: deviceID)
        }

        guard let actualVolume = audio.setVolume(expectedVolume, deviceID: deviceID) else {
            disableVolumeInterception(reason: "cannot set volume")
            return
        }

        // Verify the change worked (if not at a boundary)
        if !atBoundary {
            let changed = abs(actualVolume - currentVolume) > 0.001
            if !changed {
                disableVolumeInterception(reason: "volume change did not take effect")
            }
        }
    }

    private func toggleMute() {
        guard let deviceID = audio.getDefaultOutputDevice() else {
            disableVolumeInterception(reason: "cannot get audio device")
            return
        }

        guard let isMuted = audio.getMuteState(deviceID: deviceID) else {
            disableVolumeInterception(reason: "cannot read mute state")
            return
        }

        let newMuteState = !isMuted
        guard audio.setMuteState(newMuteState, deviceID: deviceID) else {
            disableVolumeInterception(reason: "cannot set mute state")
            return
        }
    }

    private func disableVolumeInterception(reason: String) {
        guard setVolumeInterceptionWorkingIfNeeded(false) else { return }
        lastError = "Volume interception disabled (\(reason)). Volume keys will pass through to the system HUD."
        logger.warning("\(self.lastError ?? "Volume interception disabled")")
    }

    // MARK: Private - Brightness control

    private func adjustBrightness(delta: Float) {
        guard let controller = brightnessController, controller.isAvailable else {
            disableBrightnessInterception(reason: "DisplayServices not available")
            return
        }

        guard let displayID = controller.getBuiltinDisplayID() else {
            disableBrightnessInterception(reason: "no built-in display found")
            return
        }

        guard controller.canChangeBrightness(displayID: displayID) else {
            disableBrightnessInterception(reason: "display does not support brightness control")
            return
        }

        guard let currentBrightness = controller.getCurrentBrightness(displayID: displayID) else {
            disableBrightnessInterception(reason: "cannot read brightness")
            return
        }

        // Calculate expected new brightness with quantization
        let steps = 1.0 / abs(delta)
        var expectedBrightness = currentBrightness + delta
        expectedBrightness = round(expectedBrightness * steps) / steps
        expectedBrightness = max(0.0, min(1.0, expectedBrightness))

        let atBoundary = (currentBrightness <= 0.001 && delta < 0) || (currentBrightness >= 0.999 && delta > 0)

        guard let actualBrightness = controller.setBrightness(expectedBrightness, displayID: displayID) else {
            disableBrightnessInterception(reason: "cannot set brightness")
            return
        }

        if !atBoundary {
            let changed = abs(actualBrightness - currentBrightness) > 0.001
            if !changed {
                disableBrightnessInterception(reason: "brightness change did not take effect")
            }
        }
    }

    private func disableBrightnessInterception(reason: String) {
        guard setBrightnessInterceptionWorkingIfNeeded(false) else { return }
        lastError = "Brightness interception disabled (\(reason)). Brightness keys will pass through to the system HUD."
        logger.warning("\(self.lastError ?? "Brightness interception disabled")")
    }

    // MARK: Private - Device change monitoring

    private func startDeviceChangeMonitoring() {
        lastKnownAudioDeviceID = audio.getDefaultOutputDevice() ?? kAudioObjectUnknown

        audioDevicePollingTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.checkForAudioDeviceChange()
            }
        }

        guard !isObservingDisplayChanges else { return }
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(displayConfigurationDidChange(_:)),
            name: NSApplication.didChangeScreenParametersNotification,
            object: nil
        )
        isObservingDisplayChanges = true
    }

    private func stopDeviceChangeMonitoring() {
        audioDevicePollingTimer?.invalidate()
        audioDevicePollingTimer = nil

        if isObservingDisplayChanges {
            NotificationCenter.default.removeObserver(
                self,
                name: NSApplication.didChangeScreenParametersNotification,
                object: nil
            )
            isObservingDisplayChanges = false
        }
    }

    private func checkForAudioDeviceChange() {
        guard let currentDeviceID = audio.getDefaultOutputDevice() else { return }

        if currentDeviceID != lastKnownAudioDeviceID {
            logger.info("Default audio device changed: \(self.lastKnownAudioDeviceID) -> \(currentDeviceID)")
            lastKnownAudioDeviceID = currentDeviceID

            // Re-enable volume interception state to re-test with new device
            if setVolumeInterceptionWorkingIfNeeded(true) {
                lastError = nil
                logger.info("Volume interception re-enabled due to audio device change.")
            }
        }
    }

    @objc
    private func displayConfigurationDidChange(_: Notification) {
        // Re-enable brightness interception state to re-test with new display configuration
        if setBrightnessInterceptionWorkingIfNeeded(true) {
            brightnessController = BrightnessController()
            lastError = nil
            logger.info("Brightness interception re-enabled due to display configuration change.")
        }
    }

    // MARK: Nonisolated - Interception Flags (thread-safe)

    private nonisolated func getInterceptionWorking() -> (volume: Bool, brightness: Bool) {
        interceptionFlagsLock.lock()
        defer { interceptionFlagsLock.unlock() }
        return (volumeInterceptionWorkingStorage, brightnessInterceptionWorkingStorage)
    }

    private nonisolated func getVolumeInterceptionWorking() -> Bool {
        interceptionFlagsLock.lock()
        defer { interceptionFlagsLock.unlock() }
        return volumeInterceptionWorkingStorage
    }

    private nonisolated func getBrightnessInterceptionWorking() -> Bool {
        interceptionFlagsLock.lock()
        defer { interceptionFlagsLock.unlock() }
        return brightnessInterceptionWorkingStorage
    }

    private nonisolated func setInterceptionWorking(volume: Bool, brightness: Bool) {
        interceptionFlagsLock.lock()
        volumeInterceptionWorkingStorage = volume
        brightnessInterceptionWorkingStorage = brightness
        interceptionFlagsLock.unlock()
    }

    private nonisolated func setBrightnessInterceptionWorking(_ isWorking: Bool) {
        interceptionFlagsLock.lock()
        brightnessInterceptionWorkingStorage = isWorking
        interceptionFlagsLock.unlock()
    }

    /// Set volume interception working flag if it differs. Returns true if it changed.
    private nonisolated func setVolumeInterceptionWorkingIfNeeded(_ isWorking: Bool) -> Bool {
        interceptionFlagsLock.lock()
        defer { interceptionFlagsLock.unlock() }
        guard volumeInterceptionWorkingStorage != isWorking else { return false }
        volumeInterceptionWorkingStorage = isWorking
        return true
    }

    /// Set brightness interception working flag if it differs. Returns true if it changed.
    private nonisolated func setBrightnessInterceptionWorkingIfNeeded(_ isWorking: Bool) -> Bool {
        interceptionFlagsLock.lock()
        defer { interceptionFlagsLock.unlock() }
        guard brightnessInterceptionWorkingStorage != isWorking else { return false }
        brightnessInterceptionWorkingStorage = isWorking
        return true
    }
}


