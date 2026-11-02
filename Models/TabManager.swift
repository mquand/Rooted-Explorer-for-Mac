import SwiftUI
import Combine

/// Quản lý Tab & Dual-Pane của Rooted
@MainActor
class TabManager: ObservableObject {
    @Published var tabs: [TabItem] = []
    @Published var activeTabId: UUID

    init() {
        let first = TabItem()
        self.tabs = [first]
        self.activeTabId = first.id
        wireTab(first)
    }

    var activeTab: TabItem {
        tabs.first(where: { $0.id == activeTabId }) ?? tabs[0]
    }

    var activeViewModel: FileListViewModel {
        activeTab.activeViewModel
    }

    func newTab(path: String? = nil) {
        let targetPath = path ?? activeTab.activeViewModel.currentPath
        let tab = TabItem(initialPath: targetPath)
        wireTab(tab)
        tabs.append(tab)
        activeTabId = tab.id
    }

    func closeTab(id: UUID) {
        guard tabs.count > 1 else { return }
        guard let index = tabs.firstIndex(where: { $0.id == id }) else { return }
        tabs.remove(at: index)
        if activeTabId == id {
            let nextIndex = min(index, tabs.count - 1)
            activeTabId = tabs[nextIndex].id
        }
    }

    func closeActiveTab() {
        closeTab(id: activeTabId)
    }

    func selectTab(at index: Int) {
        guard index >= 0 && index < tabs.count else { return }
        activeTabId = tabs[index].id
    }

    func selectNextTab() {
        guard let index = tabs.firstIndex(where: { $0.id == activeTabId }) else { return }
        let nextIndex = (index + 1) % tabs.count
        activeTabId = tabs[nextIndex].id
    }

    func selectPreviousTab() {
        guard let index = tabs.firstIndex(where: { $0.id == activeTabId }) else { return }
        let prevIndex = (index - 1 + tabs.count) % tabs.count
        activeTabId = tabs[prevIndex].id
    }

    func wireTab(_ tab: TabItem) {
        tab.leftViewModel.onOpenNewTab = { [weak self] path in
            self?.newTab(path: path)
        }
        tab.leftViewModel.onSelectPane = { [weak tab] in
            tab?.activePane = .left
        }

        tab.rightViewModel?.onOpenNewTab = { [weak self] path in
            self?.newTab(path: path)
        }
        tab.rightViewModel?.onSelectPane = { [weak tab] in
            tab?.activePane = .right
        }
    }
}

/// Một tab trong trình duyệt file, hỗ trợ chế độ chia 2 khung (Dual-Pane)
@MainActor
class TabItem: Identifiable, ObservableObject {
    let id: UUID
    @Published var leftViewModel: FileListViewModel
    @Published var rightViewModel: FileListViewModel?
    @Published var activePane: PaneSide = .left
    @Published var isDualPane: Bool = false

    enum PaneSide {
        case left
        case right
    }

    init(id: UUID = UUID(), initialPath: String? = nil) {
        self.id = id
        self.leftViewModel = FileListViewModel(initialPath: initialPath)
    }

    var activeViewModel: FileListViewModel {
        if isDualPane && activePane == .right, let right = rightViewModel {
            return right
        }
        return leftViewModel
    }

    var title: String {
        let path = activeViewModel.currentPath
        let name = (path as NSString).lastPathComponent
        return name.isEmpty ? "Root" : name
    }

    func toggleDualPane() {
        if isDualPane {
            isDualPane = false
            activePane = .left
        } else {
            if rightViewModel == nil {
                let right = FileListViewModel(initialPath: leftViewModel.currentPath)
                right.onSelectPane = { [weak self] in
                    self?.activePane = .right
                }
                rightViewModel = right
            }
            isDualPane = true
        }
    }
}
