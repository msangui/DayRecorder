import Foundation

final class Logger {
    static let shared = Logger()

    private let fileURL: URL
    private let queue = DispatchQueue(label: "com.dayrecorder.logger")

    private init() {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            .appendingPathComponent("DayRecorder")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        fileURL = dir.appendingPathComponent("dayrecorder.log")
    }

    func log(_ message: String) {
        let line = "[\(ISO8601DateFormatter().string(from: Date()))] \(message)\n"
        print(line, terminator: "")
        queue.async {
            if let data = line.data(using: .utf8) {
                if let handle = try? FileHandle(forWritingTo: self.fileURL) {
                    handle.seekToEndOfFile()
                    handle.write(data)
                    try? handle.close()
                } else {
                    try? data.write(to: self.fileURL)
                }
            }
        }
    }
}
