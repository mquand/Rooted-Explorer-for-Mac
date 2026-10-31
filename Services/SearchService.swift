import Foundation

/// Một dòng kết quả tìm kiếm: file + (tuỳ chọn) dòng/cặp match trong nội dung.
struct SearchHit: Identifiable, Hashable {
    var file: FileItem
    let line: Int?
    let text: String?

    var id: String {
        line.map { "\(file.path)#\($0)" } ?? file.path
    }
}

/// Tìm file theo tên, theo tag hoặc tìm nội dung, bằng công cụ dòng lệnh có sẵn:
/// Spotlight (`mdfind`) cho tên/tag, ripgrep hoặc grep cho nội dung.
///
/// Mọi tiến trình đều chạy nền; kết quả cũ bị loại bằng generation ở ViewModel.
final class SearchService {
    static let shared = SearchService()

    private init() {}

    private static let resultLimit = 500

    private struct CachedResult {
        let hits: [SearchHit]
        let date: Date
    }

    private let cacheLock = NSLock()
    private var cache: [String: CachedResult] = [:]
    private let cacheLifetime: TimeInterval = 300 // 5 minutes

    private func cacheKey(for query: String, scope: String, path: String) -> String {
        "\(scope)|\(query)|\(path)"
    }

    private func getCachedResult(key: String) -> [SearchHit]? {
        cacheLock.lock()
        defer { cacheLock.unlock() }

        guard let cached = cache[key],
              Date().timeIntervalSince(cached.date) < cacheLifetime else {
            cache.removeValue(forKey: key)
            return nil
        }
        return cached.hits
    }

    private func setCachedResult(key: String, hits: [SearchHit]) {
        cacheLock.lock()
        defer { cacheLock.unlock() }
        cache[key] = CachedResult(hits: hits, date: Date())
    }

    // MARK: - Tìm theo tên

