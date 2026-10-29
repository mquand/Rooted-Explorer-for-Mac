import Foundation
import SwiftUI
import AppKit

/// Thông tin một bản release trên GitHub.
struct GitHubRelease: Decodable, Identifiable {
    struct Asset: Decodable, Identifiable {
        let id: Int
        let name: String
        let browserDownloadURL: URL
        let size: Int

        enum CodingKeys: String, CodingKey {
            case id, name, size
            case browserDownloadURL = "browser_download_url"
        }
    }

    let id: Int
    let tagName: String
    let name: String?
    let body: String?
    let htmlURL: URL
    let publishedAt: String?
    let assets: [Asset]

    enum CodingKeys: String, CodingKey {
        case id, name, body, assets
        case tagName = "tag_name"
        case htmlURL = "html_url"
        case publishedAt = "published_at"
    }

    /// "v0.2.0" -> "0.2.0"
    var displayVersion: String {
        tagName.hasPrefix("v") ? String(tagName.dropFirst()) : tagName
    }

    var zipAsset: Asset? {
        assets.first { $0.name.lowercased().hasSuffix(".zip") }
    }

    /// Ghi chú release, bỏ các dòng trống thừa.
    var summary: String {
        let text = (body ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        return text.isEmpty ? "Bug fixes and improvements." : text
    }
}

enum UpdateError: LocalizedError {
    case invalidResponse
    case noAsset
    case cannotInstall(String)
    case commandFailed(String)

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "GitHub trả về dữ liệu không hợp lệ."
        case .noAsset:
            return "Bản release không có file .zip để cập nhật."
        case .cannotInstall(let reason):
            return reason
        case .commandFailed(let command):
            return "Lệnh thất bại: \(command)"
        }
    }
}

enum UpdateStatus: Equatable {
    case idle
    case checking
    case upToDate
    case downloading
    case installing
    case failed(String)

    var message: String? {
        switch self {
        case .idle: return nil
        case .checking: return "Đang kiểm tra bản cập nhật…"
        case .upToDate: return "Bạn đang dùng bản mới nhất."
        case .downloading: return "Đang tải bản cập nhật…"
        case .installing: return "Đang cài đặt, app sẽ tự mở lại…"
        case .failed(let message): return message
        }
    }
}

/// Kiểm tra và tự cài bản cập nhật từ GitHub Releases.
@MainActor
final class UpdateService: ObservableObject {
    static let shared = UpdateService(settings: .shared)

    @Published var availableRelease: GitHubRelease?
    @Published var status: UpdateStatus = .idle
    @Published var lastChecked: Date?

    private let settings: AppSettings
    private let session: URLSession
    private var isChecking = false
    private var didCheckOnLaunch = false

    private let latestReleaseURL = URL(string: "https://api.github.com/repos/mquand/Rooted-Explorer-for-Mac/releases/latest")!

    init(settings: AppSettings) {
        self.settings = settings
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 20
        configuration.timeoutIntervalForResource = 120
        session = URLSession(configuration: configuration)
    }

    var currentVersion: String { settings.currentVersion }

    var isBusy: Bool {
        switch status {
        case .checking, .downloading, .installing: return true
        default: return false
        }
    }

    /// Gọi lúc app khởi động. Không làm phiền người dùng nếu đang dùng bản mới nhất.
    func checkOnLaunch() async {
        guard !didCheckOnLaunch else { return }
        didCheckOnLaunch = true
        guard settings.automaticallyChecksForUpdates else { return }

        // Chờ giao diện ổn định rồi mới gọi mạng.
        try? await Task.sleep(nanoseconds: 2_000_000_000)
        await checkForUpdates(userInitiated: false)
    }

    func checkForUpdates(userInitiated: Bool) async {
        guard !isChecking else { return }
        isChecking = true
        status = .checking

        defer { isChecking = false }

        do {
            let release = try await fetchLatestRelease()
            lastChecked = Date()

            guard Self.isVersion(release.displayVersion, newerThan: currentVersion) else {
                availableRelease = nil
                status = .upToDate
                return
            }

            if !userInitiated, settings.skippedVersion == release.displayVersion {
                availableRelease = nil
                status = .idle
                return
            }

            availableRelease = release
            status = .idle
        } catch {
            status = .failed(error.localizedDescription)
        }
    }

    func skip(_ release: GitHubRelease) {
        settings.skippedVersion = release.displayVersion
        availableRelease = nil
        status = .idle
    }

    func dismissBanner() {
        availableRelease = nil
    }

    func openReleasePage(_ release: GitHubRelease) {
        NSWorkspace.shared.open(release.htmlURL)
    }

