import CoreAudio
import Combine

// Detects when any process activates the default audio input device.
// Uses kAudioDevicePropertyDeviceIsRunningSomewhere so it works with any app —
// Zoom, Teams, FaceTime, browser-based calls, etc. — without hardcoding bundle IDs.
//
// Limitation: once DayRecorder itself starts recording it also holds the mic, so
// isMicrophoneActive stays true and cannot signal meeting end. Auto-stop must be
// handled externally (manual stop, auto-split, etc.).
final class MicrophoneActivityService: ObservableObject {
    static let shared = MicrophoneActivityService()

    @Published private(set) var isMicrophoneActive = false

    private var inputDevice: AudioDeviceID = kAudioObjectUnknown
    private var isMonitoring = false

    // Retained blocks so we can pass the same pointer to Remove.
    private var runningListenerBlock: AudioObjectPropertyListenerBlock?
    private var deviceSwitchBlock: AudioObjectPropertyListenerBlock?

    private init() {}

    func startMonitoring() {
        guard !isMonitoring else { return }
        isMonitoring = true
        listenForDeviceSwitch()
        updateInputDevice()
    }

    func stopMonitoring() {
        guard isMonitoring else { return }
        isMonitoring = false
        removeRunningListener(from: inputDevice)
        removeDeviceSwitchListener()
        inputDevice = kAudioObjectUnknown
        isMicrophoneActive = false
    }

    // MARK: - Private

    private func updateInputDevice() {
        let newDevice = defaultInputDevice()
        guard newDevice != inputDevice else {
            refreshState()
            return
        }
        removeRunningListener(from: inputDevice)
        inputDevice = newDevice
        addRunningListener(to: newDevice)
        refreshState()
    }

    private func refreshState() {
        guard inputDevice != kAudioObjectUnknown else {
            isMicrophoneActive = false
            return
        }
        var running: UInt32 = 0
        var size = UInt32(MemoryLayout<UInt32>.size)
        var addr = runningAddr()
        AudioObjectGetPropertyData(inputDevice, &addr, 0, nil, &size, &running)
        let active = running != 0
        DispatchQueue.main.async { [weak self] in self?.isMicrophoneActive = active }
    }

    private func addRunningListener(to device: AudioDeviceID) {
        guard device != kAudioObjectUnknown else { return }
        var addr = runningAddr()
        let block: AudioObjectPropertyListenerBlock = { [weak self] _, _ in
            self?.refreshState()
        }
        runningListenerBlock = block
        AudioObjectAddPropertyListenerBlock(device, &addr, DispatchQueue.main, block)
    }

    private func removeRunningListener(from device: AudioDeviceID) {
        guard device != kAudioObjectUnknown, let block = runningListenerBlock else { return }
        var addr = runningAddr()
        AudioObjectRemovePropertyListenerBlock(device, &addr, DispatchQueue.main, block)
        runningListenerBlock = nil
    }

    private func listenForDeviceSwitch() {
        var addr = defaultDeviceAddr()
        let block: AudioObjectPropertyListenerBlock = { [weak self] _, _ in
            self?.updateInputDevice()
        }
        deviceSwitchBlock = block
        AudioObjectAddPropertyListenerBlock(
            AudioObjectID(kAudioObjectSystemObject), &addr, DispatchQueue.main, block)
    }

    private func removeDeviceSwitchListener() {
        guard let block = deviceSwitchBlock else { return }
        var addr = defaultDeviceAddr()
        AudioObjectRemovePropertyListenerBlock(
            AudioObjectID(kAudioObjectSystemObject), &addr, DispatchQueue.main, block)
        deviceSwitchBlock = nil
    }

    private func defaultInputDevice() -> AudioDeviceID {
        var id = AudioDeviceID(kAudioObjectUnknown)
        var size = UInt32(MemoryLayout<AudioDeviceID>.size)
        var addr = defaultDeviceAddr()
        AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject), &addr, 0, nil, &size, &id)
        return id
    }

    private func runningAddr() -> AudioObjectPropertyAddress {
        AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyDeviceIsRunningSomewhere,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain)
    }

    private func defaultDeviceAddr() -> AudioObjectPropertyAddress {
        AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultInputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain)
    }
}
