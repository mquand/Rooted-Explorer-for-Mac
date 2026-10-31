import Foundation

/// Đọc trạng thái git (branch + badge từng file) của thư mục hiện tại.
///
/// Dùng đúng một tiến trình `git status --porcelain -z --branch` cho mỗi repo,
/// parse dạng NUL-separated để không phụ thuộc quoting tên file, và cache theo
/// repo root để mở/đóng thư mục liên tục không phải chạy git lại.
final class GitService: Sendable {
    nonisolated(unsafe) static let shared = GitService()

    private init() {}

    /// Kết quả cho một repo: branch hiện tại và trạng thái từng file.
    /// `statuses` được key theo full path tuyệt đối của file.
    struct RepositoryState {
        let branch: String?
        let statuses: [String: GitStatus]
    }

    private struct Snapshot {
        let branch: String?
        let statuses: [String: GitStatus]
        let date: Date
    }

    private let lock = NSLock()
    private var cache: [String: Snapshot] = [:]
    private let cacheLifetime: TimeInterval = 30

    /// Trạng thái git cho thư mục `path`. Trả về rỗng nếu không nằm trong repo.
    /// - Parameter useCache: tắt cache khi người dùng bấm Refresh.
    func repositoryState(at path: String, useCache: Bool = true) -> RepositoryState {
        guard let root = gitRoot(at: path) else {
            return RepositoryState(branch: nil, statuses: [:])
        }

        if useCache {
            lock.lock()
            let snapshot = cache[root]
            lock.unlock()

            if let snapshot, Date().timeIntervalSince(snapshot.date) < cacheLifetime {
                return RepositoryState(branch: snapshot.branch, statuses: snapshot.statuses)
            }
        }

        let state = Self.readStatus(repoRoot: root)

        lock.lock()
        cache[root] = Snapshot(branch: state.branch, statuses: state.statuses, date: Date())
        lock.unlock()

        return state
    }

    func invalidateCache() {
        lock.lock()
        cache.removeAll()
        lock.unlock()
    }

    /// Tìm thư mục gốc repo (chứa `.git`) bằng cách đi ngược lên tới `/`.
    func gitRoot(at path: String) -> String? {
        var current = (path as NSString).standardizingPath

        while true {
            let gitPath = (current as NSString).appendingPathComponent(".git")
            // `.git` có thể là thư mục hoặc là file (worktree/submodule).
            if FileManager.default.fileExists(atPath: gitPath) {
                return current
            }

            let parent = (current as NSString).deletingLastPathComponent
            if parent == current || parent.isEmpty {
                return nil
            }
            current = parent
        }
    }

    // MARK: - Đọc trạng thái

    private static func readStatus(repoRoot: String) -> RepositoryState {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/git")
        task.arguments = ["status", "--porcelain=v1", "-z", "--branch"]
        task.currentDirectoryURL = URL(fileURLWithPath: repoRoot)
        task.standardOutput = Pipe()
        task.standardError = FileHandle.nullDevice

        guard let pipe = task.standardOutput as? Pipe else {
            return RepositoryState(branch: nil, statuses: [:])
        }

        do {
            try task.run()
        } catch {
            return RepositoryState(branch: nil, statuses: [:])
        }

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        task.waitUntilExit()

        guard task.terminationStatus == 0 else {
            return RepositoryState(branch: nil, statuses: [:])
        }

        let output = String(data: data, encoding: .utf8) ?? ""
        return parse(output: output, repoRoot: repoRoot)
    }

    static func parse(output: String, repoRoot: String) -> RepositoryState {
        var branch: String?
        var statuses: [String: GitStatus] = [:]
        let entries = output.components(separatedBy: "\0")

        var index = 0
        while index < entries.count {
            let entry = entries[index]
            index += 1

            if entry.isEmpty { continue }

            if entry.hasPrefix("##") {
                branch = parseBranch(String(entry.dropFirst(2)))
                continue
            }

            // Định dạng: "XY <path>" — cần đủ ký tự XY + space.
            guard entry.count >= 4 else { continue }

            let x = entry[entry.startIndex]
            let y = entry[entry.index(entry.startIndex, offsetBy: 1)]
            let relativePath = String(entry.dropFirst(3))

            // Với `-z`, entry sao/chép/đổi tên có thêm một phần tử: đường dẫn cũ.
            if x == "R" || x == "C" || y == "R" || y == "C" {
                index += 1
            }

            let status = Self.status(x: x, y: y)
            guard status != .none, !relativePath.isEmpty else { continue }

            statuses[(repoRoot as NSString).appendingPathComponent(relativePath)] = status
        }

        return RepositoryState(branch: branch, statuses: statuses)
    }

    /// `X` = trạng thái trong index, `Y` = trạng thái ngoài worktree.
    private static func status(x: Character, y: Character) -> GitStatus {
        if x == "?" && y == "?" { return .untracked }

        // Conflict: một nhánh U, hoặc cả hai cùng A/D.
        if x == "U" || y == "U" || (x == "A" && y == "A") || (x == "D" && y == "D") {
            return .conflict
        }

        // Đã stage (index có thay đổi): M/A/T/R/C...
        if x != " " { return .staged }

        // Chưa stage (worktree có thay đổi): M/T/D.
        if y == "M" || y == "T" || y == "D" { return .modified }

        return .none
    }

    private static func parseBranch(_ text: String) -> String? {
        let trimmed = text.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return nil }

        // "main...origin/main [ahead 1]" -> "main"
        if let range = trimmed.range(of: "...") {
            let name = String(trimmed[..<range.lowerBound])
            return name.isEmpty ? nil : name
        }
        return trimmed
    }
}
