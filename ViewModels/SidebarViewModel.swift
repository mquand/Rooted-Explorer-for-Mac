import Foundation
import SwiftUI
import Combine

/// ViewModel quản lý state cho sidebar
@MainActor
class SidebarViewModel: ObservableObject {
    @Published var volumes: [VolumeInfo] = []
    @Published var expandedPaths: Set<String> = []
    @Published var rootTree: [DirectoryNode] = []
    @Published var isLoading: Bool = false
    
    private let diskService = DiskUsageService.shared
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        loadVolumes()
        loadRootTree()
    }
    
    /// Load volumes
    func loadVolumes() {
        isLoading = true
        
        Task {
            let loadedVolumes = diskService.getAllVolumes()
            await MainActor.run {
                self.volumes = loadedVolumes
                self.isLoading = false
            }
        }
    }
    
    /// Load cây thư mục root
    func loadRootTree() {
        isLoading = true
        
        Task {
            let tree = await buildTree(at: "/", maxDepth: 3)
            await MainActor.run {
                self.rootTree = tree
                self.isLoading = false
            }
        }
    }
    
    /// Build cây thư mục (đệ quy)
    private func buildTree(at path: String, maxDepth: Int, currentDepth: Int = 0) async -> [DirectoryNode] {
        guard currentDepth < maxDepth else { return [] }
        
        let fm = FileManager.default
        guard let contents = try? fm.contentsOfDirectory(atPath: path) else {
            return []
        }
        
        var nodes: [DirectoryNode] = []
        
        // Ẩn một số thư mục hệ thống
        let ignoredDirs = [".DS_Store", ".localized", "System Volume Information"]
        
        for item in contents.sorted() {
            if ignoredDirs.contains(item) { continue }
            if item.hasPrefix(".") { continue }
            
            let itemPath = (path as NSString).appendingPathComponent(item)
            var isDir: ObjCBool = false
            fm.fileExists(atPath: itemPath, isDirectory: &isDir)
            
            guard isDir.boolValue else { continue }
            
            // Skip firmlink của Catalina+
            if itemPath.contains("/System/Volumes/Data") { continue }
            
            let hasChildren = await hasSubdirectories(at: itemPath)
            let children = hasChildren ? await buildTree(at: itemPath, maxDepth: maxDepth, currentDepth: currentDepth + 1) : []
            
            nodes.append(DirectoryNode(
                name: item,
                path: itemPath,
                isExpanded: expandedPaths.contains(itemPath),
                hasChildren: hasChildren,
                children: children
            ))
        }
        
        return nodes
    }
    
    /// Kiểm tra thư mục có subdirectory không
    private func hasSubdirectories(at path: String) async -> Bool {
        let fm = FileManager.default
        guard let contents = try? fm.contentsOfDirectory(atPath: path) else {
            return false
        }
        
        for item in contents {
            if item.hasPrefix(".") { continue }
            
            let itemPath = (path as NSString).appendingPathComponent(item)
            var isDir: ObjCBool = false
            fm.fileExists(atPath: itemPath, isDirectory: &isDir)
            
            if isDir.boolValue {
                return true
            }
        }
        
        return false
    }
    
    /// Toggle expanded state
    func toggleNode(at path: String) {
        if expandedPaths.contains(path) {
            expandedPaths.remove(path)
        } else {
            expandedPaths.insert(path)
        }
        
        // Reload tree với state mới
        loadRootTree()
    }
    
    /// Expand path (expand all parent nodes)
    func expandPath(_ path: String) {
        var currentPath = path
        while !currentPath.isEmpty && currentPath != "/" {
            expandedPaths.insert(currentPath)
            currentPath = (currentPath as NSString).deletingLastPathComponent
        }
        loadRootTree()
    }
    
    /// Collapse all
    func collapseAll() {
        expandedPaths.removeAll()
        loadRootTree()
    }
    
    /// Expand all
    func expandAll() {
        expandedPaths = Set(rootTree.map { $0.path })
        loadRootTree()
    }
    
    /// Refresh volumes
    func refreshVolumes() {
        loadVolumes()
    }
    
    /// Refresh tree
    func refreshTree() {
        loadRootTree()
    }
}

struct DirectoryNode: Identifiable, Hashable {
    var id: String { path }

    let name: String
    let path: String
    var isExpanded: Bool
    let hasChildren: Bool
    var children: [DirectoryNode]
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(path)
    }
    
    static func == (lhs: DirectoryNode, rhs: DirectoryNode) -> Bool {
        lhs.path == rhs.path
    }
}
