import SwiftUI
import AppKit
import QuickLookUI

struct FileListView: View {
    @ObservedObject var viewModel: FileListViewModel
    @Binding var columnVisibility: NavigationSplitViewVisibility
    @EnvironmentObject private var settings: AppSettings

    @State private var isRenaming = false
    @State private var renameTarget: FileItem?
    @State private var renameName = ""
    @State private var showAnalysis = false
    @State private var keyMonitor: Any?
    @State private var mouseMonitor: Any?
    @FocusState private var isSearchFocused: Bool
    @FocusState private var isQuickFilterFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            topBar
            Divider()

            if !viewModel.quickFilter.isEmpty || viewModel.showQuickFilterBar {
                quickFilterBar
                Divider()
            }

            HStack(spacing: 0) {
                content
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .onDrop(of: [.fileURL], isTargeted: nil) { providers in
                        handleDrop(providers: providers)
                    }

                if viewModel.showPreviewPane {
                    Divider()
                    FilePreviewPane(viewModel: viewModel, settings: settings)
                        .transition(.move(edge: .trailing))
                }
            }

            Divider()
            statusBar
        }
        .contentShape(Rectangle())
        .onTapGesture {
            viewModel.onSelectPane?()
        }
        .sheet(isPresented: $viewModel.showBatchRename) {
            BatchRenameSheet(viewModel: viewModel, files: viewModel.selectedFileItems)
        }
        .alert(
            "Mã kiểm tra tệp (Checksum)",
            isPresented: $viewModel.showChecksumAlert,
            presenting: viewModel.checksumResult
        ) { result in
            Button("Sao chép SHA-256") {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(result.sha256, forType: .string)
            }
            Button("Sao chép MD5") {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(result.md5, forType: .string)
            }
            Button("Đóng", role: .cancel) {}
        } message: { result in
            Text("\(result.name)\n\nSHA-256:\n\(result.sha256)\n\nMD5:\n\(result.md5)")
        }
        .alert("Rename", isPresented: $isRenaming) {
            TextField("Name", text: $renameName)
            Button("Cancel", role: .cancel) {
                renameTarget = nil
            }
            Button("Rename") {
                if let target = renameTarget {
                    viewModel.renameItem(at: target.path, to: renameName)
                }
                renameTarget = nil
            }
        } message: {
            Text("Enter a new name for this item.")
        }
        .alert("Delete Immediately", isPresented: $viewModel.showDeleteImmediatelyConfirm) {
            Button("Cancel", role: .cancel) {}
            Button("Delete Immediately", role: .destructive) {
                viewModel.deleteImmediatelySelectedItems()
            }
        } message: {
            let count = viewModel.selectedItems.count
            Text(count == 1
                ? "This item will be deleted immediately. You can't undo this action."
                : "\(count) items will be deleted immediately. You can't undo this action.")
        }
        .sheet(isPresented: $showAnalysis) {
            StorageAnalysisSheet(path: viewModel.currentPath)
        }
        .onChange(of: viewModel.focusSearchField) { shouldFocus in
            guard shouldFocus else { return }
            viewModel.focusSearchField = false
            isSearchFocused = true
        }
        .onAppear { installMonitors() }
        .onDisappear { removeMonitors() }
    }

    // MARK: - Top bar

    private var topBar: some View {
        VStack(spacing: 4) {
            HStack(spacing: 6) {
                navButton("sidebar.left", help: "Show/Hide Sidebar") {
                    withAnimation {
                        columnVisibility = columnVisibility == .detailOnly ? .all : .detailOnly
                    }
                }

                navButton("chevron.left", help: "Back") { viewModel.goBack() }
                    .disabled(!viewModel.canGoBack)

                navButton("chevron.right", help: "Forward") { viewModel.goForward() }
                    .disabled(!viewModel.canGoForward)

                navButton("arrow.up", help: "Enclosing Folder") { viewModel.navigateToParent() }

                navButton("house", help: "Home") { viewModel.navigateToHome() }

                PathBar(viewModel: viewModel)
                    .frame(minWidth: 140, maxWidth: .infinity)

                searchField
                searchScopeMenu

                if let branch = viewModel.gitBranch {
                    HStack(spacing: 3) {
                        Image(systemName: "arrow.triangle.branch")
                        Text(branch).lineLimit(1)
                    }
                    .font(.caption)
                    .foregroundColor(.secondary)
                }

                Picker("View", selection: $settings.viewMode) {
                    ForEach(ViewMode.allCases) { mode in
                        Image(systemName: mode.systemImage)
                            .help(mode.title)
                            .tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .frame(width: 118)

                Menu {
                    Picker("Lọc", selection: $viewModel.filterMode) {
                        ForEach(FileFilterMode.allCases) { mode in
                            Label(mode.title, systemImage: mode.icon)
                                .tag(mode)
                        }
                    }

                    Divider()

                    Toggle(isOn: $viewModel.isMultiSelectMode) {
                        Label("Chế độ chọn nhiều file", systemImage: "checkmark.square")
                    }

                    Toggle(isOn: $settings.showItemCheckBoxes) {
                        Label("Hỗ trợ hộp kiểm (Checkboxes)", systemImage: "checklist")
                    }

                    Divider()

                    Button("Chọn tất cả (⌘A)") {
                        viewModel.selectAll()
                    }

                    Button("Chọn tất cả thư mục") {
                        viewModel.selectAllFolders()
                    }

                    Button("Chọn tất cả tệp tin") {
                        viewModel.selectAllFiles()
                    }

                    Button("Đảo ngược vùng chọn") {
                        viewModel.invertSelection()
                    }

                    Button("Bỏ chọn tất cả (Esc)") {
                        viewModel.deselectAll()
                    }
                    .disabled(viewModel.selectedItems.isEmpty)
                } label: {
                    Image(systemName: viewModel.filterMode == .all ? "line.3.horizontal.decrease.circle" : "line.3.horizontal.decrease.circle.fill")
                        .foregroundColor(viewModel.filterMode == .all ? .secondary : .accentColor)
                }
                .menuStyle(.borderlessButton)
                .help("Lọc & Chọn: \(viewModel.filterMode.title)")

                navButton(
                    viewModel.isMultiSelectMode ? "checkmark.square.fill" : "checkmark.square",
                    help: "Chế độ chọn nhiều file"
                ) {
                    viewModel.isMultiSelectMode.toggle()
                }
                .foregroundColor(viewModel.isMultiSelectMode ? .accentColor : .primary)

                navButton(settings.showHiddenFiles ? "eye" : "eye.slash", help: "Show Hidden Files") {
                    settings.showHiddenFiles.toggle()
                }

                navButton("trash", help: "Move to Trash (⌘⌫)") {
                    viewModel.trashSelectedItems()
                }
                .disabled(viewModel.selectedItems.isEmpty)

                navButton("chevron.left.forwardslash.chevron.right", help: "Open in VS Code") {
                    TerminalService.shared.openIDE(at: viewModel.currentPath, ide: .vscode)
                }

                navButton(viewModel.showPreviewPane ? "sidebar.right" : "sidebar.trailing", help: "Toggle Preview Pane (⌥P)") {
                    withAnimation(.easeInOut(duration: 0.15)) {
                        viewModel.showPreviewPane.toggle()
                    }
                }
                .foregroundColor(viewModel.showPreviewPane ? .accentColor : .primary)

                navButton("line.3.horizontal.decrease.circle", help: "Quick Filter (/)") {
                    viewModel.showQuickFilterBar.toggle()
                }
                .foregroundColor((!viewModel.quickFilter.isEmpty || viewModel.showQuickFilterBar) ? .accentColor : .primary)

                navButton("terminal", help: "Open in Terminal") {
                    TerminalService.shared.openTerminal(at: viewModel.currentPath)
                }

                navButton("arrow.clockwise", help: "Refresh (F5 / ⌘R)") {
                    viewModel.refresh()
                }

                if viewModel.isLoading {
                    ProgressView()
                        .controlSize(.small)
                }
            }
            .padding(.horizontal, 10)
            .padding(.top, 6)

            if let error = viewModel.errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundColor(.red)
                    .lineLimit(2)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 12)
            }
        }
        .padding(.bottom, 6)
        .contentShape(Rectangle())
        .onTapGesture(count: 2) {
            handleTitleBarDoubleClick()
        }
    }

    private func handleTitleBarDoubleClick() {
        guard let window = NSApp.keyWindow else { return }
        let action = UserDefaults.standard.string(forKey: "AppleActionOnDoubleClick")
        if action == "Minimize" {
            window.performMiniaturize(nil)
        } else {
            window.zoom(nil)
        }
    }

    private var searchField: some View {
        HStack(spacing: 4) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.secondary)

            TextField("Search", text: $viewModel.searchQuery)
                .textFieldStyle(.plain)
                .focused($isSearchFocused)

            if !viewModel.searchQuery.isEmpty {
                Button {
                    viewModel.leaveSearch()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.borderless)
                .help("Clear search")
            }
        }
        .padding(.horizontal, 7)
        .padding(.vertical, 3)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(Color(nsColor: .controlBackgroundColor))
        )
        .frame(width: 200)
        .help("Search in this folder (⌘F)")
    }

    private var searchScopeMenu: some View {
        Menu {
            ForEach(FileListViewModel.SearchScope.allCases) { scope in
                Button {
                    viewModel.searchScope = scope
                } label: {
                    if viewModel.searchScope == scope {
                        Label(scope.rawValue, systemImage: "checkmark")
                    } else {
                        Text(scope.rawValue)
                    }
                }
            }
        } label: {
            Image(systemName: "text.magnifyingglass")
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
        .help("Search in file names or in file contents")
    }

    private func navButton(_ systemImage: String, help: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .frame(width: 18, height: 18)
        }
        .buttonStyle(.borderless)
        .help(help)
    }

    // MARK: - Quick Filter Bar

    private var quickFilterBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "line.3.horizontal.decrease.circle.fill")
                .foregroundColor(.accentColor)

            Text("Lọc nhanh:")
                .font(.caption.weight(.semibold))
                .foregroundColor(.secondary)

            TextField("Gõ từ khoá để lọc file trực tiếp... (Esc để thoát)", text: $viewModel.quickFilter)
                .textFieldStyle(.plain)
                .font(.caption)
                .focused($isQuickFilterFocused)

            if !viewModel.quickFilter.isEmpty {
                Button {
                    viewModel.quickFilter = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }

            Button {
                viewModel.quickFilter = ""
                viewModel.showQuickFilterBar = false
            } label: {
                Image(systemName: "xmark")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
            .help("Đóng thanh lọc nhanh")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(Color(nsColor: .controlBackgroundColor))
        .onAppear {
            isQuickFilterFocused = true
        }
    }

    private func handleDrop(providers: [NSItemProvider], targetFolder: String? = nil) -> Bool {
        var urls: [URL] = []
        let group = DispatchGroup()
        for provider in providers {
            group.enter()
            _ = provider.loadObject(ofClass: URL.self) { url, _ in
                if let url = url {
                    DispatchQueue.main.async {
                        urls.append(url)
                    }
                }
                group.leave()
            }
        }
        group.notify(queue: .main) {
            if !urls.isEmpty {
                viewModel.importFiles(urls: urls, to: targetFolder)
            }
        }
        return true
    }

    // MARK: - Content

    @ViewBuilder
    private var content: some View {
        if viewModel.isSearchActive {
            SearchResultsView(viewModel: viewModel)
        } else if viewModel.isLoading && viewModel.files.isEmpty {
            ProgressView("Loading…")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if let error = viewModel.errorMessage, viewModel.files.isEmpty {
            VStack(spacing: 10) {
                Image(systemName: "exclamationmark.triangle")
                    .font(.largeTitle)
                Text(error)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                Button("Retry") { viewModel.refresh() }
            }
            .padding()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if viewModel.displayedFiles.isEmpty {
            VStack(spacing: 8) {
                Image(systemName: viewModel.filterMode == .all ? "folder" : viewModel.filterMode.icon)
                    .font(.system(size: 40))
                    .foregroundColor(.secondary)
                Text(viewModel.filterMode == .all ? "Folder is empty" : "No \(viewModel.filterMode.rawValue.lowercased()) in this folder")
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .contentShape(Rectangle())
            .onTapGesture {
                viewModel.deselectAll()
            }
            .contextMenu { backgroundMenu }
        } else {
            switch settings.viewMode {
            case .list:
                listView
            case .icons:
                iconsView
            case .gallery:
                galleryView
            }
        }
    }

    // MARK: - List

    private var listView: some View {
        Table(viewModel.displayedFiles, selection: $viewModel.selectedItems, sortOrder: $viewModel.sortOrder) {
            TableColumn("Name", value: \.name) { file in
                tableCell(for: file) {
                    FileNameCell(file: file, viewModel: viewModel, settings: settings)
                }
            }
            .width(min: 220, max: 500)

            TableColumn("Size", value: \.size) { file in
                tableCell(for: file) {
                    Text(viewModel.sizeText(for: file))
                        .monospacedDigit()
                        .frame(maxWidth: .infinity, alignment: .trailing)
                }
            }
            .width(min: 90, max: 140)

            TableColumn("Kind", value: \.kind) { file in
                tableCell(for: file) {
                    Text(file.kind)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }
            .width(min: 100, max: 180)

            TableColumn("Modified", value: \.modified) { file in
                tableCell(for: file) {
                    Text(file.formattedDate)
                        .foregroundColor(.secondary)
                        .monospacedDigit()
                }
            }
            .width(min: 130, max: 180)
        }
        .tableStyle(.inset(alternatesRowBackgrounds: true))
        .background(
            TableDoubleClickHandler { row in
                if row >= 0 && row < viewModel.displayedFiles.count {
                    let file = viewModel.displayedFiles[row]
                    viewModel.openItem(file)
                }
            }
        )
        .contextMenu { backgroundMenu }
    }

    private func tableCell<Content: View>(
        for file: FileItem,
        @ViewBuilder content: () -> Content
    ) -> some View {
        content()
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
            .if(settings.singleClickOpen) { view in
                view.onTapGesture { handleSingleClick(file) }
            }
            .onDrag {
                NSItemProvider(contentsOf: URL(fileURLWithPath: file.path)) ?? NSItemProvider()
            }
            .if(file.isDirectory) { view in
                view.onDrop(of: [.fileURL], isTargeted: nil) { providers in
                    handleDrop(providers: providers, targetFolder: file.path)
                }
            }
            .contextMenu {
                FileItemActions(viewModel: viewModel, file: file, onRename: beginRename)
            }
    }

    // MARK: - Icons

    private var iconsView: some View {
        ScrollView {
            VStack(spacing: 0) {
                LazyVGrid(
                    columns: [GridItem(.adaptive(minimum: settings.iconSize + 44), spacing: 14)],
                    spacing: 18
                ) {
                    ForEach(viewModel.displayedFiles) { file in
                        FileIconCard(
                            file: file,
                            viewModel: viewModel,
                            settings: settings,
                            onGridTap: handleGridTap,
                            onRename: beginRename
                        )
                    }
                }
                .padding(16)

                Color.clear
                    .frame(maxWidth: .infinity, minHeight: 120)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        viewModel.deselectAll()
                    }
            }
        }
        .background(
            Color.clear
                .contentShape(Rectangle())
                .onTapGesture {
                    viewModel.deselectAll()
                }
        )
        .contextMenu { backgroundMenu }
    }

    // MARK: - Gallery

    private var galleryView: some View {
        VStack(spacing: 0) {
            Group {
                if let file = viewModel.focusedFile {
                    GalleryPreview(file: file, viewModel: viewModel)
                } else {
                    VStack(spacing: 12) {
                        Image(systemName: "photo.on.rectangle")
                            .font(.system(size: 54))
                            .foregroundColor(.secondary)
                        Text("Select an item to preview")
                            .foregroundColor(.secondary)
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(nsColor: .textBackgroundColor).opacity(0.35))
            .contentShape(Rectangle())
            .onTapGesture {
                viewModel.deselectAll()
            }

            Divider()

            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 8) {
                    ForEach(viewModel.displayedFiles) { file in
                        FileGalleryThumbnail(
                            file: file,
                            viewModel: viewModel,
                            settings: settings,
                            onGridTap: handleGridTap,
                            onRename: beginRename
                        )
                    }
                }
                .padding(10)
            }
            .frame(height: 96)
        }
        .contextMenu { backgroundMenu }
    }

    // MARK: - Status bar

    private var statusBar: some View {
        HStack(spacing: 16) {
            if viewModel.isSearchActive {
                Text("\(viewModel.searchHits.count) results")
            } else if viewModel.filterMode != .all {
                Text("\(viewModel.displayedFiles.count) of \(viewModel.files.count) items (\(viewModel.filterMode.title))")
            } else {
                Text("\(viewModel.files.count) items")
            }

            if !viewModel.selectedItems.isEmpty {
                Text("\(viewModel.selectedItems.count) selected")
                if let size = selectionSizeText {
                    Text(size)
                }
            }

            Spacer()

            if let free = viewModel.volumeFreeSpace {
                Text("\(Self.sizeFormatter.string(fromByteCount: Int64(free))) free")
            }

            if let branch = viewModel.gitBranch {
                Label(branch, systemImage: "arrow.triangle.branch")
            }
        }
        .font(.caption)
        .foregroundColor(.secondary)
        .lineLimit(1)
        .padding(.horizontal, 12)
        .padding(.vertical, 5)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(nsColor: .windowBackgroundColor))
        .contentShape(Rectangle())
        .onTapGesture {
            viewModel.deselectAll()
        }
    }

    private var selectionSizeText: String? {
        let sizes = viewModel.selectedFileItems
            .filter { !$0.isDirectory }
            .map { $0.size }
        guard !sizes.isEmpty else { return nil }
        let total = sizes.reduce(0, +)
        return Self.sizeFormatter.string(fromByteCount: Int64(total))
    }

    private static let sizeFormatter: ByteCountFormatter = {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB, .useGB]
        formatter.countStyle = .file
        return formatter
    }()

    // MARK: - Interaction

    private func handleSingleClick(_ file: FileItem) {
        if settings.singleClickOpen && file.isDirectory {
            viewModel.openItem(file)
        } else {
            viewModel.selectOnly(file.path)
        }
    }

    private func handleGridTap(_ file: FileItem) {
        let flags = NSEvent.modifierFlags.intersection(.deviceIndependentFlagsMask)

        // Kiểm tra double-click chuẩn hệ thống macOS (dựa vào thời gian và thiết lập hệ thống)
        let now = Date().timeIntervalSinceReferenceDate
        let isDoubleClick = viewModel.lastClickedPath == file.path && (now - viewModel.lastClickTime) < NSEvent.doubleClickInterval

        if isDoubleClick && flags.isEmpty {
            viewModel.lastClickTime = 0
            viewModel.lastClickedPath = nil
            viewModel.openItem(file)
            return
        }

        viewModel.lastClickTime = now
        viewModel.lastClickedPath = file.path

        if flags.contains(.command) {
            viewModel.toggleSelection(file.path)
        } else if flags.contains(.shift) {
            viewModel.selectRange(to: file.path)
        } else if settings.singleClickOpen && file.isDirectory {
            viewModel.openItem(file)
        } else {
            viewModel.selectOnly(file.path)
        }
    }

    private func isSelected(_ file: FileItem) -> Bool {
        viewModel.selectedItems.contains(file.path)
    }

    private func beginRename(_ file: FileItem) {
        renameTarget = file
        renameName = file.name
        isRenaming = true
    }

    @ViewBuilder
    private var backgroundMenu: some View {
        Button("New File") {
            if let newPath = viewModel.createNewFile(),
               let file = viewModel.files.first(where: { $0.path == newPath }) {
                beginRename(file)
            }
        }

        Button("New Folder") {
            if let newPath = viewModel.createNewFolder(),
               let folder = viewModel.files.first(where: { $0.path == newPath }) {
                beginRename(folder)
            }
        }

        Button("Paste") {
            viewModel.paste()
        }
        .disabled(!FilePasteboard.hasFiles)

        Divider()

        Toggle(isOn: $settings.showItemCheckBoxes) {
            Text("Show Item Checkboxes")
        }

        Divider()

        Menu("Selection") {
            Button("Select All (⌘A)") {
                viewModel.selectAll()
            }
            Button("Select All Folders") {
                viewModel.selectAllFolders()
            }
            Button("Select All Files") {
                viewModel.selectAllFiles()
            }
            Button("Invert Selection") {
                viewModel.invertSelection()
            }
            Button("Deselect All (Esc)") {
                viewModel.deselectAll()
            }
            .disabled(viewModel.selectedItems.isEmpty)
        }

        if !viewModel.selectedItems.isEmpty {
            Divider()

            Button("Move to Trash (⌘⌫)") {
                viewModel.trashSelectedItems()
            }

            Button("Delete Immediately… (⌥⌘⌫)") {
                viewModel.requestDeleteImmediately()
            }
        }

        Divider()

        Button("Refresh") {
            viewModel.refresh()
        }

        Button("Analyze Storage…") {
            showAnalysis = true
        }

        Button(settings.showHiddenFiles ? "Hide Hidden Files" : "Show Hidden Files") {
            settings.showHiddenFiles.toggle()
        }
    }

    static func gitStatusColor(_ status: GitStatus) -> Color {
        switch status {
        case .modified: return .orange
        case .untracked: return .green
        case .staged: return .blue
        case .conflict: return .red
        case .none: return .clear
        }
    }

    // MARK: - Bàn phím & Chuột (Deselect khi click ngoài, Space, Backspace/Delete...)

    private func installMonitors() {
        guard keyMonitor == nil else { return }

        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            self.handleKey(event)
        }

        mouseMonitor = NSEvent.addLocalMonitorForEvents(matching: .leftMouseDown) { event in
            self.handleMouseDown(event)
            return event
        }
    }

    private func removeMonitors() {
        if let keyMonitor {
            NSEvent.removeMonitor(keyMonitor)
        }
        keyMonitor = nil

        if let mouseMonitor {
            NSEvent.removeMonitor(mouseMonitor)
        }
        mouseMonitor = nil
    }

    private func handleMouseDown(_ event: NSEvent) {
        guard let window = event.window, window === NSApp.keyWindow else { return }

        // 1. Huỷ trạng thái sửa đường dẫn & nhả focus khi bấm ra bên ngoài
        if viewModel.isEditingPath {
            if let textResponder = window.firstResponder as? NSTextView {
                let clickLocation = event.locationInWindow
                let locationInResponder = textResponder.convert(clickLocation, from: nil)
                let expandedBounds = textResponder.bounds.insetBy(dx: -12, dy: -8)

                if !expandedBounds.contains(locationInResponder) {
                    viewModel.cancelPathEditing()
                    DispatchQueue.main.async {
                        window.makeFirstResponder(nil)
                    }
                }
            } else {
                viewModel.cancelPathEditing()
            }
        }

        // 2. Bỏ chọn khi click vào vùng trống của bảng (NSTableView rỗng bên dưới các row)
        guard !viewModel.selectedItems.isEmpty else { return }

        // Nếu người dùng đang giữ ⌘ hoặc ⇧ thì không can thiệp (chọn thêm vùng)
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        if flags.contains(.command) || flags.contains(.shift) {
            return
        }

        guard let hitView = window.contentView?.hitTest(event.locationInWindow) else { return }

        // Chỉ bỏ chọn khi người dùng click vào vùng trống thật sự của NSTableView (không phải row, cell, header hay scroller)
        if hitView is NSTableView || hitView is NSClipView {
            if let tableView = (hitView as? NSTableView) ?? (hitView.enclosingScrollView?.documentView as? NSTableView) {
                let pointInTable = tableView.convert(event.locationInWindow, from: nil)
                let row = tableView.row(at: pointInTable)
                if row < 0 {
                    viewModel.deselectAll()
                }
            }
        }
    }

    private func handleKey(_ event: NSEvent) -> NSEvent? {
        // Nếu đang sửa đường dẫn và bấm Escape: huỷ ngay lập tức
        if event.keyCode == 53 && viewModel.isEditingPath {
            viewModel.cancelPathEditing()
            NSApp.keyWindow?.makeFirstResponder(nil)
            return nil
        }

        // Không chặn khi người dùng đang gõ trong ô tìm kiếm/đường dẫn.
        if let responder = NSApp.keyWindow?.firstResponder, responder is NSTextView {
            return event
        }

        // Đang đứng trên button/menu (vd. đang mở menu) -> để control tự xử lý.
        if let responder = NSApp.keyWindow?.firstResponder,
           responder is NSButton || responder is NSPopUpButton || responder is NSComboBox {
            return event
        }

        // Sheet (Rename alert, Analyze sheet) đang mở -> không can thiệp.
        if let window = NSApp.keyWindow, window.isSheet {
            return event
        }

        // Quick Look đang mở -> để panel tự xử lý phím (Escape/Space đóng panel).
        if QLPreviewPanel.sharedPreviewPanelExists(), NSApp.keyWindow === QLPreviewPanel.shared() {
            return event
        }

        // Phím mũi tên trên một số bàn phím Apple mang cờ .function — loại ra
        // để "không có modifier" vẫn đúng nghĩa.
        let flags = event.modifierFlags
            .intersection(.deviceIndependentFlagsMask)
            .subtracting(.function)
        let isPlain = flags.isEmpty || flags == .shift

        switch event.keyCode {
        case 120: // F2: Đổi tên (Rename theo kiểu Windows)
            guard let file = viewModel.selectedFileItems.first else { return event }
            beginRename(file)
            return nil

        case 96: // F5: Làm mới (Refresh theo kiểu Windows)
            viewModel.refresh()
            return nil

        case 49: // Space: Quick Look
            guard flags.isEmpty else { return event }
            QuickLookController.shared.toggle(urls: viewModel.previewURLs)
            return nil

        case 36: // Return: mở item đang chọn
            guard flags.isEmpty, !viewModel.isSearchActive else { return event }
            viewModel.openFocusedItem()
            return nil

        case 35 where flags.contains(.option): // ⌥P: Toggle Preview Pane
            withAnimation(.easeInOut(duration: 0.15)) {
                viewModel.showPreviewPane.toggle()
            }
            return nil

        case 44 where isPlain: // /: Mở Quick Filter
            viewModel.showQuickFilterBar = true
            return nil

        case 53: // Escape: thoát tìm kiếm, lọc nhanh hoặc bỏ chọn tất cả
            if !viewModel.quickFilter.isEmpty || viewModel.showQuickFilterBar {
                viewModel.quickFilter = ""
                viewModel.showQuickFilterBar = false
                return nil
            }
            if viewModel.isSearchActive {
                viewModel.leaveSearch()
                return nil
            }
            if !viewModel.selectedItems.isEmpty {
                viewModel.deselectAll()
                return nil
            }
            return event

        case 51, 117: // Backspace / Forward Delete: xoá vào thùng rác hoặc xoá ngay
            guard !viewModel.selectedItems.isEmpty else { return event }
            if flags.contains(.command) && flags.contains(.option) {
                viewModel.requestDeleteImmediately()
                return nil
            } else if flags.contains(.command) || isPlain {
                viewModel.trashSelectedItems()
                return nil
            }
            return event

        case 123 where flags.contains(.option): // ⌥←: Back (Windows Alt+Left)
            viewModel.goBack()
            return nil

        case 124 where flags.contains(.option): // ⌥→: Forward (Windows Alt+Right)
            viewModel.goForward()
            return nil

        case 126 where flags.contains(.option): // ⌥↑: Up (Windows Alt+Up)
            viewModel.navigateToParent()
            return nil

        case 123, 124, 125, 126: // Phím mũi tên
            // Chỉ chặn khi không có modifier (⌘↑ = Go menu, Shift+ arrow = chọn
            // vùng, còn List mode để Table tự xử lý).
            guard flags.isEmpty,
                  settings.viewMode != .list,
                  !viewModel.isSearchActive else { return event }
            switch event.keyCode {
            case 123, 126: viewModel.moveSelection(by: -1) // trái / lên
            default: viewModel.moveSelection(by: 1)        // phải / xuống
            }
            return nil

        default:
            break
        }

        // Gõ để chọn (type-to-select) khi không giữ phím chức năng.
        guard isPlain,
              !viewModel.isSearchActive,
              let characters = event.charactersIgnoringModifiers,
              characters.count == 1,
              let character = characters.first,
              character.isLetter || character.isNumber else {
            return event
        }

        viewModel.selectByTyping(String(character))
        return nil
    }
}

