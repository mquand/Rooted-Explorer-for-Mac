import Foundation
import SwiftUI

/// Service để tìm kiếm file và nội dung
class SearchService {
    static let shared = SearchService()
    
    private init() {}
    
    /// Tìm file theo tên (sử dụng Spotlight)
    func searchFilesByName(query: String, inPath path: String, completion: @escaping ([String]) -> Void) {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/mdfind")
        task.arguments = [
            "-onlyin", path,
            "-name", query
        ]
        
        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = pipe
        
        do {
            try task.run()
            
            DispatchQueue.global(qos: .userInitiated).async {
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                let output = String(data: data, encoding: .utf8) ?? ""
                let results = output.components(separatedBy: .newlines)
                    .filter { !$0.isEmpty }
                
                DispatchQueue.main.async {
                    completion(results)
                }
            }
        } catch {
            DispatchQueue.main.async {
                completion([])
            }
        }
    }
    
    /// Tìm file theo tên (sử dụng find command - không dùng Spotlight)
    func searchFilesByNameWithFind(query: String, inPath path: String, completion: @escaping ([String]) -> Void) {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/find")
        task.arguments = [
            path,
            "-iname", "*\(query)*",
            "-not", "-path", "*/.*"  // Ẩn file ẩn
        ]
        
        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = pipe
        
        do {
            try task.run()
            
            DispatchQueue.global(qos: .userInitiated).async {
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                let output = String(data: data, encoding: .utf8) ?? ""
                let results = output.components(separatedBy: .newlines)
                    .filter { !$0.isEmpty }
                
                DispatchQueue.main.async {
                    completion(results)
                }
            }
        } catch {
            DispatchQueue.main.async {
                completion([])
            }
        }
    }
    
    /// Tìm nội dung trong file (sử dụng ripgrep nếu có, fallback grep)
    func searchContent(query: String, inPath path: String, completion: @escaping ([SearchResult]) -> Void) {
        // Thử ripgrep trước
        if isCommandAvailable("rg") {
            searchWithRipgrep(query: query, inPath: path, completion: completion)
        } else {
            searchWithGrep(query: query, inPath: path, completion: completion)
        }
    }
    
    private func searchWithRipgrep(query: String, inPath path: String, completion: @escaping ([SearchResult]) -> Void) {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/opt/homebrew/bin/rg")
        task.arguments = [
            "--line-number",
            "--no-heading",
            "--color=never",
            query,
            path
        ]
        
        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = pipe
        
        do {
            try task.run()
            
            DispatchQueue.global(qos: .userInitiated).async {
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                let output = String(data: data, encoding: .utf8) ?? ""
                let results = self.parseRipgrepOutput(output)
                
                DispatchQueue.main.async {
                    completion(results)
                }
            }
        } catch {
            DispatchQueue.main.async {
                completion([])
            }
        }
    }
    
    private func searchWithGrep(query: String, inPath path: String, completion: @escaping ([SearchResult]) -> Void) {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/grep")
        task.arguments = [
            "-rn",
            "--exclude-dir=node_modules",
            "--exclude-dir=.git",
            query,
            path
        ]
        
        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = pipe
        
        do {
            try task.run()
            
            DispatchQueue.global(qos: .userInitiated).async {
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                let output = String(data: data, encoding: .utf8) ?? ""
                let results = self.parseGrepOutput(output)
                
                DispatchQueue.main.async {
                    completion(results)
                }
            }
        } catch {
            DispatchQueue.main.async {
                completion([])
            }
        }
    }
    
    private func parseRipgrepOutput(_ output: String) -> [SearchResult] {
        var results: [SearchResult] = []
        
        for line in output.components(separatedBy: .newlines) {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { continue }
            
            // Format: file:line:content
            let parts = trimmed.split(separator: ":", maxSplits: 2)
            guard parts.count >= 3 else { continue }
            
            let filePath = String(parts[0])
            let lineNumber = Int(parts[1]) ?? 0
            let content = String(parts[2])
            
            results.append(SearchResult(
                filePath: filePath,
                fileName: (filePath as NSString).lastPathComponent,
                lineNumber: lineNumber,
                content: content
            ))
        }
        
        return results
    }
    
    private func parseGrepOutput(_ output: String) -> [SearchResult] {
        var results: [SearchResult] = []
        
        for line in output.components(separatedBy: .newlines) {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { continue }
            
            // Format: file:line:content
            let parts = trimmed.split(separator: ":", maxSplits: 2)
            guard parts.count >= 3 else { continue }
            
            let filePath = String(parts[0])
            let lineNumber = Int(parts[1]) ?? 0
            let content = String(parts[2])
            
            results.append(SearchResult(
                filePath: filePath,
                fileName: (filePath as NSString).lastPathComponent,
                lineNumber: lineNumber,
                content: content
            ))
        }
        
        return results
    }
    
    private func isCommandAvailable(_ command: String) -> Bool {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/which")
        task.arguments = [command]
        
        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = pipe
        
        do {
            try task.run()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: data, encoding: .utf8) ?? ""
            return !output.isEmpty
        } catch {
            return false
        }
    }
}

struct SearchResult: Identifiable {
    let id = UUID()
    let filePath: String
    let fileName: String
    let lineNumber: Int
    let content: String
}
