import Foundation

/// Service nén và giải nén ZIP sử dụng công cụ ditto native của macOS
final class ArchiveService: @unchecked Sendable {
    static let shared = ArchiveService()
    private init() {}

    /// Nén một hoặc nhiều file/thư mục thành file .zip
    func compress(paths: [String], destinationZip: String) -> Bool {
        guard !paths.isEmpty else { return false }

        if paths.count == 1, let path = paths.first {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/ditto")
            process.arguments = ["-c", "-k", "--sequesterRsrc", "--keepParent", path, destinationZip]
            do {
                try process.run()
                process.waitUntilExit()
                return process.terminationStatus == 0
            } catch {
                return false
            }
        } else {
            // Nén nhiều mục: tạo thư mục tạm chứa symlink hoặc copy, sau đó nén
            let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
            try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)

            for path in paths {
                let name = (path as NSString).lastPathComponent
                let linkURL = tempDir.appendingPathComponent(name)
                try? FileManager.default.copyItem(at: URL(fileURLWithPath: path), to: linkURL)
            }

            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/ditto")
            process.arguments = ["-c", "-k", "--sequesterRsrc", tempDir.path, destinationZip]
            do {
                try process.run()
                process.waitUntilExit()
                try? FileManager.default.removeItem(at: tempDir)
                return process.terminationStatus == 0
            } catch {
                try? FileManager.default.removeItem(at: tempDir)
                return false
            }
        }
    }

    /// Giải nén file .zip vào thư mục chỉ định
    func extract(zipPath: String, to destinationFolder: String) -> Bool {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/ditto")
        process.arguments = ["-x", "-k", zipPath, destinationFolder]
        do {
            try process.run()
            process.waitUntilExit()
            return process.terminationStatus == 0
        } catch {
            return false
        }
    }
}
