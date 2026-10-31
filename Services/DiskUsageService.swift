import Foundation

/// Phân tích dung lượng volume, thư mục và quét "rác" dev (node_modules, .venv…).
///
/// Mọi hàm quét đều chạy nền và hủy được (`Task.checkCancellation()` giữa chừng),
/// nên đóng sheet khi quét đang chạy sẽ dừng quét thật sự.
final class DiskUsageService: @unchecked Sendable {
    static let shared = DiskUsageService()

    private init() {}

    // MARK: - Volumes

    /// Thông tin các volume đang mount (bao gồm ổ khởi động).
    func getAllVolumes() -> [VolumeInfo] {
        let keys: Set<URLResourceKey> = [
            .volumeNameKey,
            .volumeTotalCapacityKey,
            .volumeAvailableCapacityKey,
            .volumeIsBrowsableKey
        ]

        let urls = FileManager.default.mountedVolumeURLs(
            includingResourceValuesForKeys: Array(keys),
            options: [.skipHiddenVolumes]
        ) ?? []

        let volumes: [VolumeInfo] = urls.compactMap { url in
            guard let values = try? url.resourceValues(forKeys: keys),
                  values.volumeIsBrowsable != false else {
                return nil
            }

            let total = UInt64(values.volumeTotalCapacity ?? 0)
            let free = UInt64(values.volumeAvailableCapacity ?? 0)

            return VolumeInfo(
                name: values.volumeName ?? url.lastPathComponent,
                path: url.path,
                totalSpace: total,
                freeSpace: free,
                usedSpace: total > free ? total - free : 0,
                isMounted: true
            )
        }

        return volumes.sorted { lhs, rhs in
            if lhs.path == "/" { return true }
            if rhs.path == "/" { return false }
            return lhs.name.localizedStandardCompare(rhs.name) == .orderedAscending
        }
    }

    // MARK: - Dung lượng

    /// Dung lượng thực tế trên đĩa của thư mục (kèm cả file ẩn như `.git`).
    /// Dùng allocated size để khớp với số Finder hiển thị.
    static func directorySize(at path: String) async -> UInt64 {
        let task = Task.detached(priority: .userInitiated) {
            Self.calculateDirectorySize(at: path)
        }
        return await withTaskCancellationHandler(operation: {
            await task.value
        }, onCancel: {
            task.cancel()
        })
    }

    private static func calculateDirectorySize(at path: String) -> UInt64 {
        let url = URL(fileURLWithPath: path, isDirectory: true)
        let keys: Set<URLResourceKey> = [
            .totalFileAllocatedSizeKey,
            .fileAllocatedSizeKey,
            .isRegularFileKey
        ]

        guard let enumerator = FileManager.default.enumerator(
            at: url,
            includingPropertiesForKeys: Array(keys),
            options: [.skipsPackageDescendants],
            errorHandler: nil
        ) else {
            return 0
        }

        var total: UInt64 = 0
        var visited = 0

        for case let fileURL as URL in enumerator {
            visited += 1
            if visited.isMultiple(of: 4096) {
                // Check cancellation mỗi 4096 file
                let cancelled = withUnsafeCurrentTask { $0?.isCancelled ?? false }
                if cancelled { break }
            }

            guard let values = try? fileURL.resourceValues(forKeys: keys),
                  values.isRegularFile == true else {
                continue
            }
            total += UInt64(values.totalFileAllocatedSize ?? values.fileAllocatedSize ?? 0)
        }

        return total
    }

    // MARK: - Phân tích thư mục

    /// Phân tích đệ quy: tổng dung lượng, số file/thư mục và các thư mục con lớn nhất.
    func analyzeDirectory(at path: String) async throws -> DirectoryUsage {
        let task = Task.detached(priority: .userInitiated) {
            try Self.calculateDirectoryUsage(at: path)
        }
        return try await withTaskCancellationHandler(operation: {
            try await task.value
        }, onCancel: {
            task.cancel()
        })
    }

    private static func calculateDirectoryUsage(at path: String) throws -> DirectoryUsage {
        let fileManager = FileManager.default
        var totalSize: UInt64 = 0
        var fileCount = 0
        var folderCount = 0
        var subdirectories: [DirectoryUsage] = []

        let contents = try fileManager.contentsOfDirectory(atPath: path)

        for item in contents {
            try Task.checkCancellation()

            let itemPath = (path as NSString).appendingPathComponent(item)
            var isDirectory: ObjCBool = false
            guard fileManager.fileExists(atPath: itemPath, isDirectory: &isDirectory) else { continue }

            if isDirectory.boolValue {
                folderCount += 1
                let subUsage = try Self.calculateDirectoryUsage(at: itemPath)
                totalSize += subUsage.size
                fileCount += subUsage.fileCount
                folderCount += subUsage.folderCount
                subdirectories.append(subUsage)
            } else {
                fileCount += 1
                if let attributes = try? fileManager.attributesOfItem(atPath: itemPath) {
                    totalSize += attributes[.size] as? UInt64 ?? 0
                }
            }
        }

        subdirectories.sort { $0.size > $1.size }

        return DirectoryUsage(
            path: path,
            name: (path as NSString).lastPathComponent,
            size: totalSize,
            fileCount: fileCount,
            folderCount: folderCount,
            subdirectories: subdirectories
        )
    }

