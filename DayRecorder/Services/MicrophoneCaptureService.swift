import AVFoundation

// Mic input is now captured by AVAudioEngine.inputNode inside AudioMixerService.
// This class is kept only to hold the shared error type.
final class MicrophoneCaptureService {
    func stop() {}
}

enum RecordingError: LocalizedError {
    case noMicrophoneFound
    case cannotAddMicInput
    case cannotAddMicOutput
    case systemAudioUnavailable
    case outputSetupFailed

    var errorDescription: String? {
        switch self {
        case .noMicrophoneFound: return "No microphone device found."
        case .cannotAddMicInput: return "Cannot add microphone input to capture session."
        case .cannotAddMicOutput: return "Cannot add audio output to capture session."
        case .systemAudioUnavailable: return "System audio capture requires macOS 13+ and Screen Recording permission."
        case .outputSetupFailed: return "Failed to set up the output audio file."
        }
    }
}
