import Foundation
import SwiftUI
import Combine
import AppKit

/// ViewModel quản lý state cho danh sách file.
@MainActor
class FileListViewModel: ObservableObject {
    @Published var currentPath: String
    @Published var pathInput: String
    @Published var files: [FileItem] = []
    @Published var selectedItems: Set<String> = []
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    @Published var gitBranch: String?
    @Published var folderSizes: [String: UInt64] = [:]
    @Published var sortOption: SortOption = .name {
        didSet {
            guard oldValue != sortOption else { return }
            files = sortFiles(files)
        }
    }

    @Published private(set) var history: [String] = []
    @Published private(set) var historyIndex: Int = -1

    private let settings: AppSettings
    private let gitService = GitService.shared
    private var cancellables = Set<AnyCancellable>()
    private var loadGeneration = 0
    private var lastSelectedPath: String?

    enum SortOption: String, CaseIterable {
        case name = "Name"
        case size = "Size"
        case modified = "Modified"
        case type = "Type"
    }

    init() {
        let settings = AppSettings.shared
        self.settings = settings

        let startPath = FileManager.default.homeDirectoryForCurrentUser.path
        currentPath = startPath
        pathInput = startPath
        history = [startPath]
        historyIndex = 0

        settings.$showHiddenFiles
            .removeDuplicates()
            .dropFirst()
            .debounce(for: .milliseconds(150), scheduler: RunLoop.main)
            .sink { [weak self] _ in
                self?.loadFiles()
            }
            .store(in: &cancellables)

        loadFiles()
    }

    var canGoBack: Bool { historyIndex > 0 }
    var canGoForward: Bool { historyIndex >= 0 && historyIndex < history.count - 1 }
    var selectedURLs: [URL] { selectedItems.map { URL(fileURLWithPath: $0) } }

    var focusedFile: FileItem? {
        guard let path = selectedItems.first else { return nil }
        return files.first { $0.path == path }
    }

    // MARK: - Loading

    /// Load file từ currentPath. Đọc đĩa và git ở background để UI không bị treo.
    func loadFiles() {
        let path = currentPath
        let showHidden = settings.showHiddenFiles

        loadGeneration += 1
        let generation = loadGeneration
        isLoading = true
        errorMessage = nil

        Task {
            do {
                let loaded = try await Task.detached(priority: .userInitiated) {
                    try Self.readDirectory(at: path, showHidden: showHidden)
                }.value

                guard generation == self.loadGeneration, path == self.currentPath else { return }

                var items = self.sortFiles(loaded)

                let metadata = await Task.detached(priority: .utility) {
                    () -> (String?, [String: GitStatus]) in
                    let service = GitService.shared
                    let branch = service.isGitRepository(at: path)
                        ? service.getCurrentBranch(at: path)
                        : nil
                    let status = service.getStatusForDirectory(at: path)
                    return (branch, status)
                }.value

                guard generation == self.loadGeneration, path == self.currentPath else { return }

                self.gitBranch = metadata.0
                items = items.map { file in
                    var updated = file
                    updated.gitStatus = metadata.1[file.name] ?? .none
                    return updated
                }

                self.files = items
                self.isLoading = false
            } catch {
                guard generation == self.loadGeneration else { return }
                self.files = []
                self.errorMessage = error.localizedDescription
                self.isLoading = false
            }
        }
    }

    nonisolated private static func readDirectory(at path: String, showHidden: Bool) throws -> [FileItem] {
        let fileManager = FileManager.default
        let names = try fileManager.contentsOfDirectory(atPath: path)
        var items: [FileItem] = []
        items.reserveCapacity(names.count)

        for name in names {
            if !showHidden && name.hasPrefix(".") { continue }

            let filePath = (path as NSString).appendingPathComponent(name)
            var isDirectory: ObjCBool = false
            guard fileManager.fileExists(atPath: filePath, isDirectory: &isDirectory) else { continue }

            let attributes = try? fileManager.attributesOfItem(atPath: filePath)
            let size = attributes?[.size] as? UInt64 ?? 0
            let modified = attributes?[.modificationDate] as? Date ?? .distantPast
            let isSymlink = (attributes?[.type] as? FileAttributeType) == .typeSymbolicLink

            items.append(FileItem(
                name: name,
                path: filePath,
                isDirectory: isDirectory.boolValue,
                size: size,
                modified: modified,
                isHidden: name.hasPrefix("."),
                isSymlink: isSymlink
            ))
        }

        return items
    }

    private func sortFiles(_ files: [FileItem]) -> [FileItem] {
        files.sorted { lhs, rhs in
            if sortOption != .size && lhs.isDirectory != rhs.isDirectory {
                return lhs.isDirectory
            }

            switch sortOption {
            case .name:
                return lhs.name.localizedStandardCompare(rhs.name) == .orderedAscending
            case .size:
                return lhs.size > rhs.size
            case .modified:
                return lhs.modified > rhs.modified
            case .type:
                let result = lhs.kind.localizedStandardCompare(rhs.kind)
                if result == .orderedSame {
                    return lhs.name.localizedStandardCompare(rhs.name) == .orderedAscending
                }
                return result == .orderedAscending
            }
        }
    }