    // MARK: - Dev junk

    /// Quét các thư mục dev rác (node_modules, .venv, DerivedData…) trong `basePath`.
    func scanDevJunk(at basePath: String) async throws -> [DevJunkItem] {
        return try await withTaskCancellationHandler(operation: {
            try await Self.findDevJunk(at: basePath)
        }, onCancel: {
            // Task tự hủy bởi withTaskCancellationHandler
        })
    }

    private static let junkPatterns: Set<String> = [
        "node_modules",
        ".venv",
        "venv",
        "__pycache__",
        ".pytest_cache",
        ".mypy_cache",
        "build",
        "dist",
        ".gradle",
        "target",
        "Pods",
        "DerivedData"
    ]

    private static func findDevJunk(at path: String) async throws -> [DevJunkItem] {
        var junkItems: [DevJunkItem] = []
        let fileManager = FileManager.default

        func scan(_ currentPath: String) async throws {
            let contents = try fileManager.contentsOfDirectory(atPath: currentPath)

            for item in contents {
                try Task.checkCancellation()

                let itemPath = (currentPath as NSString).appendingPathComponent(item)
                var isDirectory: ObjCBool = false
                guard fileManager.fileExists(atPath: itemPath, isDirectory: &isDirectory),
                      isDirectory.boolValue else {
                    continue
                }

                if junkPatterns.contains(item) {
                    let size = await directorySize(at: itemPath)
                    junkItems.append(DevJunkItem(
                        path: itemPath,
                        name: item,
                        type: junkType(for: item),
                        size: size
                    ))
                } else {
                    try await scan(itemPath)
                }
            }
        }

        try await scan(path)
        junkItems.sort { $0.size > $1.size }
        return junkItems
    }

    private static func junkType(for name: String) -> DevJunkType {
        switch name {
        case "node_modules": return .nodeModules
        case ".venv", "venv": return .pythonVenv
        case "__pycache__", ".pytest_cache", ".mypy_cache": return .pythonCache
        case "build", "dist": return .pythonBuild
        case ".gradle": return .gradle
        case "target": return .rustTarget
        case "Pods": return .cocoapods
        case "DerivedData": return .xcodeDerivedData
        default: return .other
        }
    }
}

struct VolumeInfo: Identifiable {
    let id = UUID()
    let name: String
    let path: String
    let totalSpace: UInt64
    let freeSpace: UInt64
    let usedSpace: UInt64
    let isMounted: Bool

    var usedPercentage: Double {
        guard totalSpace > 0 else { return 0 }
        return Double(usedSpace) / Double(totalSpace) * 100
    }

    var formattedTotalSpace: String {
        ByteCountFormatter.string(fromByteCount: Int64(totalSpace), countStyle: .file)
    }

    var formattedFreeSpace: String {
        ByteCountFormatter.string(fromByteCount: Int64(freeSpace), countStyle: .file)
    }

    var formattedUsedSpace: String {
        ByteCountFormatter.string(fromByteCount: Int64(usedSpace), countStyle: .file)
    }
}

struct DirectoryUsage: Identifiable {
    let id = UUID()
    let path: String
    let name: String
    let size: UInt64
    let fileCount: Int
    let folderCount: Int
    let subdirectories: [DirectoryUsage]

    var formattedSize: String {
        ByteCountFormatter.string(fromByteCount: Int64(size), countStyle: .file)
    }
}

struct DevJunkItem: Identifiable {
    let id = UUID()
    let path: String
    let name: String
    let type: DevJunkType
    let size: UInt64

    var formattedSize: String {
        ByteCountFormatter.string(fromByteCount: Int64(size), countStyle: .file)
    }
}

enum DevJunkType: String, CaseIterable {
    case nodeModules = "Node Modules"
    case pythonVenv = "Python venv"
    case pythonCache = "Python Cache"
    case pythonBuild = "Python Build"
    case gradle = "Gradle"
    case rustTarget = "Rust Target"
    case cocoapods = "CocoaPods"
    case xcodeDerivedData = "Xcode DerivedData"
    case other = "Other"
}