    func searchByName(_ query: String, in path: String) async -> [SearchHit] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }

        let key = cacheKey(for: trimmed, scope: "name", path: path)
        if let cached = getCachedResult(key: key) {
            return cached
        }

        var paths: [String] = []

        if let output = await Self.run(
            "/usr/bin/mdfind",
            ["-onlyin", path, "-name", trimmed],
            allowNoMatch: true
        ) {
            paths = Self.lines(output)
        }

        // Spotlight có thể không index thư mục này — rơi về `find`.
        if paths.isEmpty {
            if let output = await Self.run(
                "/usr/bin/find",
                [path, "-iname", "*\(Self.sanitize(trimmed))*", "-not", "-path", "*/.*"],
                allowNoMatch: true
            ) {
                paths = Self.lines(output)
            }
        }

        let hits = await filesToHits(Array(paths.prefix(Self.resultLimit)))
        setCachedResult(key: key, hits: hits)
        return hits
    }

    // MARK: - Tìm theo tag

    func searchByTag(_ tag: FinderTag, in path: String) async -> [SearchHit] {
        let query = "kMDItemUserTags == '\(Self.sanitize(tag.name))'c"
        let key = cacheKey(for: tag.name, scope: "tag", path: path)

        if let cached = getCachedResult(key: key) {
            return cached
        }

        guard let output = await Self.run(
            "/usr/bin/mdfind",
            ["-onlyin", path, query],
            allowNoMatch: true
        ) else {
            return []
        }

        let paths = Self.lines(output)
        let hits = await filesToHits(Array(paths.prefix(Self.resultLimit)))
        setCachedResult(key: key, hits: hits)
        return hits
    }

    // MARK: - Tìm nội dung

    func searchContent(_ query: String, in path: String) async -> [SearchHit] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }

        let key = cacheKey(for: trimmed, scope: "content", path: path)
        if let cached = getCachedResult(key: key) {
            return cached
        }

        let arguments = ["--line-number", "--no-heading", "--color=never", "--max-columns=300", "-e", trimmed, path]

        var output: String?
        if let ripgrep = Self.resolveExecutable("rg") {
            output = await Self.run(ripgrep, arguments, allowNoMatch: true)
        }

        if output == nil {
            output = await Self.run(
                "/usr/bin/grep",
                ["-rn", "--exclude-dir=node_modules", "--exclude-dir=.git", "-e", trimmed, path],
                allowNoMatch: true
            )
        }

        guard let output else { return [] }
        let hits = await matchToHits(Self.parseMatches(output))
        setCachedResult(key: key, hits: hits)
        return hits
    }

    // MARK: - Helpers

    private func filesToHits(_ paths: [String]) async -> [SearchHit] {
        guard !paths.isEmpty else { return [] }

        let items: [FileItem] = await Task.detached(priority: .userInitiated) {
            FileItem.fromPaths(paths)
        }.value

        return items.map { SearchHit(file: $0, line: nil, text: nil) }
    }

    private func matchToHits(_ matches: [(path: String, line: Int, text: String)]) async -> [SearchHit] {
        guard !matches.isEmpty else { return [] }

        let grouped = Dictionary(grouping: matches, by: \.path)

        let items = await Task.detached(priority: .userInitiated) {
            FileItem.fromPaths(Array(grouped.keys))
        }.value

        return items.map { item in
            if let first = grouped[item.path]?.first {
                return SearchHit(file: item, line: first.line, text: first.text)
            }
            return SearchHit(file: item, line: nil, text: nil)
        }
    }

    private static func lines(_ output: String) -> [String] {
        output.components(separatedBy: .newlines).filter { !$0.isEmpty }
    }

    private static func sanitize(_ query: String) -> String {
        query
            .replacingOccurrences(of: "\"", with: "")
            .replacingOccurrences(of: "'", with: "")
    }

    /// Parse output kiểu `đường-dòng:dòng:cặp-match` (dùng chung cho rg và grep).
    private static func parseMatches(_ output: String) -> [(path: String, line: Int, text: String)] {
        var results: [(path: String, line: Int, text: String)] = []
        results.reserveCapacity(64)

        for raw in output.components(separatedBy: .newlines) {
            let line = raw.trimmingCharacters(in: .whitespaces)
            guard !line.isEmpty else { continue }

            let parts = line.split(separator: ":", maxSplits: 2)
            guard parts.count >= 3, let number = Int(parts[1]) else { continue }

            if results.count >= Self.resultLimit { break }

            results.append((path: String(parts[0]), line: number, text: String(parts[2])))
        }

        return results
    }

    /// Tìm executable trong PATH của GUI app (thường ngắn) + các vị trí hay dùng.
    static func resolveExecutable(_ name: String) -> String? {
        var directories = (ProcessInfo.processInfo.environment["PATH"] ?? "")
            .components(separatedBy: ":")
        directories += ["/opt/homebrew/bin", "/usr/local/bin", "/usr/bin", "/bin"]

        for directory in directories where !directory.isEmpty {
            let candidate = (directory as NSString).appendingPathComponent(name)
            if FileManager.default.isExecutableFile(atPath: candidate) {
                return candidate
            }
        }
        return nil
    }

    /// Chạy tiến trình nền, trả về stdout. `nil` nếu không chạy được hoặc exit
    /// khác 0 (trừ khi `allowNoMatch` cho phép exit 1 — "không có kết quả").
    private static func run(
        _ executable: String,
        _ arguments: [String],
        allowNoMatch: Bool = false
    ) async -> String? {
        await Task.detached(priority: .userInitiated) { () -> String? in
            let task = Process()
            task.executableURL = URL(fileURLWithPath: executable)
            task.arguments = arguments
            task.standardOutput = Pipe()
            task.standardError = FileHandle.nullDevice

            guard let pipe = task.standardOutput as? Pipe else { return nil }

            do {
                try task.run()
            } catch {
                return nil
            }

            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            task.waitUntilExit()

            let status = task.terminationStatus
            guard status == 0 || (allowNoMatch && status == 1) else { return nil }

            return String(data: data, encoding: .utf8) ?? ""
        }.value
    }
}
