import Foundation
import SwiftUI
import Combine
import AppKit

/// ViewModel quản lý state cho danh sách file: điều hướng, sort, chọn,
/// clipboard, tag, tìm kiếm và tính dung lượng.
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

    /// Sắp xếp hiện tại — bind trực tiếp với `sortOrder` của Table nên header
    /// cột bấm là sắp xếp (kiểu Windows Explorer).
    @Published var sortOrder: [KeyPathComparator<FileItem>] = [KeyPathComparator(\FileItem.name)] {
        didSet {
            files = sortFiles(files)
        }
    }

    /// Dung lượng trống của volume chứa thư mục hiện tại (cho status bar).
    @Published var volumeFreeSpace: UInt64?

    // MARK: - Tìm kiếm
    @Published var searchQuery: String = ""
    @Published var searchHits: [SearchHit] = []
    @Published var isSearching: Bool = false
    @Published var isSearchActive: Bool = false
    @Published var searchTitle: String?
    @Published var searchScope: SearchScope = .name {
        didSet {
            if isSearchActive, oldValue != searchScope, !searchQuery.isEmpty {
                searchQueryChanged()
            }
        }
    }

    /// Cờ báo UI focus vào ô nhập đường dẫn / ô tìm kiếm (từ menu phím tắt).
    @Published var focusPathField: Bool = false
    @Published var focusSearchField: Bool = false

    enum SearchScope: String, CaseIterable, Identifiable {
        case name = "Name"
        case content = "Contents"

        var id: String { rawValue }
    }

    @Published private(set) var history: [String] = []
    @Published private(set) var historyIndex: Int = -1

    private let settings: AppSettings
    private var cancellables = Set<AnyCancellable>()
    private var loadGeneration = 0
    private var searchGeneration = 0
    private var searchTask: Task<Void, Never>?
    private var activeTagSearch: FinderTag?
    private var typeAhead = ""
    private var typeAheadDate: Date = .distantPast
    private var lastSelectedPath: String?

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

        // Debounce tìm kiếm — chạy cả với gán chương trình (vd. đổi scope).
        $searchQuery
            .removeDuplicates()
            .debounce(for: .milliseconds(250), scheduler: RunLoop.main)
            .sink { [weak self] _ in
                self?.searchQueryChanged()
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

    /// Các file đang chọn, theo đúng thứ tự hiển thị — dùng cho Quick Look.
    var previewURLs: [URL] {
        files
            .filter { selectedItems.contains($0.path) }
            .map { URL(fileURLWithPath: $0.path) }
    }

    var selectedFileItems: [FileItem] {
        files.filter { selectedItems.contains($0.path) }
    }

    // MARK: - Loading

    /// Load file từ currentPath. Đọc đĩa và git ở background để UI không bị treo.
    /// - Parameter force: bỏ qua cache git (Refresh).
    func loadFiles(force: Bool = false) {
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

                let metadata = await Task.detached(priority: .utility) { () -> (String?, [String: GitStatus], UInt64?) in
                    let state = GitService.shared.repositoryState(at: path, useCache: !force)
                    return (state.branch, state.statuses, Self.freeSpace(at: path))
                }.value

                guard generation == self.loadGeneration, path == self.currentPath else { return }

                self.gitBranch = metadata.0
                self.volumeFreeSpace = metadata.2
                items = items.map { file in
                    var updated = file
                    updated.gitStatus = metadata.1[file.path] ?? .none
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
        let names = try FileManager.default.contentsOfDirectory(atPath: path)
        var items: [FileItem] = []
        items.reserveCapacity(names.count)

        for name in names {
            if !showHidden && name.hasPrefix(".") { continue }
            let filePath = (path as NSString).appendingPathComponent(name)
            if let item = FileItem.from(path: filePath) {
                items.append(item)
            }
        }

        return items
    }

    nonisolated private static func freeSpace(at path: String) -> UInt64? {
        let keys: Set<URLResourceKey> = [
            .volumeAvailableCapacityForImportantUsageKey,
            .volumeAvailableCapacityKey
        ]
        guard let values = try? URL(fileURLWithPath: path).resourceValues(forKeys: keys) else { return nil }

        if let important = values.volumeAvailableCapacityForImportantUsage, important > 0 {
            return UInt64(important)
        }
        if let available = values.volumeAvailableCapacity, available > 0 {
            return UInt64(available)
        }
        return nil
    }

    private func sortFiles(_ files: [FileItem]) -> [FileItem] {
        let comparators = sortOrder.isEmpty ? [KeyPathComparator(\FileItem.name)] : sortOrder

        return files.sorted { lhs, rhs in
            // Như Explorer: thư mục luôn đứng trước file.
            if lhs.isDirectory != rhs.isDirectory {
                return lhs.isDirectory
            }

            for comparator in comparators {
                let result = comparator.compare(lhs, rhs)
                if result != .orderedSame {
                    return result == .orderedAscending
                }
            }

            return lhs.name.localizedStandardCompare(rhs.name) == .orderedAscending
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

        leaveSearch()
        currentPath = path
        pathInput = path
        selectedItems.removeAll()
        lastSelectedPath = nil
        files = []
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
            focusPathField = false
            return
        }

        let expanded = (trimmed as NSString).expandingTildeInPath
        navigateTo(path: expanded)
        pathInput = currentPath
        focusPathField = false
    }

    func goBack() {
        guard canGoBack else { return }
        historyIndex -= 1
        switchToHistoryEntry()
    }

    func goForward() {
        guard canGoForward else { return }
        historyIndex += 1
        switchToHistoryEntry()
    }

    private func switchToHistoryEntry() {
        leaveSearch()
        currentPath = history[historyIndex]
        pathInput = currentPath
        selectedItems.removeAll()
        lastSelectedPath = nil
        files = []
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
        loadFiles(force: true)
    }

    // MARK: - Opening

    func openItem(_ item: FileItem) {
        if item.isDirectory {
            navigateTo(path: item.path)
        } else {
            NSWorkspace.shared.open(URL(fileURLWithPath: item.path))
        }
    }

    func openFocusedItem() {
        if let focused = focusedFile {
            openItem(focused)
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

    /// Chọn item kế tiếp/trước đó theo thứ tự hiển thị (dùng cho phím mũi tên).
    func moveSelection(by offset: Int) {
        guard !files.isEmpty else { return }

        guard let currentPath = selectedItems.first,
              let index = files.firstIndex(where: { $0.path == currentPath }) else {
            selectOnly(files[min(max(0, offset - 1), files.count - 1)].path)
            return
        }

        let target = min(max(index + offset, 0), files.count - 1)
        selectOnly(files[target].path)
    }

    func selectByTyping(_ character: String) {
        let now = Date()
        typeAhead = now.timeIntervalSince(typeAheadDate) < 0.7 ? typeAhead + character : character
        typeAheadDate = now

        let query = typeAhead.lowercased()
        if let match = files.first(where: { $0.name.lowercased().hasPrefix(query) }) {
            selectOnly(match.path)
            return
        }

        // Chuỗi gõ nối tiếp không khớp — quay lại với đúng ký tự vừa gõ.
        typeAhead = character
        if let match = files.first(where: { $0.name.lowercased().hasPrefix(character) }) {
            selectOnly(match.path)
        }
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
        var failures = 0

        for path in selectedItems {
            let source = URL(fileURLWithPath: path)
            let destination = uniqueDestination(for: source.lastPathComponent, source: source)
            do {
                try fileManager.copyItem(at: source, to: destination)
            } catch {
                failures += 1
            }
        }

        if failures > 0 {
            errorMessage = "Không thể nhân bản \(failures) mục — kiểm tra quyền ghi của thư mục này."
        }

        loadFiles()
    }

    // MARK: - File operations

    func trashSelectedItems() {
        let fileManager = FileManager.default
        var failures = 0

        for path in selectedItems {
            do {
                try fileManager.trashItem(at: URL(fileURLWithPath: path), resultingItemURL: nil)
            } catch {
                failures += 1
            }
        }

        if failures > 0 {
            errorMessage = "Không thể chuyển \(failures) mục vào Thùng rác — một số ổ đĩa ngoài không hỗ trợ Trash."
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

        guard trimmed != ".", trimmed != "..", !trimmed.contains("/") else {
            errorMessage = "Tên file không được chứa dấu / ."
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

    // MARK: - Tags (Finder)

    /// Gỡ/bật một tag trên các file đang chọn: nếu mọi file đã có tag thì gỡ,
    /// chưa có thì thêm (giống toggle trong Finder).
    func toggleTag(_ tag: FinderTag) {
        let targets = selectedFileItems
        guard !targets.isEmpty else { return }

        let allHaveTag = targets.allSatisfy { $0.tags.contains { $0.name == tag.name } }

        for item in targets {
            var newTags = item.tags.filter { $0.name != tag.name }
            if !allHaveTag {
                newTags.append(tag)
            }
            TagService.setTags(newTags, for: item.path)
            updateTags(newTags, path: item.path)
        }
    }

    func removeTagsFromSelection() {
        let targets = selectedFileItems
        guard !targets.isEmpty else { return }

        for item in targets {
            TagService.removeTags(for: item.path)
            updateTags([], path: item.path)
        }
    }

    private func updateTags(_ tags: [FinderTag], path: String) {
        if let index = files.firstIndex(where: { $0.path == path }) {
            files[index].tags = tags
        }
        if let index = searchHits.firstIndex(where: { $0.file.path == path }) {
            searchHits[index].file.tags = tags
        }
    }

    // MARK: - Search

    func searchQueryChanged() {
        searchTask?.cancel()

        let query = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else {
            // Ô trống trong khi đang xem kết quả tag -> giữ nguyên kết quả đó.
            guard activeTagSearch == nil else { return }
            leaveSearch()
            return
        }

        activeTagSearch = nil
        searchTitle = nil

        searchTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 300_000_000)
            guard !Task.isCancelled else { return }
            await self?.performSearch(query: query)
        }
    }

    /// Tìm theo tag từ sidebar — quét toàn bộ home bằng Spotlight.
    func startTagSearch(_ tag: FinderTag) {
        let home = FileManager.default.homeDirectoryForCurrentUser.path

        searchTask?.cancel()
        searchGeneration += 1

        activeTagSearch = tag
        searchQuery = ""
        searchScope = .name
        searchTitle = "Tag: \(tag.name)"

        let generation = searchGeneration
        isSearchActive = true
        isSearching = true

        searchTask = Task { [weak self] in
            guard let self else { return }
            let hits = await SearchService.shared.searchByTag(tag, in: home)
            guard generation == self.searchGeneration else { return }
            self.searchHits = hits
            self.isSearching = false
        }
    }

    private func performSearch(query: String) async {
        searchGeneration += 1
        let generation = searchGeneration
        let path = currentPath
        let scope = searchScope

        isSearchActive = true
        isSearching = true

        let hits: [SearchHit]
        switch scope {
        case .name:
            hits = await SearchService.shared.searchByName(query, in: path)
        case .content:
            hits = await SearchService.shared.searchContent(query, in: path)
        }

        guard generation == searchGeneration else { return }
        searchHits = hits
        isSearching = false
    }

    /// Thoát chế độ tìm kiếm, quay lại danh sách thư mục.
    func leaveSearch() {
        searchTask?.cancel()
        searchGeneration += 1
        activeTagSearch = nil
        searchQuery = ""
        searchHits = []
        searchTitle = nil
        isSearching = false
        isSearchActive = false
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
            let size = await DiskUsageService.directorySize(at: path)
            self.folderSizes[path] = size
        }
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
