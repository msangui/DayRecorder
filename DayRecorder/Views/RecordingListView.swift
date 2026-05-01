import SwiftUI
import AVKit

struct RecordingListView: View {
    @ObservedObject private var library = RecordingLibraryStore.shared
    @Binding var selected: Recording?
    @State private var searchText = ""
    @State private var renamingID: UUID? = nil
    @State private var renameText = ""

    var filtered: [Recording] {
        if searchText.isEmpty { return library.recordings }
        return library.recordings.filter {
            $0.title.localizedCaseInsensitiveContains(searchText) ||
            $0.filename.localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            searchBar
            Divider()
            if filtered.isEmpty {
                emptyState
            } else {
                List(filtered, selection: $selected) { rec in
                    recordingRow(rec)
                        .tag(rec)
                }
                .listStyle(.sidebar)
            }
        }
    }

    private var searchBar: some View {
        HStack {
            Image(systemName: "magnifyingglass").foregroundColor(.secondary)
            TextField("Search recordings", text: $searchText)
                .textFieldStyle(.plain)
        }
        .padding(8)
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: "waveform").font(.system(size: 48)).foregroundColor(.secondary)
            Text("No recordings yet").foregroundColor(.secondary)
            Spacer()
        }
    }

    @ViewBuilder
    private func recordingRow(_ rec: Recording) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            if renamingID == rec.id {
                TextField("Title", text: $renameText, onCommit: { commitRename(rec) })
                    .textFieldStyle(.roundedBorder)
                    .onExitCommand { renamingID = nil }
            } else {
                Text(rec.title)
                    .fontWeight(.medium)
                    .lineLimit(1)
            }
            HStack {
                Text(rec.formattedDate).font(.caption).foregroundColor(.secondary)
                Spacer()
                Text(rec.formattedDuration).font(.caption).foregroundColor(.secondary)
                Text(rec.formattedSize).font(.caption).foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 2)
        .contextMenu { contextMenu(for: rec) }
    }

    @ViewBuilder
    private func contextMenu(for rec: Recording) -> some View {
        Button("Play") { play(rec) }
        Button("Reveal in Finder") { revealInFinder(rec) }
        Button("Rename") { beginRename(rec) }
        Divider()
        Button("Delete", role: .destructive) { library.delete(rec) }
    }

    private func play(_ rec: Recording) {
        NSWorkspace.shared.open(rec.fileURL)
    }

    private func revealInFinder(_ rec: Recording) {
        NSWorkspace.shared.activateFileViewerSelecting([rec.fileURL])
    }

    private func beginRename(_ rec: Recording) {
        renameText = rec.title
        renamingID = rec.id
    }

    private func commitRename(_ rec: Recording) {
        let trimmed = renameText.trimmingCharacters(in: .whitespaces)
        if !trimmed.isEmpty {
            library.rename(rec, to: trimmed)
        }
        renamingID = nil
    }
}
