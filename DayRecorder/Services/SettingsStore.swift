import Foundation
import Combine

final class SettingsStore: ObservableObject {
    static let shared = SettingsStore()

    private let defaults = UserDefaults.standard

    @Published var outputDirectory: URL {
        didSet { save() }
    }

    @Published var autoSplitInterval: AutoSplitInterval {
        didSet { save() }
    }

    @Published var autoStartOnLaunch: Bool {
        didSet { save() }
    }

    @Published var autoDetectMeetings: Bool {
        didSet { save() }
    }

    private static var defaultOutputDirectory: URL {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        return docs.appendingPathComponent("DayRecorder")
    }

    private init() {
        if let bookmarkData = defaults.data(forKey: "outputDirectoryBookmark") {
            var stale = false
            let resolved = try? URL(resolvingBookmarkData: bookmarkData,
                                    options: .withSecurityScope,
                                    relativeTo: nil,
                                    bookmarkDataIsStale: &stale)
            if let resolved = resolved {
                outputDirectory = resolved
            } else {
                outputDirectory = Self.defaultOutputDirectory
            }
        } else if let pathString = defaults.string(forKey: "outputDirectory") {
            outputDirectory = URL(fileURLWithPath: pathString)
        } else {
            outputDirectory = Self.defaultOutputDirectory
        }

        let splitRaw = defaults.integer(forKey: "autoSplitInterval")
        autoSplitInterval = AutoSplitInterval(rawValue: splitRaw) ?? .off
        autoStartOnLaunch = defaults.bool(forKey: "autoStartOnLaunch")
        autoDetectMeetings = defaults.bool(forKey: "autoDetectMeetings")

        ensureOutputDirectoryExists()
    }

    func ensureOutputDirectoryExists() {
        try? FileManager.default.createDirectory(at: outputDirectory,
                                                  withIntermediateDirectories: true)
    }

    func setOutputDirectory(_ url: URL) {
        _ = url.startAccessingSecurityScopedResource()
        if let bookmark = try? url.bookmarkData(options: .withSecurityScope) {
            defaults.set(bookmark, forKey: "outputDirectoryBookmark")
        }
        defaults.set(url.path, forKey: "outputDirectory")
        outputDirectory = url
        ensureOutputDirectoryExists()
    }

    private func save() {
        defaults.set(autoSplitInterval.rawValue, forKey: "autoSplitInterval")
        defaults.set(autoStartOnLaunch, forKey: "autoStartOnLaunch")
        defaults.set(autoDetectMeetings, forKey: "autoDetectMeetings")
    }
}
