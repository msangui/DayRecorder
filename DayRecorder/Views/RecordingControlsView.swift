import SwiftUI

struct RecordingControlsView: View {
    @ObservedObject private var manager = RecordingManager.shared
    @ObservedObject private var permissions = PermissionsManager.shared

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                titleField
                Spacer()
                timerLabel
                controlButtons
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)

            if let err = manager.systemAudioError {
                systemAudioWarning(err)
            }

            if manager.status != .idle, !manager.currentOutputPath.isEmpty {
                outputPathBar
            }
        }
        .background(Color(NSColor.controlBackgroundColor))
    }

    private var titleField: some View {
        TextField("Recording title (optional)", text: $manager.pendingTitle)
            .textFieldStyle(.roundedBorder)
            .frame(maxWidth: 280)
            .disabled(manager.status != .idle)
    }

    private var timerLabel: some View {
        Text(formattedElapsed)
            .font(.system(.title3, design: .monospaced))
            .foregroundColor(manager.status == .recording ? .red : .secondary)
            .frame(minWidth: 70, alignment: .trailing)
    }

    private var controlButtons: some View {
        HStack(spacing: 8) {
            if manager.status == .idle {
                Button(action: startRecording) {
                    Label("Record", systemImage: "record.circle")
                        .foregroundColor(.red)
                }
                .buttonStyle(.borderedProminent)
                .tint(.red.opacity(0.15))
                .foregroundColor(.red)
                .disabled(!permissions.microphoneGranted)
            } else {
                if manager.status == .recording {
                    Button(action: { manager.pauseRecording() }) {
                        Image(systemName: "pause.circle.fill")
                            .font(.title2)
                    }
                    .buttonStyle(.borderless)
                } else if manager.status == .paused {
                    Button(action: { manager.resumeRecording() }) {
                        Image(systemName: "play.circle.fill")
                            .font(.title2)
                    }
                    .buttonStyle(.borderless)
                }
                Button(action: stopRecording) {
                    Image(systemName: "stop.circle.fill")
                        .font(.title2)
                        .foregroundColor(.red)
                }
                .buttonStyle(.borderless)
                .disabled(manager.status == .stopping)
            }
        }
    }

    private var outputPathBar: some View {
        HStack {
            Image(systemName: "doc.fill")
                .foregroundColor(.secondary)
                .font(.caption)
            Text(manager.currentOutputPath)
                .font(.caption)
                .foregroundColor(.secondary)
                .lineLimit(1)
                .truncationMode(.middle)
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 6)
    }

    private func systemAudioWarning(_ msg: String) -> some View {
        HStack {
            Image(systemName: "speaker.slash.fill")
                .foregroundColor(.orange)
            Text("System audio unavailable: \(msg)")
                .font(.caption)
                .foregroundColor(.orange)
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 4)
    }

    private var formattedElapsed: String {
        let t = Int(manager.elapsedTime)
        let h = t / 3600, m = (t % 3600) / 60, s = t % 60
        if h > 0 { return String(format: "%d:%02d:%02d", h, m, s) }
        return String(format: "%d:%02d", m, s)
    }

    private func startRecording() {
        Task { await manager.startRecording() }
    }

    private func stopRecording() {
        Task { await manager.stopRecording() }
    }
}
