import Foundation
import Combine

final class RecordingLibraryStore: ObservableObject {
    static let shared = RecordingLibraryStore()

    @Published private(set) var recordings: [Recording] = []

    private let settings = SettingsStore.shared
    private var storeURL: URL { settings.outputDirectory.appendingPathComponent("library.json") }

    private init() {
        load()
        reconcile()
    }

    func load() {
        guard let data = try? Data(contentsOf: storeURL),
              let decoded = try? JSONDecoder().decode([Recording].self, from: data) else {
            recordings = []
            return
        }
        recordings = decoded.sorted { $0.createdAt > $1.createdAt }
    }

    func save() {
        guard let data = try? JSONEncoder().encode(recordings) else { return }
        try? data.write(to: storeURL, options: .atomic)
    }

    func add(_ recording: Recording) {
        recordings.insert(recording, at: 0)
        save()
    }

    func delete(_ recording: Recording) {
        try? FileManager.default.removeItem(at: recording.fileURL)
        recordings.removeAll { $0.id == recording.id }
        save()
    }

    func rename(_ recording: Recording, to newTitle: String) {
        guard let idx = recordings.firstIndex(where: { $0.id == recording.id }) else { return }
        let old = recordings[idx]
        let newFilename = FileNaming.filename(for: newTitle, date: old.createdAt)
        let newURL = FileNaming.uniqueURL(in: old.fileURL.deletingLastPathComponent(), filename: newFilename)
        do {
            try FileManager.default.moveItem(at: old.fileURL, to: newURL)
            recordings[idx].title = newTitle
            recordings[idx].filename = newURL.lastPathComponent
            recordings[idx].filePath = newURL.path
            save()
        } catch {
            Logger.shared.log("Rename failed: \(error)")
        }
    }

    func updateDuration(_ id: UUID, duration: TimeInterval) {
        guard let idx = recordings.firstIndex(where: { $0.id == id }) else { return }
        recordings[idx].duration = duration
        updateFileSize(id: id)
        save()
    }

    private func updateFileSize(id: UUID) {
        guard let idx = recordings.firstIndex(where: { $0.id == id }) else { return }
        let url = recordings[idx].fileURL
        if let attrs = try? FileManager.default.attributesOfItem(atPath: url.path),
           let size = attrs[.size] as? Int64 {
            recordings[idx].fileSize = size
        }
    }

    func reconcile() {
        let fm = FileManager.default
        let dir = settings.outputDirectory

        // Remove entries where file no longer exists
        recordings = recordings.filter { fm.fileExists(atPath: $0.filePath) }

        // Find m4a files not tracked
        guard let contents = try? fm.contentsOfDirectory(at: dir, includingPropertiesForKeys: [.fileSizeKey, .creationDateKey]) else { return }
        let knownPaths = Set(recordings.map { $0.filePath })
        for url in contents where url.pathExtension == "m4a" && !knownPaths.contains(url.path) {
            let attrs = try? url.resourceValues(forKeys: [.fileSizeKey, .creationDateKey])
            let size = Int64(attrs?.fileSize ?? 0)
            let date = attrs?.creationDate ?? Date()
            let title = url.deletingPathExtension().lastPathComponent
            let rec = Recording(
                id: UUID(),
                title: title,
                filename: url.lastPathComponent,
                createdAt: date,
                duration: 0,
                fileSize: size,
                filePath: url.path
            )
            recordings.append(rec)
        }
        recordings.sort { $0.createdAt > $1.createdAt }
        save()
    }
}
