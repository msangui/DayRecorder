import ScreenCaptureKit
import AVFoundation

@available(macOS 13.0, *)
final class SystemAudioCaptureService: NSObject, SCStreamDelegate, SCStreamOutput {
    private var stream: SCStream?
    private var onPCMBuffer: ((AVAudioPCMBuffer) -> Void)?

    func start(onBuffer: @escaping (AVAudioPCMBuffer) -> Void) async throws {
        let content = try await SCShareableContent.current
        guard let display = content.displays.first else {
            throw RecordingError.systemAudioUnavailable
        }
        let filter = SCContentFilter(display: display,
                                     excludingApplications: [],
                                     exceptingWindows: [])
        let config = SCStreamConfiguration()
        config.capturesAudio = true
        config.sampleRate = 44100
        config.channelCount = 2
        // Minimal video to keep the stream valid (required by SCStream)
        config.minimumFrameInterval = CMTime(value: 1, timescale: 1)
        config.width = 2
        config.height = 2

        let stream = SCStream(filter: filter, configuration: config, delegate: self)
        try stream.addStreamOutput(self,
                                   type: .audio,
                                   sampleHandlerQueue: DispatchQueue(label: "com.dayrecorder.sysaudio"))
        try await stream.startCapture()

        self.stream = stream
        self.onPCMBuffer = onBuffer
    }

    func stop() async {
        try? await stream?.stopCapture()
        stream = nil
        onPCMBuffer = nil
    }

    func stream(_ stream: SCStream,
                didOutputSampleBuffer sampleBuffer: CMSampleBuffer,
                of type: SCStreamOutputType) {
        guard type == .audio else { return }
        guard let pcm = sampleBuffer.toAVAudioPCMBuffer() else { return }
        onPCMBuffer?(pcm)
    }

    func stream(_ stream: SCStream, didStopWithError error: Error) {
        Logger.shared.log("System audio stream stopped: \(error)")
    }
}

// MARK: - CMSampleBuffer → AVAudioPCMBuffer

private extension CMSampleBuffer {
    func toAVAudioPCMBuffer() -> AVAudioPCMBuffer? {
        guard let formatDesc = CMSampleBufferGetFormatDescription(self) else { return nil }
        let format = AVAudioFormat(cmAudioFormatDescription: formatDesc)
        let frameCount = AVAudioFrameCount(CMSampleBufferGetNumSamples(self))
        guard frameCount > 0,
              let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else { return nil }
        buffer.frameLength = frameCount
        let status = CMSampleBufferCopyPCMDataIntoAudioBufferList(
            self, at: 0, frameCount: Int32(frameCount), into: buffer.mutableAudioBufferList)
        guard status == noErr else { return nil }
        return buffer
    }
}
