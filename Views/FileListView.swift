import SwiftUI
import AppKit

struct FileListView: View {
    @ObservedObject var viewModel: FileListViewModel
    @Binding var columnVisibility: NavigationSplitViewVisibility
    @EnvironmentObject private var settings: AppSettings

    @State private var isRenaming = false
    @State private var renameTarget: FileItem?
    @State private var renameName = ""

    var body: some View {
        VStack(spacing: 0) {
            topBar
            Divider()
            content
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

                TextField("Path", text: $viewModel.pathInput)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(.body, design: .monospaced))
                    .onSubmit { viewModel.submitPathInput() }
                    .frame(minWidth: 160, maxWidth: .infinity)

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
                    ForEach(FileListViewModel.SortOption.allCases, id: \.self) { option in
                        Button {
                            viewModel.sortOption = option
                        } label: {
                            if viewModel.sortOption == option {
                                Label(option.rawValue, systemImage: "checkmark")
                            } else {
                                Text(option.rawValue)
                            }
                        }
                    }
                } label: {
                    Image(systemName: "arrow.up.arrow.down")
                }
                .menuStyle(.borderlessButton)
                .fixedSize()
                .help("Sort")

                navButton(settings.showHiddenFiles ? "eye" : "eye.slash", help: "Show Hidden Files") {
                    settings.showHiddenFiles.toggle()
                }

                navButton("terminal", help: "Open in Terminal") {
                    TerminalService.shared.openTerminal(at: viewModel.currentPath)
                }

                navButton("arrow.clockwise", help: "Refresh") {
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
    }

    private func navButton(_ systemImage: String, help: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .frame(width: 18, height: 18)
        }
        .buttonStyle(.borderless)
        .help(help)
    }

    // MARK: - Content

    @ViewBuilder
    private var content: some View {
        if viewModel.isLoading && viewModel.files.isEmpty {
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
        } else if viewModel.files.isEmpty {
            Text("Folder is empty")
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
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
        Table(viewModel.files, selection: $viewModel.selectedItems) {
            TableColumn("Name") { file in
                tableCell(for: file) {
                    HStack(spacing: 6) {
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
                                .background(gitStatusColor(file.gitStatus))
                                .cornerRadius(4)
                        }
                    }
                }
            }
            .width(min: 220, max: 500)

            TableColumn("Size") { file in
                tableCell(for: file) {
                    Text(viewModel.sizeText(for: file))
                        .monospacedDigit()
                        .frame(maxWidth: .infinity, alignment: .trailing)
                }
            }
            .width(min: 90, max: 140)

            TableColumn("Kind") { file in
                tableCell(for: file) {
                    Text(file.kind)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }
            .width(min: 100, max: 180)

            TableColumn("Modified") { file in
                tableCell(for: file) {
                    Text(file.formattedDate)
                        .foregroundColor(.secondary)
                        .monospacedDigit()
                }
            }
            .width(min: 130, max: 180)
        }
        .tableStyle(.inset(alternatesRowBackgrounds: true))
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
            .onDoubleClick { viewModel.openItem(file) }
            .contextMenu {
                FileItemActions(viewModel: viewModel, file: file, onRename: beginRename)
            }
    }

    // MARK: - Icons

    private var iconsView: some View {
        ScrollView {
            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: settings.iconSize + 44), spacing: 14)],
                spacing: 18
            ) {
                ForEach(viewModel.files) { file in
                    VStack(spacing: 6) {
                        FileThumbnail(file: file, size: settings.iconSize)
                            .shadow(color: .black.opacity(0.08), radius: 3, y: 1)

                        Text(file.name)
                            .font(.caption)
                            .multilineTextAlignment(.center)
                            .lineLimit(2)
                            .foregroundColor(file.isHidden ? .secondary : .primary)
                    }
                    .padding(8)
                    .frame(maxWidth: .infinity)
                    .background(
                        RoundedRectangle(cornerRadius: 9)
                            .fill(isSelected(file) ? Color.accentColor.opacity(0.18) : Color.clear)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 9)
                            .stroke(isSelected(file) ? Color.accentColor.opacity(0.5) : Color.clear, lineWidth: 1)
                    )
                    .contentShape(Rectangle())
                    .onTapGesture { handleGridTap(file) }
                    .onDoubleClick { viewModel.openItem(file) }
                    .contextMenu {
                        FileItemActions(viewModel: viewModel, file: file, onRename: beginRename)
                    }
                }
            }
            .padding(16)
        }
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

            Divider()

            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 8) {
                    ForEach(viewModel.files) { file in
                        VStack(spacing: 4) {
                            FileThumbnail(file: file, size: 54)
                            Text(file.name)
                                .font(.caption2)
                                .lineLimit(1)
                                .truncationMode(.middle)
                                .frame(width: 78)
                        }
                        .padding(6)
                        .background(
                            RoundedRectangle(cornerRadius: 7)
                                .fill(isSelected(file) ? Color.accentColor.opacity(0.18) : Color.clear)
                        )
                        .contentShape(Rectangle())
                        .onTapGesture { handleGridTap(file) }
                        .onDoubleClick { viewModel.openItem(file) }
                        .contextMenu {
                            FileItemActions(viewModel: viewModel, file: file, onRename: beginRename)
                        }
                    }
                }
                .padding(10)
            }
            .frame(height: 96)
        }
        .contextMenu { backgroundMenu }
    }

    // MARK: - Interaction

    private func handleSingleClick(_ file: FileItem) {
        if settings.singleClickOpen && file.isDirectory {
            viewModel.openItem(file)
        } else {
            viewModel.selectOnly(file.path)
        }
    }

    private func handleGridTap(_ file: FileItem) {
        let flags = NSEvent.modifierFlags

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
        Button("New Folder") {
            viewModel.createNewFolder()
        }

        Button("Paste") {
            viewModel.paste()
        }
        .disabled(!FilePasteboard.hasFiles)

        Divider()

        Button("Select All") {
            viewModel.selectAll()
        }

        Button("Refresh") {
            viewModel.refresh()
        }

        Divider()

        Button(settings.showHiddenFiles ? "Hide Hidden Files" : "Show Hidden Files") {
            settings.showHiddenFiles.toggle()
        }
    }

    private func gitStatusColor(_ status: GitStatus) -> Color {
        switch status {
        case .modified: return .orange
        case .untracked: return .green
        case .staged: return .blue
        case .conflict: return .red
        case .none: return .clear
        }
    }
}

// MARK: - Thumbnail

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
