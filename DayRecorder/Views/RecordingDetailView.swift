import SwiftUI
import AVKit

struct RecordingDetailView: View {
    let recording: Recording
    @ObservedObject private var library = RecordingLibraryStore.shared
    @State private var player: AVPlayer? = nil
    @State private var isPlaying = false
    @State private var showRename = false
    @State private var renameText = ""

    var body: some View {
        VStack(spacing: 24) {
            waveformIcon
            metadataGrid
            playerControls
            actionButtons
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .sheet(isPresented: $showRename) { renameSheet }
        .onAppear { setupPlayer() }
        .onDisappear { player?.pause() }
    }

    private var waveformIcon: some View {
        Image(systemName: "waveform")
            .font(.system(size: 64))
            .foregroundColor(.accentColor)
    }

    private var metadataGrid: some View {
        Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 8) {
            GridRow {
                label("Title")
                Text(recording.title).fontWeight(.medium)
            }
            GridRow {
                label("Date")
                Text(recording.formattedDate)
            }
            GridRow {
                label("Duration")
                Text(recording.formattedDuration)
            }
            GridRow {
                label("Size")
                Text(recording.formattedSize)
            }
            GridRow {
                label("Path")
                Text(recording.filePath)
                    .font(.caption)
                    .lineLimit(2)
                    .truncationMode(.middle)
            }
        }
    }

    private func label(_ text: String) -> some View {
        Text(text)
            .foregroundColor(.secondary)
            .frame(minWidth: 60, alignment: .trailing)
    }

    private var playerControls: some View {
        HStack(spacing: 20) {
            Button(action: togglePlay) {
                Image(systemName: isPlaying ? "pause.circle.fill" : "play.circle.fill")
                    .font(.system(size: 40))
            }
            .buttonStyle(.borderless)
        }
    }

    private var actionButtons: some View {
        HStack(spacing: 12) {
            Button("Reveal in Finder") {
                NSWorkspace.shared.activateFileViewerSelecting([recording.fileURL])
            }
            Button("Rename") {
                renameText = recording.title
                showRename = true
            }
            Button("Delete", role: .destructive) {
                library.delete(recording)
            }
        }
        .buttonStyle(.bordered)
    }

    private var renameSheet: some View {
        VStack(spacing: 16) {
            Text("Rename Recording").font(.headline)
            TextField("Title", text: $renameText)
                .textFieldStyle(.roundedBorder)
                .frame(width: 300)
            HStack {
                Button("Cancel") { showRename = false }
                Button("Rename") {
                    let t = renameText.trimmingCharacters(in: .whitespaces)
                    if !t.isEmpty { library.rename(recording, to: t) }
                    showRename = false
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(24)
    }

    private func setupPlayer() {
        player = AVPlayer(url: recording.fileURL)
        NotificationCenter.default.addObserver(forName: .AVPlayerItemDidPlayToEndTime,
                                               object: player?.currentItem,
                                               queue: .main) { _ in
            isPlaying = false
            player?.seek(to: .zero)
        }
    }

    private func togglePlay() {
        guard let player else { return }
        if isPlaying {
            player.pause()
        } else {
            player.play()
        }
        isPlaying.toggle()
    }
}