    /// Tải bản mới, giải nén và thay thế app hiện tại rồi tự mở lại.
    func downloadAndInstall(_ release: GitHubRelease) async {
        guard let asset = release.zipAsset else {
            status = .failed(UpdateError.noAsset.localizedDescription)
            openReleasePage(release)
            return
        }

        status = .downloading
        let fileManager = FileManager.default
        let workDirectory = fileManager.temporaryDirectory
            .appendingPathComponent("RootedUpdate-\(UUID().uuidString)", isDirectory: true)

        do {
            try fileManager.createDirectory(at: workDirectory, withIntermediateDirectories: true)

            var request = URLRequest(url: asset.browserDownloadURL)
            request.setValue("Rooted/\(currentVersion)", forHTTPHeaderField: "User-Agent")

            let (downloadedURL, response) = try await session.download(for: request)
            guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
                throw UpdateError.invalidResponse
            }

            let zipURL = workDirectory.appendingPathComponent("Rooted.zip")
            try fileManager.moveItem(at: downloadedURL, to: zipURL)

            let extractDirectory = workDirectory.appendingPathComponent("extract", isDirectory: true)
            try fileManager.createDirectory(at: extractDirectory, withIntermediateDirectories: true)
            try runProcess("/usr/bin/ditto", ["-x", "-k", zipURL.path, extractDirectory.path])

            guard let appURL = try findApp(in: extractDirectory) else {
                throw UpdateError.noAsset
            }

            status = .installing
            try install(appAt: appURL, workDirectory: workDirectory)
        } catch {
            try? fileManager.removeItem(at: workDirectory)
            status = .failed(error.localizedDescription)
        }
    }

    // MARK: - Networking

    private func fetchLatestRelease() async throws -> GitHubRelease {
        var request = URLRequest(url: latestReleaseURL)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue("2022-11-28", forHTTPHeaderField: "X-GitHub-Api-Version")
        request.setValue("Rooted/\(currentVersion)", forHTTPHeaderField: "User-Agent")

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw UpdateError.invalidResponse
        }

        return try JSONDecoder().decode(GitHubRelease.self, from: data)
    }

    // MARK: - Installation

    private func findApp(in directory: URL) throws -> URL? {
        let contents = try FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        )
        return contents.first { $0.pathExtension.lowercased() == "app" }
    }

    private func install(appAt source: URL, workDirectory: URL) throws {
        let destination = Bundle.main.bundleURL.standardizedFileURL
        let destinationParent = destination.deletingLastPathComponent()

        let allowed = destination.path.hasPrefix("/Applications/")
            || destination.path.hasPrefix(NSHomeDirectory() + "/Applications/")

        guard allowed else {
            throw UpdateError.cannotInstall(
                "App đang chạy từ thư mục build. Hãy tải bản mới thủ công từ trang release."
            )
        }

        guard FileManager.default.isWritableFile(atPath: destinationParent.path) else {
            throw UpdateError.cannotInstall(
                "Không có quyền ghi vào \(destinationParent.path). Hãy chuyển app vào /Applications hoặc cập nhật thủ công."
            )
        }

        let scriptURL = workDirectory.appendingPathComponent("install.sh")
        let script = """
        #!/bin/sh
        while /bin/kill -0 \(ProcessInfo.processInfo.processIdentifier) 2>/dev/null; do /bin/sleep 0.2; done
        /bin/rm -rf \(shellQuote(destination.path))
        /usr/bin/ditto \(shellQuote(source.path)) \(shellQuote(destination.path))
        /usr/bin/xattr -dr com.apple.quarantine \(shellQuote(destination.path)) 2>/dev/null
        /usr/bin/open \(shellQuote(destination.path))
        /bin/rm -rf \(shellQuote(workDirectory.path))
        """

        try script.write(to: scriptURL, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: scriptURL.path)

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/sh")
        process.arguments = [scriptURL.path]
        try process.run()

        // Thoát để script thay thế bundle và mở lại app.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            NSApp.terminate(nil)
        }
    }

    private func runProcess(_ executable: String, _ arguments: [String]) throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments

        let errorPipe = Pipe()
        process.standardError = errorPipe
        process.standardOutput = Pipe()

        try process.run()
        process.waitUntilExit()

        guard process.terminationStatus == 0 else {
            let data = errorPipe.fileHandleForReading.readDataToEndOfFile()
            let message = String(data: data, encoding: .utf8) ?? executable
            throw UpdateError.commandFailed(message.trimmingCharacters(in: .whitespacesAndNewlines))
        }
    }

    private func shellQuote(_ value: String) -> String {
        "'" + value.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }

    // MARK: - Version comparison

    static func isVersion(_ candidate: String, newerThan current: String) -> Bool {
        let lhs = numericComponents(candidate)
        let rhs = numericComponents(current)
        let count = max(lhs.count, rhs.count)

        for index in 0..<count {
            let left = index < lhs.count ? lhs[index] : 0
            let right = index < rhs.count ? rhs[index] : 0
            if left != right { return left > right }
        }
        return false
    }

    private static func numericComponents(_ version: String) -> [Int] {
        version
            .split(separator: ".")
            .map { component in
                let digits = component.prefix { $0.isNumber }
                return Int(digits) ?? 0
            }
    }
}
