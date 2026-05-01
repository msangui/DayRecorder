import AVFoundation
import Accelerate

// Engine graph is intentionally minimal to avoid all format negotiation:
//
//   inputNode ──[nil tap, hardware format]──→ AVAudioConverter ──→ AVAudioFile (AAC 44100 2ch)
//                                                                          ↑
//   SCStream PCM ──[scheduleSystemBuffer]──→ queue ──→ vDSP mix ──────────┘
//
//   mainMixerNode ──→ outputNode  (untouched; inputNode is disconnected from it
//                                  so there is no mic monitoring through speakers)
//
// Tapping inputNode with format:nil is the only tap that is guaranteed to work
// regardless of hardware sample rate or channel count. AVAudioConverter then
// handles every combination (mono/stereo, 8kHz–192kHz, etc.) in one place.
final class AudioMixerService {
    private var engine: AVAudioEngine?
    private var audioFile: AVAudioFile?
    private var micConverter: AVAudioConverter?
    private var sysConverter: AVAudioConverter?

    // Thread-safe queue of system-audio buffers (already converted to outputFormat).
    private var sysQueue = [AVAudioPCMBuffer]()
    private let sysLock = NSLock()

    private(set) var outputURL: URL?

    // Single target format for the output file.
    static let outputFormat = AVAudioFormat(
        commonFormat: .pcmFormatFloat32,
        sampleRate: 44100, channels: 2, interleaved: false
    )!

    func setup(outputURL: URL) throws {
        self.outputURL = outputURL

        let engine = AVAudioEngine()

        // Disconnect inputNode from mainMixerNode so mic audio never reaches the
        // speakers. This is a no-op if the connection doesn't exist yet, so it's safe.
        engine.disconnectNodeOutput(engine.inputNode)

        // inputFormat(forBus:) returns the true hardware format before prepare().
        // This is the ONLY reliable way to know the real channel count + sample rate.
        let hwFmt = engine.inputNode.inputFormat(forBus: 0)
        Logger.shared.log("Mic HW format: \(hwFmt)")

        let target = Self.outputFormat
        guard let conv = AVAudioConverter(from: hwFmt, to: target) else {
            throw RecordingError.outputSetupFailed
        }
        micConverter = conv

        let fileSettings: [String: Any] = [
            AVFormatIDKey: kAudioFormatMPEG4AAC,
            AVSampleRateKey: target.sampleRate,
            AVNumberOfChannelsKey: target.channelCount,
            AVEncoderBitRateKey: 192_000
        ]
        let file = try AVAudioFile(forWriting: outputURL,
                                   settings: fileSettings,
                                   commonFormat: target.commonFormat,
                                   interleaved: target.isInterleaved)
        self.audioFile = file

        // format: nil — engine delivers buffers exactly in the hardware format.
        // No engine-side conversion is attempted, so no -10865/-10868 errors.
        engine.inputNode.installTap(onBus: 0, bufferSize: 4096, format: nil) { [weak self] buf, _ in
            self?.handleMicBuffer(buf)
        }

        engine.prepare()
        try engine.start()
        self.engine = engine
    }

    // Receives PCM from SystemAudioCaptureService. Converts to outputFormat and
    // enqueues for mixing in the next mic tap callback.
    func scheduleSystemBuffer(_ buffer: AVAudioPCMBuffer) {
        let target = Self.outputFormat
        if sysConverter == nil || sysConverter?.inputFormat != buffer.format {
            sysConverter = AVAudioConverter(from: buffer.format, to: target)
        }
        guard let conv = sysConverter,
              let converted = resample(buffer, using: conv, to: target) else { return }
        sysLock.lock()
        sysQueue.append(converted)
        sysLock.unlock()
    }

    private func handleMicBuffer(_ raw: AVAudioPCMBuffer) {
        let target = Self.outputFormat
        guard let conv = micConverter,
              let mic = resample(raw, using: conv, to: target) else { return }

        // Drain any pending system-audio and mix it into the mic buffer.
        sysLock.lock()
        let pending = sysQueue
        sysQueue.removeAll(keepingCapacity: true)
        sysLock.unlock()

        if !pending.isEmpty {
            mix(pending, into: mic)
        }

        do {
            try audioFile?.write(from: mic)
        } catch {
            Logger.shared.log("Audio write error: \(error)")
        }
    }

    // Adds PCM samples from sources into dest in-place using vDSP, then clamps
    // to [-1, 1] to prevent clipping.
    private func mix(_ sources: [AVAudioPCMBuffer], into dest: AVAudioPCMBuffer) {
        let chCount = Int(dest.format.channelCount)
        let destFrames = Int(dest.frameLength)
        var sysOffset = 0
        for src in sources {
            let frames = min(Int(src.frameLength), destFrames - sysOffset)
            if frames <= 0 { break }
            for ch in 0..<chCount {
                guard let d = dest.floatChannelData?[ch],
                      let s = src.floatChannelData?[ch] else { continue }
                vDSP_vadd(d + sysOffset, 1, s, 1, d + sysOffset, 1, vDSP_Length(frames))
                var lo: Float = -1, hi: Float = 1
                vDSP_vclip(d + sysOffset, 1, &lo, &hi, d + sysOffset, 1, vDSP_Length(frames))
            }
            sysOffset += frames
        }
    }

    private func resample(_ input: AVAudioPCMBuffer,
                           using converter: AVAudioConverter,
                           to format: AVAudioFormat) -> AVAudioPCMBuffer? {
        let ratio = format.sampleRate / input.format.sampleRate
        let capacity = AVAudioFrameCount(Double(input.frameLength) * ratio + 1)
        guard let output = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: capacity) else { return nil }
        var error: NSError?
        var consumed = false
        let status = converter.convert(to: output, error: &error) { _, flag in
            if consumed { flag.pointee = .noDataNow; return nil }
            flag.pointee = .haveData
            consumed = true
            return input
        }
        guard status != .error else {
            Logger.shared.log("Resample error: \(error?.localizedDescription ?? "unknown")")
            return nil
        }
        return output
    }

    func finalize(completion: @escaping (TimeInterval) -> Void) {
        guard let engine = engine else { completion(0); return }
        engine.inputNode.removeTap(onBus: 0)
        engine.stop()
        audioFile = nil          // flushes and closes the AAC file
        micConverter = nil
        sysConverter = nil
        sysLock.lock(); sysQueue.removeAll(); sysLock.unlock()
        let url = outputURL
        self.engine = nil
        self.outputURL = nil
        guard let url else { completion(0); return }
        let asset = AVURLAsset(url: url)
        completion(max(0, CMTimeGetSeconds(asset.duration)))
    }

    func reset() {
        engine?.inputNode.removeTap(onBus: 0)
        engine?.stop()
        audioFile = nil
        micConverter = nil
        sysConverter = nil
        sysLock.lock(); sysQueue.removeAll(); sysLock.unlock()
        engine = nil
        outputURL = nil
    }
}
