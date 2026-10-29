import Foundation
import SwiftUI

/// Service để quản lý Git operations
class GitService {
    static let shared = GitService()
    
    private init() {}
    
    /// Kiểm tra xem path có trong git repo không
    func isGitRepository(at path: String) -> Bool {
        var currentPath = path
        var isDir: ObjCBool = false
        
        while !currentPath.isEmpty && currentPath != "/" {
            let gitPath = (currentPath as NSString).appendingPathComponent(".git")
            if FileManager.default.fileExists(atPath: gitPath, isDirectory: &isDir) {
                return true
            }
            currentPath = (currentPath as NSString).deletingLastPathComponent
        }
        
        return false
    }
    
    /// Lấy git status của một file
    func getStatus(for path: String) -> GitStatus {
        guard isGitRepository(at: path) else { return .none }
        
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/git")
        task.arguments = ["status", "--porcelain", path]
        
        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = pipe
        
        do {
            try task.run()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            
            if output.isEmpty {
                return .none
            }
            
            let statusChar = output.prefix(1)
            switch statusChar {
            case "M":
                return .modified
            case "?":
                return .untracked
            case "A":
                return .staged
            case "U", "AA", "UU":
                return .conflict
            default:
                return .none
            }
        } catch {
            return .none
        }
    }
    
    /// Lấy branch hiện tại của repo
    func getCurrentBranch(at path: String) -> String? {
        guard isGitRepository(at: path) else { return nil }
        
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/git")
        task.arguments = ["branch", "--show-current"]
        task.currentDirectoryURL = URL(fileURLWithPath: path)
        
        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = pipe
        
        do {
            try task.run()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines)
            return output?.isEmpty == false ? output : nil
        } catch {
            return nil
        }
    }
    
    /// Lấy git status cho toàn bộ thư mục
    func getStatusForDirectory(at path: String) -> [String: GitStatus] {
        guard isGitRepository(at: path) else { return [:] }
        
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/git")
        task.arguments = ["status", "--porcelain"]
        task.currentDirectoryURL = URL(fileURLWithPath: path)
        
        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = pipe
        
        do {
            try task.run()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: data, encoding: .utf8) ?? ""
            
            var statusMap: [String: GitStatus] = [:]
            
            for line in output.components(separatedBy: .newlines) {
                let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
                guard trimmed.count >= 3 else { continue }
                
                let statusChar = String(trimmed.prefix(1))
                let fileName = String(trimmed.dropFirst(3))
                
                let status: GitStatus
                switch statusChar {
                case "M":
                    status = .modified
                case "?":
                    status = .untracked
                case "A":
                    status = .staged
                case "U", "AA", "UU":
                    status = .conflict
                default:
                    status = .none
                }
                
                statusMap[fileName] = status
            }
            
            return statusMap
        } catch {
            return [:]
        }
    }
    
    /// Mở git diff view
    func openDiff(for path: String) {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/git")
        task.arguments = ["difftool", path]
        task.currentDirectoryURL = URL(fileURLWithPath: (path as NSString).deletingLastPathComponent)
        try? task.run()
    }
}
