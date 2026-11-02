import Foundation
import SwiftUI
import AppKit

/// ViewModel quản lý cây thư mục kiểu Windows Explorer (Root Tree) và ổ đĩa (Locations) cho sidebar.
@MainActor
final class SidebarViewModel: ObservableObject {
    @Published var volumes: [VolumeInfo] = []
    @Published var rootNodes: [DirectoryNode] = []
    @Published var expandedPaths: Set<String> = []
    @Published var loadingPaths: Set<String> = []
    @Published var isLoading: Bool = false

    init() {
        loadVolumes()
        loadRootTree()
    }

    func loadVolumes() {
        Task.detached(priority: .utility) {
            let loaded = DiskUsageService.shared.getAllVolumes()
            await MainActor.run {
                self.volumes = loaded
            }
        }
    }

    func refreshVolumes() {
        loadVolumes()
    }

    func loadRootTree() {
        Task {
            let nodes = await loadChildren(for: "/")
            self.rootNodes = nodes
        }
    }

    func toggleNode(at path: String, expanded: Bool) {
        if expanded {
            expandedPaths.insert(path)
        } else {
            expandedPaths.remove(path)
        }

        updateNode(at: path) { node in
            node.isExpanded = expanded
        }

        guard expanded,
              let node = node(at: path),
              !node.isLoaded,
              !loadingPaths.contains(path) else {
            return
        }

        loadingPaths.insert(path)

        Task {
            let children = await loadChildren(for: path)
            loadingPaths.remove(path)

            updateNode(at: path) { node in
                node.children = children
                node.isLoaded = true
                node.hasChildren = !children.isEmpty
                node.isExpanded = true
            }
        }
    }

    func collapseAll() {
        expandedPaths.removeAll()
        loadRootTree()
    }

    func refreshTree() {
        loadRootTree()
    }

    /// Tự động mở rộng cây thư mục đến vị trí đang đứng (kiểu Windows Explorer Expand to current folder)
    func revealPath(_ path: String) {
        guard !path.isEmpty, path != "/" else { return }
        let parts = path.split(separator: "/").map(String.init)
        var current = ""
        for part in parts {
            current += "/" + part
            if current == path { break }
            if !expandedPaths.contains(current) {
                toggleNode(at: current, expanded: true)
            }
        }
    }

    func ejectVolume(at path: String) {
        let url = URL(fileURLWithPath: path)
        try? NSWorkspace.shared.unmountAndEjectDevice(at: url)
        Task {
            try? await Task.sleep(nanoseconds: 600_000_000)
            self.refreshVolumes()
        }
    }

    // MARK: - Quét thư mục cây kiểu Windows Explorer

    private func loadChildren(for path: String) async -> [DirectoryNode] {
        await Task.detached(priority: .userInitiated) {
            Self.scanChildren(of: path)
        }.value
    }

    nonisolated private static func scanChildren(of path: String) -> [DirectoryNode] {
        let fileManager = FileManager.default
        let url = URL(fileURLWithPath: path, isDirectory: true)
        let keys: Set<URLResourceKey> = [.isDirectoryKey, .isSymbolicLinkKey, .isPackageKey]

        guard let contents = try? fileManager.contentsOfDirectory(
            at: url,
            includingPropertiesForKeys: Array(keys),
            options: [.skipsHiddenFiles, .skipsPackageDescendants]
        ) else {
            return []
        }

        var nodes: [DirectoryNode] = []

        for child in contents {
            // Không bao giờ duyệt file .app, framework, plugin như một thư mục
            let ext = child.pathExtension.lowercased()
            if ext == "app" || ext == "framework" || ext == "plugin" || ext == "kext" || ext == "bundle" {
                continue
            }

            guard let values = try? child.resourceValues(forKeys: keys),
                  values.isDirectory == true,
                  values.isSymbolicLink != true,
                  values.isPackage != true else {
                continue
            }

            let childPath = child.path
            guard !ignoredPathsList.contains(childPath) else { continue }

            // Kiểm tra nhanh xem thư mục này có thư mục con nào không để hiện mũi tên
            let hasSubs = quickCheckHasSubdirectories(at: childPath)

            nodes.append(DirectoryNode(
                name: child.lastPathComponent,
                path: childPath,
                isExpanded: false,
                hasChildren: hasSubs,
                isLoaded: false,
                children: []
            ))
        }

        return nodes.sorted {
            $0.name.localizedStandardCompare($1.name) == .orderedAscending
        }
    }

    nonisolated private static func quickCheckHasSubdirectories(at path: String) -> Bool {
        let url = URL(fileURLWithPath: path, isDirectory: true)
        let keys: Set<URLResourceKey> = [.isDirectoryKey, .isPackageKey, .isSymbolicLinkKey]
        guard let contents = try? FileManager.default.contentsOfDirectory(
            at: url,
            includingPropertiesForKeys: Array(keys),
            options: [.skipsHiddenFiles, .skipsPackageDescendants]
        ) else {
            return false
        }

        for item in contents {
            let ext = item.pathExtension.lowercased()
            if ext == "app" || ext == "framework" || ext == "plugin" { continue }

            if let vals = try? item.resourceValues(forKeys: keys),
               vals.isDirectory == true,
               vals.isPackage != true,
               vals.isSymbolicLink != true {
                return true
            }
        }
        return false
    }

    private func node(at path: String) -> DirectoryNode? {
        Self.findNode(at: path, in: rootNodes)
    }

    nonisolated private static func findNode(at path: String, in nodes: [DirectoryNode]) -> DirectoryNode? {
        for node in nodes {
            if node.path == path { return node }
            if let found = findNode(at: path, in: node.children) {
                return found
            }
        }
        return nil
    }

    private func updateNode(at path: String, transform: (inout DirectoryNode) -> Void) {
        var nodes = rootNodes
        Self.mapNodesInPlace(&nodes, path: path, transform: transform)
        rootNodes = nodes
    }

    nonisolated private static func mapNodesInPlace(
        _ nodes: inout [DirectoryNode],
        path: String,
        transform: (inout DirectoryNode) -> Void
    ) {
        for index in nodes.indices {
            if nodes[index].path == path {
                transform(&nodes[index])
            } else if !nodes[index].children.isEmpty {
                mapNodesInPlace(&nodes[index].children, path: path, transform: transform)
            }
        }
    }

    nonisolated private static let ignoredPathsList: Set<String> = [
        "/Volumes",
        "/dev",
        "/cores",
        "/private",
        "/bin",
        "/sbin",
        "/usr",
        "/etc",
        "/var",
        "/tmp",
        "/opt",
        "/net",
        "/home",
        "/System/Volumes/Data",
        "/System/Volumes/Preboot",
        "/System/Volumes/VM",
        "/System/Volumes/Update",
        "/System/Volumes/xarts",
        "/System/Volumes/iSCPreboot",
        "/System/Volumes/Hardware"
    ]
}

struct DirectoryNode: Identifiable, Hashable {
    var id: String { path }

    let name: String
    let path: String
    var isExpanded: Bool
    var hasChildren: Bool
    var isLoaded: Bool
    var children: [DirectoryNode]

    func hash(into hasher: inout Hasher) {
        hasher.combine(path)
    }

    static func == (lhs: DirectoryNode, rhs: DirectoryNode) -> Bool {
        lhs.path == rhs.path &&
        lhs.isExpanded == rhs.isExpanded &&
        lhs.isLoaded == rhs.isLoaded &&
        lhs.hasChildren == rhs.hasChildren &&
        lhs.children.count == rhs.children.count
    }
}
