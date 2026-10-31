import Foundation
import SwiftUI
import Combine

/// ViewModel quản lý state cho sidebar.
///
/// Cây thư mục được load lười: chỉ đọc các thư mục con trực tiếp khi người dùng
/// mở rộng một node, thay vì quét toàn bộ cây mỗi lần toggle.
@MainActor
final class SidebarViewModel: ObservableObject {
    @Published var volumes: [VolumeInfo] = []
    @Published var rootNodes: [DirectoryNode] = []
    @Published var expandedPaths: Set<String> = []
    @Published var loadingPaths: Set<String> = []
    @Published var isLoading: Bool = false

    private let diskService = DiskUsageService.shared
    private var cancellables = Set<AnyCancellable>()

    init() {
        loadVolumes()
        loadRootTree()
    }

    func loadVolumes() {
        isLoading = true

        Task {
            let loaded = diskService.getAllVolumes()
            self.volumes = loaded
            self.isLoading = false
        }
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

    func refreshVolumes() {
        loadVolumes()
    }

    func refreshTree() {
        loadRootTree()
    }

    // MARK: - Helpers

    private func loadChildren(for path: String) async -> [DirectoryNode] {
        await Task.detached(priority: .userInitiated) {
            Self.scanChildren(of: path)
        }.value
    }

    nonisolated private static func scanChildren(of path: String) -> [DirectoryNode] {
        let fileManager = FileManager.default
        let url = URL(fileURLWithPath: path, isDirectory: true)
        let keys: Set<URLResourceKey> = [.isDirectoryKey, .isSymbolicLinkKey]

        guard let contents = try? fileManager.contentsOfDirectory(
            at: url,
            includingPropertiesForKeys: Array(keys),
            options: [.skipsHiddenFiles, .skipsPackageDescendants]
        ) else {
            return []
        }

        var nodes: [DirectoryNode] = []

        for child in contents {
            guard let values = try? child.resourceValues(forKeys: keys),
                  values.isDirectory == true,
                  values.isSymbolicLink != true else {
                continue
            }

            let childPath = child.path
            guard !ignoredPathsList.contains(childPath) else { continue }

            nodes.append(DirectoryNode(
                name: child.lastPathComponent,
                path: childPath,
                isExpanded: false,
                hasChildren: true,
                isLoaded: false,
                children: []
            ))
        }

        return nodes.sorted {
            $0.name.localizedStandardCompare($1.name) == .orderedAscending
        }
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
        lhs.path == rhs.path
    }
}
