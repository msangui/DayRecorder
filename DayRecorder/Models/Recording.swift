import Foundation

struct Recording: Identifiable, Codable, Hashable {
    var id: UUID
    var title: String
    var filename: String
    var createdAt: Date
    var duration: TimeInterval
    var fileSize: Int64
    var filePath: String

    var fileURL: URL { URL(fileURLWithPath: filePath) }

    var formattedDuration: String {
        let total = Int(duration)
        let h = total / 3600
        let m = (total % 3600) / 60
        let s = total % 60
        if h > 0 {
            return String(format: "%d:%02d:%02d", h, m, s)
        }
        return String(format: "%d:%02d", m, s)
    }

    var formattedSize: String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB, .useGB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: fileSize)
    }

    var formattedDate: String {
        let fmt = DateFormatter()
        fmt.dateStyle = .medium
        fmt.timeStyle = .short
        return fmt.string(from: createdAt)
    }
}