// MARK: - Tag dots

/// Chấm màu tag Finder hiển thị cạnh tên file.
struct TagDots: View {
    let tags: [FinderTag]

    var body: some View {
        if !tags.isEmpty {
            HStack(spacing: 3) {
                ForEach(tags) { tag in
                    Circle()
                        .fill(tag.color)
                        .frame(width: 8, height: 8)
                }
            }
        }
    }
}

// MARK: - File Name Cell (List View)

private struct FileNameCell: View {
    let file: FileItem
    @ObservedObject var viewModel: FileListViewModel
    @ObservedObject var settings: AppSettings

    @State private var isHovered = false

    private var isSelected: Bool {
        viewModel.selectedItems.contains(file.path)
    }

    private var isMultiSelecting: Bool {
        viewModel.isMultiSelectMode || viewModel.selectedItems.count > 1
    }

    private var showCheckbox: Bool {
        guard settings.showItemCheckBoxes else { return false }
        if isMultiSelecting { return true }
        if isHovered { return true }
        return false
    }

    var body: some View {
        HStack(spacing: 6) {
            if showCheckbox {
                Button {
                    viewModel.toggleSelection(file.path)
                } label: {
                    Image(systemName: isSelected ? "checkmark.square.fill" : "square")
                        .font(.system(size: 13))
                        .foregroundColor(isSelected ? .accentColor : .secondary)
                }
                .buttonStyle(.plain)
                .help(isSelected ? "Bỏ chọn" : "Chọn")
            }

            Image(systemName: file.icon)
                .foregroundColor(file.iconColor)
                .frame(width: 16)

            Text(file.name)
                .foregroundColor(file.isHidden ? .secondary : .primary)
                .lineLimit(1)

            if file.gitStatus != .none {
                Text(file.gitStatus.rawValue)
                    .font(.caption2)
                    .padding(.horizontal, 4)
                    .padding(.vertical, 1)
                    .background(FileListView.gitStatusColor(file.gitStatus))
                    .cornerRadius(4)
            }

            TagDots(tags: file.tags)
        }
        .onHover { hovering in
            isHovered = hovering
        }
    }
}

