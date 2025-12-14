//
//  AudioController.swift
//  NoHUD
//

import AudioToolbox
import CoreAudio
import Foundation

struct AudioController {
    /// Get the default output audio device ID.
    func getDefaultOutputDevice() -> AudioDeviceID? {
        var deviceID: AudioDeviceID = kAudioObjectUnknown
        var size = UInt32(MemoryLayout<AudioDeviceID>.size)
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )

        let status = AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject),
            &address,
            0,
            nil,
            &size,
            &deviceID
        )

        guard status == noErr, deviceID != kAudioObjectUnknown else {
            return nil
        }

        return deviceID
    }

    /// Get the current volume (0.0 to 1.0).
    func getCurrentVolume(deviceID: AudioDeviceID) -> Float? {
        var volume: Float = 0.0
        var size = UInt32(MemoryLayout<Float>.size)
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwareServiceDeviceProperty_VirtualMainVolume,
            mScope: kAudioDevicePropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain
        )

        let status = AudioObjectGetPropertyData(
            deviceID,
            &address,
            0,
            nil,
            &size,
            &volume
        )

        guard status == noErr else { return nil }
        return volume
    }

    /// Set the volume (0.0 to 1.0). Returns the actual volume after setting.
    @discardableResult
    func setVolume(_ volume: Float, deviceID: AudioDeviceID) -> Float? {
        var newVolume = max(0.0, min(1.0, volume))
        let size = UInt32(MemoryLayout<Float>.size)
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwareServiceDeviceProperty_VirtualMainVolume,
            mScope: kAudioDevicePropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain
        )

        let status = AudioObjectSetPropertyData(
            deviceID,
            &address,
            0,
            nil,
            size,
            &newVolume
        )

        guard status == noErr else { return nil }
        return getCurrentVolume(deviceID: deviceID)
    }

    /// Get the current mute state.
    func getMuteState(deviceID: AudioDeviceID) -> Bool? {
        var muted: UInt32 = 0
        var size = UInt32(MemoryLayout<UInt32>.size)
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyMute,
            mScope: kAudioDevicePropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain
        )

        let status = AudioObjectGetPropertyData(
            deviceID,
            &address,
            0,
            nil,
            &size,
            &muted
        )

        guard status == noErr else { return nil }
        return muted != 0
    }

    /// Set the mute state.
    @discardableResult
    func setMuteState(_ muted: Bool, deviceID: AudioDeviceID) -> Bool {
        var muteValue: UInt32 = muted ? 1 : 0
        let size = UInt32(MemoryLayout<UInt32>.size)
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyMute,
            mScope: kAudioDevicePropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain
        )

        let status = AudioObjectSetPropertyData(
            deviceID,
            &address,
            0,
            nil,
            size,
            &muteValue
        )

        return status == noErr
    }
}