    // MARK: - Navigation

    func navigateTo(path: String) {
        guard !path.isEmpty else { return }

        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: path, isDirectory: &isDirectory),
              isDirectory.boolValue else {
            errorMessage = "Không tìm thấy thư mục: \(path)"
            return
        }

        currentPath = path
        pathInput = path
        selectedItems.removeAll()
        lastSelectedPath = nil
        recordVisit(path)
        loadFiles()
    }

    func navigateToParent() {
        let parent = (currentPath as NSString).deletingLastPathComponent
        guard !parent.isEmpty, parent != currentPath else { return }
        navigateTo(path: parent)
    }

    func navigateToHome() {
        navigateTo(path: FileManager.default.homeDirectoryForCurrentUser.path)
    }

    func submitPathInput() {
        let trimmed = pathInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            pathInput = currentPath
            return
        }

        let expanded = (trimmed as NSString).expandingTildeInPath
        navigateTo(path: expanded)
        pathInput = currentPath
    }

    func goBack() {
        guard canGoBack else { return }
        historyIndex -= 1
        currentPath = history[historyIndex]
        pathInput = currentPath
        selectedItems.removeAll()
        lastSelectedPath = nil
        loadFiles()
    }

    func goForward() {
        guard canGoForward else { return }
        historyIndex += 1
        currentPath = history[historyIndex]
        pathInput = currentPath
        selectedItems.removeAll()
        lastSelectedPath = nil
        loadFiles()
    }

    private func recordVisit(_ path: String) {
        if historyIndex >= 0, historyIndex < history.count, history[historyIndex] == path {
            return
        }

        if historyIndex < history.count - 1 {
            history.removeSubrange((historyIndex + 1)...)
        }

        history.append(path)
        historyIndex = history.count - 1
    }

    func refresh() {
        loadFiles()
    }

    // MARK: - Opening

    func openItem(_ item: FileItem) {
        if item.isDirectory {
            navigateTo(path: item.path)
        } else {
            NSWorkspace.shared.open(URL(fileURLWithPath: item.path))
        }
    }

    func reveal(_ items: [FileItem]) {
        let urls = items.map { URL(fileURLWithPath: $0.path) }
        guard !urls.isEmpty else { return }
        NSWorkspace.shared.activateFileViewerSelecting(urls)
    }

    func openTerminal(for item: FileItem) {
        let path = item.isDirectory ? item.path : (item.path as NSString).deletingLastPathComponent
        TerminalService.shared.openTerminal(at: path)
    }

    // MARK: - Selection

    func selectOnly(_ path: String) {
        selectedItems = [path]
        lastSelectedPath = path
    }

    func ensureSelected(_ path: String) {
        if !selectedItems.contains(path) {
            selectOnly(path)
        }
    }

    func toggleSelection(_ path: String) {
        if selectedItems.contains(path) {
            selectedItems.remove(path)
        } else {
            selectedItems.insert(path)
            lastSelectedPath = path
        }
    }

    func selectRange(to path: String) {
        guard let anchor = lastSelectedPath,
              let start = files.firstIndex(where: { $0.path == anchor }),
              let end = files.firstIndex(where: { $0.path == path }) else {
            selectOnly(path)
            return
        }

        let range = start <= end ? start...end : end...start
        selectedItems = Set(files[range].map(\.path))
    }

    func selectAll() {
        selectedItems = Set(files.map(\.path))
    }

    func deselectAll() {
        selectedItems.removeAll()
        lastSelectedPath = nil
    }

    // MARK: - Clipboard

    func copySelectedItems(cut: Bool = false) {
        let urls = selectedURLs
        guard !urls.isEmpty else { return }
        FilePasteboard.write(urls: urls, cut: cut)
    }

    func paste() {
        let (urls, isCut) = FilePasteboard.read()
        guard !urls.isEmpty else { return }

        let fileManager = FileManager.default
        let currentURL = URL(fileURLWithPath: currentPath, isDirectory: true).standardizedFileURL

        for source in urls {
            if isCut && source.deletingLastPathComponent().standardizedFileURL == currentURL {
                continue
            }

            let destination = uniqueDestination(for: source.lastPathComponent, source: isCut ? nil : source)

            if destination.path.hasPrefix(source.path + "/") {
                errorMessage = "Không thể copy thư mục vào chính nó."
                continue
            }

            do {
                if isCut {
                    try fileManager.moveItem(at: source, to: destination)
                } else {
                    try fileManager.copyItem(at: source, to: destination)
                }
            } catch {
                errorMessage = error.localizedDescription
            }
        }

        if isCut {
            FilePasteboard.clear()
        }

        loadFiles()
    }

    func duplicateSelectedItems() {
        let fileManager = FileManager.default

        for path in selectedItems {
            let source = URL(fileURLWithPath: path)
            let destination = uniqueDestination(for: source.lastPathComponent, source: source)
            try? fileManager.copyItem(at: source, to: destination)
        }

        loadFiles()
    }

    // MARK: - File operations

    func trashSelectedItems() {
        let fileManager = FileManager.default

        for path in selectedItems {
            try? fileManager.trashItem(at: URL(fileURLWithPath: path), resultingItemURL: nil)
        }

        selectedItems.removeAll()
        lastSelectedPath = nil
        loadFiles()
    }

    func createNewFolder() {
        let destination = URL(fileURLWithPath: currentPath, isDirectory: true)
            .appendingPathComponent(uniqueName("Untitled Folder"), isDirectory: true)
        do {
            try FileManager.default.createDirectory(at: destination, withIntermediateDirectories: false)
            loadFiles()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func createNewFile() {
        let destination = URL(fileURLWithPath: currentPath, isDirectory: true)
            .appendingPathComponent(uniqueName("Untitled.txt"))
        guard FileManager.default.createFile(atPath: destination.path, contents: nil) else {
            errorMessage = "Không thể tạo file mới."
            return
        }
        loadFiles()
    }

    @discardableResult
    func renameItem(at path: String, to newName: String) -> Bool {
        let trimmed = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            errorMessage = "Tên không được để trống."
            return false
        }

        let parent = (path as NSString).deletingLastPathComponent
        let destination = (parent as NSString).appendingPathComponent(trimmed)

        guard destination != path else { return true }

        guard !FileManager.default.fileExists(atPath: destination) else {
            errorMessage = "Đã có file hoặc thư mục tên \"\(trimmed)\"."
            return false
        }

        do {
            try FileManager.default.moveItem(atPath: path, toPath: destination)
            selectedItems = [destination]
            loadFiles()
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    // MARK: - Folder size

    func sizeText(for item: FileItem) -> String {
        guard item.isDirectory else { return item.formattedSize }
        guard let size = folderSizes[item.path] else { return "—" }
        return Self.byteFormatter.string(fromByteCount: Int64(size))
    }

    func calculateSize(for item: FileItem) {
        guard item.isDirectory, folderSizes[item.path] == nil else { return }

        let path = item.path
        Task {
            let size = await Task.detached(priority: .utility) {
                Self.directorySize(at: path)
            }.value
            self.folderSizes[path] = size
        }
    }

    nonisolated private static func directorySize(at path: String, maxEntries: Int = .max) -> UInt64 {
        let url = URL(fileURLWithPath: path, isDirectory: true)
        let keys: Set<URLResourceKey> = [.totalFileAllocatedSizeKey, .fileAllocatedSizeKey, .isRegularFileKey]

        guard let enumerator = FileManager.default.enumerator(
            at: url,
            includingPropertiesForKeys: Array(keys),
            options: [.skipsHiddenFiles, .skipsPackageDescendants],
            errorHandler: nil
        ) else {
            return 0
        }

        var total: UInt64 = 0
        var visited = 0

        for case let fileURL as URL in enumerator {
            visited += 1
            if visited > maxEntries { break }

            guard let values = try? fileURL.resourceValues(forKeys: keys),
                  values.isRegularFile == true else {
                continue
            }
            total += UInt64(values.totalFileAllocatedSize ?? values.fileAllocatedSize ?? 0)
        }

        return total
    }

    private func uniqueDestination(for name: String, source: URL?) -> URL {
        let directory = URL(fileURLWithPath: currentPath, isDirectory: true)
        var candidate = directory.appendingPathComponent(name)

        if candidate.standardizedFileURL == source?.standardizedFileURL {
            candidate = directory.appendingPathComponent(duplicateName(for: name, index: 1))
        }

        var index = 2
        while FileManager.default.fileExists(atPath: candidate.path) {
            candidate = directory.appendingPathComponent(duplicateName(for: name, index: index))
            index += 1
        }

        return candidate
    }

    private func duplicateName(for name: String, index: Int) -> String {
        let nsName = name as NSString
        let ext = nsName.pathExtension
        let base = nsName.deletingPathExtension
        let suffix = index == 1 ? "copy" : "copy \(index)"
        return ext.isEmpty ? "\(base) \(suffix)" : "\(base) \(suffix).\(ext)"
    }

    private func uniqueName(_ baseName: String) -> String {
        let directory = URL(fileURLWithPath: currentPath, isDirectory: true)
        var candidate = baseName
        var index = 2

        while FileManager.default.fileExists(atPath: directory.appendingPathComponent(candidate).path) {
            let nsName = baseName as NSString
            let ext = nsName.pathExtension
            let base = nsName.deletingPathExtension
            candidate = ext.isEmpty ? "\(base) \(index)" : "\(base) \(index).\(ext)"
            index += 1
        }

        return candidate
    }

    private static let byteFormatter: ByteCountFormatter = {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB, .useGB]
        formatter.countStyle = .file
        return formatter
    }()
}

// MARK: - Focused value (dùng cho menu Copy/Cut/Paste)

struct FileListViewModelKey: FocusedValueKey {
    typealias Value = FileListViewModel
}

extension FocusedValues {
    var fileListViewModel: FileListViewModel? {
        get { self[FileListViewModelKey.self] }
        set { self[FileListViewModelKey.self] = newValue }
    }
}