// MARK: - File Icon Card (Icons View)

private struct FileIconCard: View {
    let file: FileItem
    @ObservedObject var viewModel: FileListViewModel
    @ObservedObject var settings: AppSettings
    let onGridTap: (FileItem) -> Void
    let onRename: (FileItem) -> Void

    @State private var isHovered = false

    private var isSelected: Bool {
        viewModel.selectedItems.contains(file.path)
    }

    private var isMultiSelecting: Bool {
        viewModel.isMultiSelectMode || viewModel.selectedItems.count > 1
    }

    private var showCheckbox: Bool {
        guard settings.showItemCheckBoxes else { return false }
        if isMultiSelecting { return true }
        if isHovered { return true }
        return false
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            VStack(spacing: 6) {
                FileThumbnail(file: file, size: settings.iconSize)
                    .shadow(color: .black.opacity(0.08), radius: 3, y: 1)

                Text(file.name)
                    .font(.caption)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .foregroundColor(file.isHidden ? .secondary : .primary)

                TagDots(tags: file.tags)
            }
            .padding(8)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 9)
                    .fill(isSelected ? Color.accentColor.opacity(0.18) : Color.clear)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 9)
                    .stroke(isSelected ? Color.accentColor.opacity(0.5) : Color.clear, lineWidth: 1)
            )
            .contentShape(Rectangle())
            .onTapGesture { onGridTap(file) }
            .onDrag {
                NSItemProvider(contentsOf: URL(fileURLWithPath: file.path)) ?? NSItemProvider()
            }
            .contextMenu {
                FileItemActions(viewModel: viewModel, file: file, onRename: onRename)
            }

            if showCheckbox {
                Button {
                    viewModel.toggleSelection(file.path)
                } label: {
                    Image(systemName: isSelected ? "checkmark.square.fill" : "square")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(isSelected ? .accentColor : .secondary)
                        .padding(3)
                        .background(
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color(nsColor: .controlBackgroundColor).opacity(0.85))
                        )
                }
                .buttonStyle(.plain)
                .padding(4)
                .help(isSelected ? "Bỏ chọn" : "Chọn")
            }
        }
        .onHover { hovering in
            isHovered = hovering
        }
    }
}

