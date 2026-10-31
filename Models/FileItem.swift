import Foundation
import SwiftUI
import UniformTypeIdentifiers

struct FileItem: Identifiable, Hashable {
    /// Dùng path làm identity để selection ổn định sau mỗi lần refresh.
    var id: String { path }

    let name: String
    let path: String
    let isDirectory: Bool
    let size: UInt64
    let modified: Date
    let isHidden: Bool
    var gitStatus: GitStatus = .none
    var isSymlink: Bool = false
    var tags: [FinderTag] = []

    /// Đọc một file từ đĩa (kèm tag). Trả về nil nếu không đọc được.
    static func from(path: String) -> FileItem? {
        let fileManager = FileManager.default

        var isDirectory: ObjCBool = false
        guard fileManager.fileExists(atPath: path, isDirectory: &isDirectory) else { return nil }

        let attributes = try? fileManager.attributesOfItem(atPath: path)
        let size = attributes?[.size] as? UInt64 ?? 0
        let modified = attributes?[.modificationDate] as? Date ?? .distantPast
        let isSymlink = (attributes?[.type] as? FileAttributeType) == .typeSymbolicLink
        let name = (path as NSString).lastPathComponent

        return FileItem(
            name: name,
            path: path,
            isDirectory: isDirectory.boolValue,
            size: size,
            modified: modified,
            isHidden: name.hasPrefix("."),
            isSymlink: isSymlink,
            tags: TagService.tags(for: path)
        )
    }

    /// Tạo nhiều FileItem từ nhiều paths (dùng cho search performance).
    static func fromPaths(_ paths: [String]) -> [FileItem] {
        return paths.compactMap { from(path: $0) }
    }

    var icon: String {
        if isSymlink { return "arrow.turn.right" }
        if isDirectory { return "folder.fill" }

        let ext = (name as NSString).pathExtension.lowercased()
        switch ext {
        case "swift", "m", "h": return "swift"
        case "js", "ts", "jsx", "tsx": return "doc.text"
        case "json", "plist": return "doc.text"
        case "md": return "doc.text"
        case "png", "jpg", "jpeg", "gif", "svg", "webp": return "photo"
        case "mp4", "mov": return "video"
        case "mp3", "wav": return "music.note"
        case "zip", "tar", "gz": return "archivebox"
        default: return "doc"
        }
    }

    var iconColor: Color {
        if isSymlink { return .purple }
        if isDirectory { return .blue }

        let ext = (name as NSString).pathExtension.lowercased()
        switch ext {
        case "swift": return .orange
        case "js", "ts", "jsx", "tsx": return .yellow
        case "json", "plist": return .gray
        case "md": return .blue
        case "png", "jpg", "jpeg", "gif", "svg": return .green
        default: return .gray
        }
    }

    var formattedSize: String {
        guard !isDirectory else { return "—" }
        return Self.byteFormatter.string(fromByteCount: Int64(size))
    }

    var formattedDate: String {
        Self.dateFormatter.string(from: modified)
    }

    var kind: String {
        if isSymlink { return "Alias" }
        if isDirectory { return "Folder" }

        let ext = (name as NSString).pathExtension.lowercased()
        guard !ext.isEmpty, let type = UTType(filenameExtension: ext) else {
            return ext.isEmpty ? "Document" : ext.uppercased()
        }
        return type.localizedDescription ?? ext.uppercased()
    }

    private nonisolated(unsafe) static let byteFormatter: ByteCountFormatter = {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB, .useGB]
        formatter.countStyle = .file
        return formatter
    }()

    private nonisolated(unsafe) static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter
    }()
}

enum GitStatus: String, CaseIterable {
    case none = ""
    case modified = "M"
    case untracked = "?"
    case staged = "A"
    case conflict = "!"
}
