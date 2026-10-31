import Foundation
import SwiftUI

/// Service để mở terminal và IDE
final class TerminalService: @unchecked Sendable {
    static let shared = TerminalService()
    
    private init() {}
    
    enum TerminalApp: String, CaseIterable {
        case terminal = "Terminal"
        case iTerm = "iTerm"
        case warp = "Warp"
        case ghostty = "Ghostty"
        
        var displayName: String {
            rawValue
        }
    }
    
    enum IDE: String, CaseIterable {
        case vscode = "VS Code"
        case cursor = "Cursor"
        case xcode = "Xcode"
        case webstorm = "WebStorm"
        case intellij = "IntelliJ IDEA"
        
        var displayName: String {
            rawValue
        }
    }
    
    /// Mở terminal tại thư mục
    func openTerminal(at path: String, app: TerminalApp = .terminal) {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/open")
        task.arguments = ["-a", app.rawValue, path]
        try? task.run()
    }
    
    /// Mở IDE tại thư mục
    func openIDE(at path: String, ide: IDE) {
        switch ide {
        case .vscode:
            openVSCode(at: path)
        case .cursor:
            openCursor(at: path)
        case .xcode:
            openXcode(at: path)
        case .webstorm:
            openWebStorm(at: path)
        case .intellij:
            openIntelliJ(at: path)
        }
    }
    
    private func openVSCode(at path: String) {
        // Thử với code command
        let codePaths = [
            "/usr/local/bin/code",
            "/opt/homebrew/bin/code",
            "/Applications/Visual Studio Code.app/Contents/Resources/app/bin/code"
        ]
        
        for codePath in codePaths {
            if FileManager.default.fileExists(atPath: codePath) {
                let task = Process()
                task.executableURL = URL(fileURLWithPath: codePath)
                task.arguments = [path]
                try? task.run()
                return
            }
        }
        
        // Fallback: mở bằng open
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/open")
        task.arguments = ["-a", "Visual Studio Code", path]
        try? task.run()
    }
    
    private func openCursor(at path: String) {
        let cursorPaths = [
            "/usr/local/bin/cursor",
            "/opt/homebrew/bin/cursor",
            "/Applications/Cursor.app/Contents/Resources/app/bin/cursor"
        ]
        
        for cursorPath in cursorPaths {
            if FileManager.default.fileExists(atPath: cursorPath) {
                let task = Process()
                task.executableURL = URL(fileURLWithPath: cursorPath)
                task.arguments = [path]
                try? task.run()
                return
            }
        }
        
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/open")
        task.arguments = ["-a", "Cursor", path]
        try? task.run()
    }
    
    private func openXcode(at path: String) {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/open")
        task.arguments = ["-a", "Xcode", path]
        try? task.run()
    }
    
    private func openWebStorm(at path: String) {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/open")
        task.arguments = ["-a", "WebStorm", path]
        try? task.run()
    }
    
    private func openIntelliJ(at path: String) {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/open")
        task.arguments = ["-a", "IntelliJ IDEA", path]
        try? task.run()
    }
    
    /// Lấy danh sách terminal đã cài
    func getInstalledTerminals() -> [TerminalApp] {
        var installed: [TerminalApp] = []
        
        for terminal in TerminalApp.allCases {
            if isAppInstalled(terminal.rawValue) {
                installed.append(terminal)
            }
        }
        
        return installed
    }
    
    /// Lấy danh sách IDE đã cài
    func getInstalledIDEs() -> [IDE] {
        var installed: [IDE] = []
        
        for ide in IDE.allCases {
            if isAppInstalled(ide.displayName) {
                installed.append(ide)
            }
        }
        
        return installed
    }
    
    private func isAppInstalled(_ appName: String) -> Bool {
        let appPaths = [
            "/Applications/\(appName).app",
            "/Users/\(NSUserName())/Applications/\(appName).app"
        ]
        
        for path in appPaths {
            if FileManager.default.fileExists(atPath: path) {
                return true
            }
        }
        
        return false
    }
}
