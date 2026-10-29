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

    /// Mở rộng tất cả thư mục cha để path hiện tại hiển thị trong sidebar.
    func expandPath(_ path: String) {
        var components: [String] = []
        var current = path

        while !current.isEmpty, current != "/" {
            components.append(current)
            current = (current as NSString).deletingLastPathComponent
        }

        for component in components.reversed() {
            if !expandedPaths.contains(component) {
                toggleNode(at: component, expanded: true)
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
            guard !ignoredPaths.contains(childPath) else { continue }

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
        rootNodes = Self.mapNodes(rootNodes, path: path, transform: transform)
    }

    nonisolated private static func mapNodes(
        _ nodes: [DirectoryNode],
        path: String,
        transform: (inout DirectoryNode) -> Void
    ) -> [DirectoryNode] {
        var result = nodes

        for index in result.indices {
            if result[index].path == path {
                transform(&result[index])
            } else if !result[index].children.isEmpty {
                result[index].children = mapNodes(result[index].children, path: path, transform: transform)
            }
        }

        return result
    }

    private static let ignoredPaths: Set<String> = [
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