// MARK: - File Gallery Thumbnail (Gallery View)

private struct FileGalleryThumbnail: View {
    let file: FileItem
    @ObservedObject var viewModel: FileListViewModel
    @ObservedObject var settings: AppSettings
    let onGridTap: (FileItem) -> Void
    let onRename: (FileItem) -> Void

    @State private var isHovered = false

    private var isSelected: Bool {
        viewModel.selectedItems.contains(file.path)
    }

    private var isMultiSelecting: Bool {
        viewModel.isMultiSelectMode || viewModel.selectedItems.count > 1
    }

    private var showCheckbox: Bool {
        guard settings.showItemCheckBoxes else { return false }
        if isMultiSelecting { return true }
        if isHovered { return true }
        return false
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            VStack(spacing: 4) {
                FileThumbnail(file: file, size: 54)
                Text(file.name)
                    .font(.caption2)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .frame(width: 78)
                TagDots(tags: file.tags)
            }
            .padding(6)
            .background(
                RoundedRectangle(cornerRadius: 7)
                    .fill(isSelected ? Color.accentColor.opacity(0.18) : Color.clear)
            )
            .contentShape(Rectangle())
            .onTapGesture { onGridTap(file) }
            .onDrag {
                NSItemProvider(contentsOf: URL(fileURLWithPath: file.path)) ?? NSItemProvider()
            }
            .contextMenu {
                FileItemActions(viewModel: viewModel, file: file, onRename: onRename)
            }

            if showCheckbox {
                Button {
                    viewModel.toggleSelection(file.path)
                } label: {
                    Image(systemName: isSelected ? "checkmark.square.fill" : "square")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(isSelected ? .accentColor : .secondary)
                        .padding(2)
                        .background(
                            RoundedRectangle(cornerRadius: 3)
                                .fill(Color(nsColor: .controlBackgroundColor).opacity(0.85))
                        )
                }
                .buttonStyle(.plain)
                .padding(2)
                .help(isSelected ? "Bỏ chọn" : "Chọn")
            }
        }
        .onHover { hovering in
            isHovered = hovering
        }
    }
}

