import Foundation
import SwiftUI
import Combine

/// ViewModel quản lý state cho danh sách file
@MainActor
class FileListViewModel: ObservableObject {
    @Published var currentPath: String = "/Users"
    @Published var files: [FileItem] = []
    @Published var showHiddenFiles: Bool = true
    @Published var selectedItems: Set<String> = []
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    @Published var gitBranch: String?
    @Published var sortOption: SortOption = .name
    
    private let gitService = GitService.shared
    private var cancellables = Set<AnyCancellable>()
    
    enum SortOption: String, CaseIterable {
        case name = "Name"
        case size = "Size"
        case modified = "Modified"
        case type = "Type"
    }
    
    init() {
        loadFiles()
        
        // Reload khi showHiddenFiles thay đổi
        $showHiddenFiles
            .debounce(for: .milliseconds(300), scheduler: RunLoop.main)
            .sink { [weak self] _ in
                self?.loadFiles()
            }
            .store(in: &cancellables)
    }
    
    /// Load file từ currentPath
    func loadFiles() {
        isLoading = true
        errorMessage = nil
        
        Task {
            do {
                let loadedFiles = try await loadFiles(at: currentPath)
                self.files = sortFiles(loadedFiles)
                
                // Load git branch nếu có
                if gitService.isGitRepository(at: currentPath) {
                    self.gitBranch = gitService.getCurrentBranch(at: currentPath)
                } else {
                    self.gitBranch = nil
                }
                
                // Load git status cho từng file
                let statusMap = gitService.getStatusForDirectory(at: currentPath)
                self.files = self.files.map { file in
                    var updatedFile = file
                    updatedFile.gitStatus = statusMap[file.name] ?? .none
                    return updatedFile
                }
                
                isLoading = false
            } catch {
                self.errorMessage = error.localizedDescription
                isLoading = false
            }
        }
    }
    
    private func loadFiles(at path: String) async throws -> [FileItem] {
        return try await withCheckedThrowingContinuation { continuation in
            let fm = FileManager.default
            
            guard let contents = try? fm.contentsOfDirectory(atPath: path) else {
                continuation.resume(returning: [])
                return
            }
            
            var loadedFiles: [FileItem] = []
            
            for name in contents {
                let filePath = (path as NSString).appendingPathComponent(name)
                var isDir: ObjCBool = false
                fm.fileExists(atPath: filePath, isDirectory: &isDir)
                
                let attributes = try? fm.attributesOfItem(atPath: filePath)
                let size = attributes?[.size] as? UInt64 ?? 0
                let modified = attributes?[.modificationDate] as? Date ?? Date()
                let isHidden = name.hasPrefix(".")
                
                // Check symlink
                let isSymlink = (attributes?[.type] as? FileAttributeType) == .typeSymbolicLink
                
                if !showHiddenFiles && isHidden {
                    continue
                }
                
                let fileItem = FileItem(
                    name: name,
                    path: filePath,
                    isDirectory: isDir.boolValue,
                    size: size,
                    modified: modified,
                    isHidden: isHidden,
                    isSymlink: isSymlink
                )
                
                loadedFiles.append(fileItem)
            }
            
            continuation.resume(returning: loadedFiles)
        }
    }
    
    private func sortFiles(_ files: [FileItem]) -> [FileItem] {
        switch sortOption {
        case .name:
            return files.sorted { $0.name.lowercased() < $1.name.lowercased() }
        case .size:
            return files.sorted { $0.size > $1.size }
        case .modified:
            return files.sorted { $0.modified > $1.modified }
        case .type:
            return files.sorted { $0.name < $1.name }
        }
    }
    
    /// Navigate đến thư mục
    func navigateTo(path: String) {
        currentPath = path
        selectedItems.removeAll()
        loadFiles()
    }
    
    /// Navigate lên thư mục cha
    func navigateToParent() {
        let parent = (currentPath as NSString).deletingLastPathComponent
        if !parent.isEmpty && parent != currentPath {
            currentPath = parent
            selectedItems.removeAll()
            loadFiles()
        }
    }
    
    /// Navigate đến home
    func navigateToHome() {
        currentPath = FileManager.default.homeDirectoryForCurrentUser.path
        selectedItems.removeAll()
        loadFiles()
    }
    
    /// Refresh list
    func refresh() {
        loadFiles()
    }
    
    /// Open file/folder
    func openItem(_ item: FileItem) {
        if item.isDirectory {
            navigateTo(path: item.path)
        } else {
            let task = Process()
            task.executableURL = URL(fileURLWithPath: "/usr/bin/open")
            task.arguments = [item.path]
            try? task.run()
        }
    }
    
    /// Delete selected items
    func deleteSelectedItems() {
        for path in selectedItems {
            try? FileManager.default.removeItem(atPath: path)
        }
        selectedItems.removeAll()
        loadFiles()
    }
    
    /// Toggle selection
    func toggleSelection(_ path: String) {
        if selectedItems.contains(path) {
            selectedItems.remove(path)
        } else {
            selectedItems.insert(path)
        }
    }
    
    /// Select all
    func selectAll() {
        selectedItems = Set(files.map { $0.path })
    }
    
    /// Deselect all
    func deselectAll() {
        selectedItems.removeAll()
    }
    
    /// Copy selected items
    func copySelectedItems(to destinationPath: String) {
        let fm = FileManager.default
        
        for path in selectedItems {
            let fileName = (path as NSString).lastPathComponent
            let destPath = (destinationPath as NSString).appendingPathComponent(fileName)
            
            var isDir: ObjCBool = false
            fm.fileExists(atPath: path, isDirectory: &isDir)
            
            if isDir.boolValue {
                try? fm.copyItem(atPath: path, toPath: destPath)
            } else {
                try? fm.copyItem(atPath: path, toPath: destPath)
            }
        }
        
        selectedItems.removeAll()
        loadFiles()
    }
    
    /// Move selected items
    func moveSelectedItems(to destinationPath: String) {
        let fm = FileManager.default
        
        for path in selectedItems {
            let fileName = (path as NSString).lastPathComponent
            let destPath = (destinationPath as NSString).appendingPathComponent(fileName)
            
            try? fm.moveItem(atPath: path, toPath: destPath)
        }
        
        selectedItems.removeAll()
        loadFiles()
    }
    
    /// Create new folder
    func createNewFolder(name: String) {
        let newPath = (currentPath as NSString).appendingPathComponent(name)
        try? FileManager.default.createDirectory(atPath: newPath, withIntermediateDirectories: true)
        loadFiles()
    }
    
    /// Create new file
    func createNewFile(name: String) {
        let newPath = (currentPath as NSString).appendingPathComponent(name)
        FileManager.default.createFile(atPath: newPath, contents: nil)
        loadFiles()
    }
    
    /// Rename item
    func renameItem(at path: String, to newName: String) {
        let newPath = ((path as NSString).deletingLastPathComponent as NSString).appendingPathComponent(newName)
        try? FileManager.default.moveItem(atPath: path, toPath: newPath)
        loadFiles()
    }
}
