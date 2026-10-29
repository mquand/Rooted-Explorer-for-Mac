import Foundation
import SwiftUI

/// Service để phân tích dung lượng ổ đĩa và thư mục
class DiskUsageService {
    static let shared = DiskUsageService()
    
    private init() {}
    
    /// Lấy thông tin tất cả volumes
    func getAllVolumes() -> [VolumeInfo] {
        var volumes: [VolumeInfo] = []
        
        let volumesPath = "/Volumes"
        guard let contents = try? FileManager.default.contentsOfDirectory(atPath: volumesPath) else {
            return volumes
        }
        
        for volumeName in contents {
            if volumeName == "." || volumeName == ".." { continue }
            
            let volumePath = (volumesPath as NSString).appendingPathComponent(volumeName)
            if let info = getVolumeInfo(at: volumePath) {
                volumes.append(info)
            }
        }
        
        return volumes
    }
    
    /// Lấy thông tin một volume
    func getVolumeInfo(at path: String) -> VolumeInfo? {
        let fm = FileManager.default
        
        guard let attributes = try? fm.attributesOfItem(atPath: path) else {
            return nil
        }
        
        let totalSpace = attributes[.systemSize] as? UInt64 ?? 0
        let freeSpace = attributes[.systemFreeSize] as? UInt64 ?? 0
        let usedSpace = totalSpace - freeSpace
        
        return VolumeInfo(
            name: (path as NSString).lastPathComponent,
            path: path,
            totalSpace: totalSpace,
            freeSpace: freeSpace,
            usedSpace: usedSpace,
            isMounted: true
        )
    }
    
    /// Phân tích dung lượng thư mục (đệ quy)
    func analyzeDirectory(at path: String, completion: @escaping (DirectoryUsage) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async {
            let usage = self.calculateDirectoryUsage(at: path)
            DispatchQueue.main.async {
                completion(usage)
            }
        }
    }
    
    /// Tính dung lượng thư mục (đệ quy)
    private func calculateDirectoryUsage(at path: String) -> DirectoryUsage {
        let fm = FileManager.default
        var totalSize: UInt64 = 0
        var fileCount = 0
        var folderCount = 0
        var subdirectories: [DirectoryUsage] = []
        
        guard let contents = try? fm.contentsOfDirectory(atPath: path) else {
            return DirectoryUsage(
                path: path,
                name: (path as NSString).lastPathComponent,
                size: 0,
                fileCount: 0,
                folderCount: 0,
                subdirectories: []
            )
        }
        
        for item in contents {
            if item == "." || item == ".." { continue }
            
            let itemPath = (path as NSString).appendingPathComponent(item)
            var isDir: ObjCBool = false
            fm.fileExists(atPath: itemPath, isDirectory: &isDir)
            
            if isDir.boolValue {
                folderCount += 1
                // Recursive analyze subdirectory
                let subUsage = calculateDirectoryUsage(at: itemPath)
                totalSize += subUsage.size
                fileCount += subUsage.fileCount
                folderCount += subUsage.folderCount
                subdirectories.append(subUsage)
            } else {
                fileCount += 1
                if let attributes = try? fm.attributesOfItem(atPath: itemPath) {
                    totalSize += attributes[.size] as? UInt64 ?? 0
                }
            }
        }
        
        // Sort subdirectories by size (descending)
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
    
    /// Quét các thư mục dev rác (node_modules, .venv, __pycache__, etc.)
    func scanDevJunk(at basePath: String, completion: @escaping ([DevJunkItem]) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async {
            let junkItems = self.findDevJunk(at: basePath)
            DispatchQueue.main.async {
                completion(junkItems)
            }
        }
    }
    
    private func findDevJunk(at path: String) -> [DevJunkItem] {
        var junkItems: [DevJunkItem] = []
        let fm = FileManager.default
        
        let junkPatterns = [
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
        
        func scanDirectory(_ currentPath: String) {
            guard let contents = try? fm.contentsOfDirectory(atPath: currentPath) else { return }
            
            for item in contents {
                if item == "." || item == ".." { continue }
                
                let itemPath = (currentPath as NSString).appendingPathComponent(item)
                var isDir: ObjCBool = false
                fm.fileExists(atPath: itemPath, isDirectory: &isDir)
                
                if isDir.boolValue {
                    if junkPatterns.contains(item) {
                        if let size = getDirectorySize(at: itemPath) {
                            junkItems.append(DevJunkItem(
                                path: itemPath,
                                name: item,
                                type: junkType(for: item),
                                size: size
                            ))
                        }
                    } else {
                        scanDirectory(itemPath)
                    }
                }
            }
        }
        
        scanDirectory(path)
        return junkItems
    }
    
    private func getDirectorySize(at path: String) -> UInt64? {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/du")
        task.arguments = ["-s", path]
        
        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = pipe
        
        do {
            try task.run()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: data, encoding: .utf8) ?? ""
            let parts = output.split(separator: "\t")
            if let sizeStr = parts.first {
                return UInt64(sizeStr.trimmingCharacters(in: .whitespaces)) ?? 0
            }
        } catch {}
        
        return nil
    }
    
    private func junkType(for name: String) -> DevJunkType {
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
