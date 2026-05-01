import Foundation

enum RecordingStatus: String, Equatable {
    case idle
    case recording
    case paused
    case stopping

    var displayName: String {
        switch self {
        case .idle: return "Idle"
        case .recording: return "Recording"
        case .paused: return "Paused"
        case .stopping: return "Stopping"
        }
    }

    var menuBarIcon: String {
        switch self {
        case .idle: return "waveform"
        case .recording: return "waveform.badge.microphone"
        case .paused: return "pause.circle"
        case .stopping: return "stop.circle"
        }
    }
}

enum AutoSplitInterval: Int, CaseIterable, Codable {
    case off = 0
    case thirtyMin = 30
    case sixtyMin = 60
    case twoHours = 120

    var displayName: String {
        switch self {
        case .off: return "Off"
        case .thirtyMin: return "30 min"
        case .sixtyMin: return "60 min"
        case .twoHours: return "120 min"
        }
    }
}
