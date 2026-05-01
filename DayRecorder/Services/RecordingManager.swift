import Foundation
import AVFoundation
import Combine

@MainActor
final class RecordingManager: ObservableObject {
    static let shared = RecordingManager()

    @Published private(set) var status: RecordingStatus = .idle
    @Published private(set) var elapsedTime: TimeInterval = 0
    @Published private(set) var currentOutputPath: String = ""
    @Published var pendingTitle: String = ""
    @Published var systemAudioAvailable: Bool = false
    @Published var systemAudioError: String? = nil

    private let mixer = AudioMixerService()
    private let library = RecordingLibraryStore.shared
    private let settings = SettingsStore.shared

    private var sysAudio: AnyObject? = nil   // SystemAudioCaptureService (macOS 13+)

    private var timer: Timer?
    private var currentRecordingID: UUID?
    private var autoSplitTimer: Timer?

    private init() {
        if #available(macOS 13.0, *) {
            sysAudio = SystemAudioCaptureService()
        }
    }

    func startRecording() async {
        guard status == .idle else { return }
        status = .recording

        let title = pendingTitle.trimmingCharacters(in: .whitespaces)
        let id = UUID()
        currentRecordingID = id
        let filename = FileNaming.filename(for: title)
        let outputURL = FileNaming.uniqueURL(in: settings.outputDirectory, filename: filename)
        currentOutputPath = outputURL.path

        do {
            try mixer.setup(outputURL: outputURL)
        } catch {
            Logger.shared.log("Audio engine setup failed: \(error)")
            status = .idle
            return
        }

        // Start system audio capture
        if #available(macOS 13.0, *), let sys = sysAudio as? SystemAudioCaptureService {
            do {
                try await sys.start { [weak self] pcm in
                    self?.mixer.scheduleSystemBuffer(pcm)
                }
                systemAudioAvailable = true
                systemAudioError = nil
            } catch {
                systemAudioAvailable = false
                systemAudioError = error.localizedDescription
                Logger.shared.log("System audio start failed: \(error)")
            }
        }

        let rec = Recording(
            id: id,
            title: title.isEmpty ? "Recording" : title,
            filename: outputURL.lastPathComponent,
            createdAt: Date(),
            duration: 0,
            fileSize: 0,
            filePath: outputURL.path
        )
        library.add(rec)

        elapsedTime = 0
        startTimer()
        scheduleAutoSplit()
    }

    func stopRecording() async {
        guard status == .recording || status == .paused else { return }
        status = .stopping

        stopTimer()
        autoSplitTimer?.invalidate()
        autoSplitTimer = nil

        if #available(macOS 13.0, *), let sys = sysAudio as? SystemAudioCaptureService {
            await sys.stop()
        }

        let id = currentRecordingID
        mixer.finalize { [weak self] duration in
            Task { @MainActor in
                if let id = id {
                    self?.library.updateDuration(id, duration: duration)
                }
                self?.status = .idle
                self?.elapsedTime = 0
                self?.currentOutputPath = ""
                self?.pendingTitle = ""
                self?.currentRecordingID = nil
                self?.mixer.reset()
            }
        }
    }

    func pauseRecording() {
        guard status == .recording else { return }
        status = .paused
        stopTimer()
    }

    func resumeRecording() {
        guard status == .paused else { return }
        status = .recording
        startTimer()
    }

    private func startTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.elapsedTime += 1 }
        }
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }

    private func scheduleAutoSplit() {
        let interval = settings.autoSplitInterval
        guard interval != .off else { return }
        let seconds = TimeInterval(interval.rawValue * 60)
        autoSplitTimer = Timer.scheduledTimer(withTimeInterval: seconds, repeats: false) { [weak self] _ in
            Task { @MainActor in
                await self?.stopRecording()
                await self?.startRecording()
            }
        }
    }
}
