//
//  BrightnessController.swift
//  NoHUD
//

import CoreGraphics
import Darwin
import Foundation

final class BrightnessController {
    private var displayServicesHandle: UnsafeMutableRawPointer?
    private var canChangeBrightnessFunc: (@convention(c) (CGDirectDisplayID) -> Bool)?
    private var getBrightnessFunc: (@convention(c) (CGDirectDisplayID, UnsafeMutablePointer<Float>) -> kern_return_t)?
    private var setBrightnessFunc: (@convention(c) (CGDirectDisplayID, Float) -> kern_return_t)?

    init() {
        loadDisplayServices()
    }

    deinit {
        close()
    }

    func close() {
        if let handle = displayServicesHandle {
            dlclose(handle)
            displayServicesHandle = nil
        }
    }

    var isAvailable: Bool { setBrightnessFunc != nil }

    func getBuiltinDisplayID() -> CGDirectDisplayID? {
        var displayCount: UInt32 = 0
        var result = CGGetActiveDisplayList(0, nil, &displayCount)
        if result != .success || displayCount == 0 { return nil }

        var activeDisplays = [CGDirectDisplayID](repeating: 0, count: Int(displayCount))
        result = CGGetActiveDisplayList(displayCount, &activeDisplays, &displayCount)
        if result != .success { return nil }

        for display in activeDisplays.prefix(Int(displayCount)) {
            if CGDisplayIsBuiltin(display) != 0 {
                return display
            }
        }

        return nil
    }

    func canChangeBrightness(displayID: CGDirectDisplayID) -> Bool {
        guard let canChange = canChangeBrightnessFunc else { return false }
        return canChange(displayID)
    }

    func getCurrentBrightness(displayID: CGDirectDisplayID) -> Float? {
        guard let getBrightness = getBrightnessFunc else { return nil }
        var brightness: Float = 0.0
        let result = getBrightness(displayID, &brightness)
        guard result == KERN_SUCCESS else { return nil }
        return brightness
    }

    @discardableResult
    func setBrightness(_ brightness: Float, displayID: CGDirectDisplayID) -> Float? {
        guard let setBrightness = setBrightnessFunc else { return nil }
        let clampedBrightness = max(0.0, min(1.0, brightness))
        let result = setBrightness(displayID, clampedBrightness)
        guard result == KERN_SUCCESS else { return nil }
        return getCurrentBrightness(displayID: displayID)
    }

    // MARK: Private

    private func loadDisplayServices() {
        guard
            let handle = dlopen(
                "/System/Library/PrivateFrameworks/DisplayServices.framework/DisplayServices",
                RTLD_LAZY
            )
        else {
            return
        }

        guard
            let canChangeBrightnessPtr = dlsym(handle, "DisplayServicesCanChangeBrightness"),
            let getBrightnessPtr = dlsym(handle, "DisplayServicesGetBrightness"),
            let setBrightnessPtr = dlsym(handle, "DisplayServicesSetBrightness")
        else {
            dlclose(handle)
            return
        }

        displayServicesHandle = handle
        canChangeBrightnessFunc = unsafeBitCast(
            canChangeBrightnessPtr,
            to: (@convention(c) (CGDirectDisplayID) -> Bool).self
        )
        getBrightnessFunc = unsafeBitCast(
            getBrightnessPtr,
            to: (@convention(c) (CGDirectDisplayID, UnsafeMutablePointer<Float>) -> kern_return_t).self
        )
        setBrightnessFunc = unsafeBitCast(
            setBrightnessPtr,
            to: (@convention(c) (CGDirectDisplayID, Float) -> kern_return_t).self
        )
    }
}


