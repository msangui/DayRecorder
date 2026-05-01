import Foundation

enum FileNaming {
    static func filename(for title: String, date: Date = Date()) -> String {
        let dateStr = datePrefix(from: date)
        let sanitized = sanitize(title: title)
        let base = sanitized.isEmpty ? "Recording" : sanitized
        return "\(dateStr)_\(base).m4a"
    }

    static func sanitize(title: String) -> String {
        let illegal = CharacterSet(charactersIn: "/\\:*?\"<>|")
        return title
            .components(separatedBy: illegal)
            .joined(separator: "_")
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "  ", with: " ")
    }

    static func datePrefix(from date: Date) -> String {
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd_HH-mm"
        return fmt.string(from: date)
    }

    static func uniqueURL(in directory: URL, filename: String) -> URL {
        var url = directory.appendingPathComponent(filename)
        guard FileManager.default.fileExists(atPath: url.path) else { return url }

        let base = url.deletingPathExtension().lastPathComponent
        let ext = url.pathExtension
        var counter = 2
        repeat {
            url = directory.appendingPathComponent("\(base)_\(counter).\(ext)")
            counter += 1
        } while FileManager.default.fileExists(atPath: url.path)
        return url
    }
}