// MARK: - Thumbnail

@MainActor
struct FileThumbnail: View {
    let file: FileItem
    let size: CGFloat

    @State private var image: NSImage?

    var body: some View {
        Group {
            if let image {
                Image(nsImage: image)
                    .resizable()
                    .interpolation(.high)
                    .aspectRatio(contentMode: .fit)
            } else {
                Image(systemName: file.icon)
                    .font(.system(size: max(14, size * 0.58)))
                    .foregroundColor(file.iconColor)
            }
        }
        .frame(width: size, height: size)
        .task(id: file.path) {
            image = await ThumbnailService.shared.thumbnail(for: file.path, size: size * 2)
        }
    }
}

// MARK: - Gallery preview

private struct GalleryPreview: View {
    let file: FileItem
    @ObservedObject var viewModel: FileListViewModel

    @State private var image: NSImage?

    var body: some View {
        VStack(spacing: 10) {
            ZStack {
                if let image {
                    Image(nsImage: image)
                        .resizable()
                        .interpolation(.high)
                        .aspectRatio(contentMode: .fit)
                } else {
                    Image(systemName: file.icon)
                        .font(.system(size: 82))
                        .foregroundColor(file.iconColor)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(20)

            VStack(spacing: 3) {
                Text(file.name)
                    .font(.headline)
                    .lineLimit(1)
                    .truncationMode(.middle)

                Text("\(file.kind) · \(viewModel.sizeText(for: file))")
                    .font(.caption)
                    .foregroundColor(.secondary)

                if !file.tags.isEmpty {
                    HStack(spacing: 6) {
                        ForEach(file.tags) { tag in
                            HStack(spacing: 4) {
                                Circle()
                                    .fill(tag.color)
                                    .frame(width: 8, height: 8)
                                Text(tag.name)
                                    .font(.caption2)
                            }
                        }
                    }
                }

                Text(file.path)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 12)
        }
        .task(id: file.path) {
            image = await ThumbnailService.shared.thumbnail(for: file.path, size: 1400)
        }
    }
}

// MARK: - Table Double Click Handler (Native AppKit doubleAction)

@MainActor
private struct TableDoubleClickHandler: NSViewRepresentable {
    let onDoubleClick: (Int) -> Void

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async {
            if let tableView = findTableView(from: view) {
                context.coordinator.attach(to: tableView, handler: onDoubleClick)
            }
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        context.coordinator.handler = onDoubleClick
        if context.coordinator.tableView == nil {
            DispatchQueue.main.async {
                if let tableView = findTableView(from: nsView) {
                    context.coordinator.attach(to: tableView, handler: onDoubleClick)
                }
            }
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(handler: onDoubleClick)
    }

    @MainActor
    class Coordinator: NSObject {
        var handler: (Int) -> Void
        weak var tableView: NSTableView?

        init(handler: @escaping (Int) -> Void) {
            self.handler = handler
        }

        func attach(to tableView: NSTableView, handler: @escaping (Int) -> Void) {
            self.tableView = tableView
            self.handler = handler
            tableView.target = self
            tableView.doubleAction = #selector(onTableDoubleClick(_:))
        }

        @objc func onTableDoubleClick(_ sender: NSTableView) {
            let row = sender.clickedRow
            if row >= 0 {
                handler(row)
            }
        }
    }

    private func findTableView(from view: NSView) -> NSTableView? {
        var current: NSView? = view
        while let c = current {
            if let tv = c as? NSTableView {
                return tv
            }
            if let sv = c as? NSScrollView, let tv = sv.documentView as? NSTableView {
                return tv
            }
            for sub in c.subviews {
                if let tv = sub as? NSTableView {
                    return tv
                }
                if let sv = sub as? NSScrollView, let tv = sv.documentView as? NSTableView {
                    return tv
                }
            }
            current = c.superview
        }
        return nil
    }
}
