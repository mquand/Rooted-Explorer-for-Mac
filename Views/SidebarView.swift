import SwiftUI
import AppKit

struct SidebarView: View {
    @StateObject private var viewModel = SidebarViewModel()
    @ObservedObject var fileListViewModel: FileListViewModel
    @EnvironmentObject private var settings: AppSettings

    @State private var favorites: [FavoriteLocation] = []
    @State private var isHDExpanded: Bool = true

    private var selectedPath: String {
        fileListViewModel.currentPath
    }

    private func loadFavorites() {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        let candidates = [
            FavoriteLocation(name: "Home", path: home, icon: "house"),
            FavoriteLocation(
                name: "Desktop",
                path: (home as NSString).appendingPathComponent("Desktop"),
                icon: "desktopcomputer"
            ),
            FavoriteLocation(
                name: "Downloads",
                path: (home as NSString).appendingPathComponent("Downloads"),
                icon: "arrow.down.circle"
            ),
            FavoriteLocation(
                name: "Documents",
                path: (home as NSString).appendingPathComponent("Documents"),
                icon: "doc"
            ),
            FavoriteLocation(
                name: "Pictures",
                path: (home as NSString).appendingPathComponent("Pictures"),
                icon: "photo"
            ),
            FavoriteLocation(
                name: "Music",
                path: (home as NSString).appendingPathComponent("Music"),
                icon: "music.note"
            ),
            FavoriteLocation(
                name: "Applications",
                path: "/Applications",
                icon: "app.badge"
            )
        ]

        favorites = candidates.filter {
            FileManager.default.fileExists(atPath: $0.path)
        }
    }

    private var rootVolumeName: String {
        if let root = viewModel.volumes.first(where: { $0.path == "/" }), !root.name.isEmpty {
            return root.name
        }
        return "Macintosh HD"
    }

    private var externalVolumes: [VolumeInfo] {
        var seen = Set<String>()
        return viewModel.volumes.filter { vol in
            guard vol.path != "/" else { return false }
            let name = vol.name.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !name.isEmpty else { return false }
            let lower = name.lowercased()

            // Lọc bỏ DMG installer của Rooted hoặc các file cài đặt tạm thời
            if lower.contains("rooted") || lower.hasPrefix("install ") {
                return false
            }

            if seen.contains(lower) {
                return false
            }
            seen.insert(lower)
            return true
        }
    }

    var body: some View {
        List {
            Section("Favorites") {
                ForEach(favorites) { item in
                    sidebarRow(name: item.name, path: item.path, icon: item.icon)
                }

                ForEach(settings.customFavorites, id: \.self) { path in
                    let name = (path as NSString).lastPathComponent
                    Button {
                        fileListViewModel.navigateTo(path: path)
                    } label: {
                        Label(name, systemImage: "folder.fill")
                            .lineLimit(1)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .listRowBackground(rowBackground(for: path))
                    .contextMenu {
                        Button("Unpin from Favorites") {
                            settings.customFavorites.removeAll { $0 == path }
                        }
                    }
                }
            }
            .onDrop(of: [.fileURL], isTargeted: nil) { providers in
                for provider in providers {
                    _ = provider.loadObject(ofClass: URL.self) { url, _ in
                        guard let url = url else { return }
                        var isDir: ObjCBool = false
                        if FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir), isDir.boolValue {
                            DispatchQueue.main.async {
                                if !settings.customFavorites.contains(url.path) {
                                    settings.customFavorites.append(url.path)
                                }
                            }
                        }
                    }
                }
                return true
            }

            Section("This PC") {
                // Ổ đĩa hệ thống chính (Macintosh HD) kèm cây thư mục có thể mở rộng
                DisclosureGroup(
                    isExpanded: $isHDExpanded
                ) {
                    ForEach(viewModel.rootNodes) { node in
                        DirectoryTreeRow(
                            node: node,
                            selectedPath: selectedPath,
                            sidebarViewModel: viewModel,
                            onSelect: { fileListViewModel.navigateTo(path: $0) }
                        )
                    }
                } label: {
                    Button {
                        fileListViewModel.navigateTo(path: "/")
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "internaldrive.fill")
                                .foregroundColor(selectedPath == "/" ? .accentColor : .primary)
                            Text(rootVolumeName)
                                .fontWeight(.medium)
                                .lineLimit(1)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
                .listRowBackground(rowBackground(for: "/"))

                // Các ổ đĩa ngoài thực tế (USB, External SSD...)
                ForEach(externalVolumes, id: \.path) { vol in
                    Button {
                        fileListViewModel.navigateTo(path: vol.path)
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "externaldrive.fill")
                                .foregroundColor(.secondary)

                            Text(vol.name)
                                .lineLimit(1)

                            Spacer(minLength: 4)

                            Button {
                                viewModel.ejectVolume(at: vol.path)
                            } label: {
                                Image(systemName: "eject")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                            .buttonStyle(.plain)
                            .help("Eject")
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .listRowBackground(rowBackground(for: vol.path))
                }
            }

            if settings.showTagsInSidebar {
                Section("Tags") {
                    ForEach(FinderTag.standard) { tag in
                        Button {
                            fileListViewModel.startTagSearch(tag)
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "circle.fill")
                                    .font(.system(size: 10))
                                    .foregroundColor(tag.color)
                                Text(tag.name)
                                    .lineLimit(1)
                                Spacer(minLength: 4)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .help("Search files with this tag")
                    }
                }
            }
        }
        .listStyle(.sidebar)
        .onAppear {
            loadFavorites()
            viewModel.refreshVolumes()
            if viewModel.rootNodes.isEmpty {
                viewModel.loadRootTree()
            }
            viewModel.revealPath(fileListViewModel.currentPath)
        }
        .onChange(of: fileListViewModel.currentPath) { newPath in
            viewModel.revealPath(newPath)
        }
    }

    private func sidebarRow(name: String, path: String, icon: String) -> some View {
        Button {
            fileListViewModel.navigateTo(path: path)
        } label: {
            Label(name, systemImage: icon)
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .listRowBackground(rowBackground(for: path))
    }

    private func rowBackground(for path: String) -> Color {
        selectedPath == path ? Color.accentColor.opacity(0.15) : Color.clear
    }
}

private struct FavoriteLocation: Identifiable {
    var id: String { path }

    let name: String
    let path: String
    let icon: String
}

private struct DirectoryTreeRow: View {
    let node: DirectoryNode
    let selectedPath: String
    @ObservedObject var sidebarViewModel: SidebarViewModel
    let onSelect: (String) -> Void

    private var isExpanded: Binding<Bool> {
        Binding(
            get: { node.isExpanded },
            set: { sidebarViewModel.toggleNode(at: node.path, expanded: $0) }
        )
    }

    var body: some View {
        if node.hasChildren {
            DisclosureGroup(isExpanded: isExpanded) {
                if node.isLoaded {
                    ForEach(node.children) { child in
                        DirectoryTreeRow(
                            node: child,
                            selectedPath: selectedPath,
                            sidebarViewModel: sidebarViewModel,
                            onSelect: onSelect
                        )
                    }
                } else {
                    HStack(spacing: 6) {
                        ProgressView().controlSize(.small)
                        Text("Loading…")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    .padding(.leading, 12)
                }
            } label: {
                rowLabel
            }
            .listRowBackground(rowBackground)
        } else {
            rowLabel
                .listRowBackground(rowBackground)
        }
    }

    private var rowLabel: some View {
        Button {
            onSelect(node.path)
        } label: {
            Label(node.name, systemImage: node.isExpanded ? "folder.fill" : "folder")
                .foregroundColor(selectedPath == node.path ? .accentColor : .primary)
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button("Open") { onSelect(node.path) }
            Button("Open in Terminal") { TerminalService.shared.openTerminal(at: node.path) }
            Button("Reveal in Finder") { NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: node.path)]) }
            Divider()
            Button("Copy Path") {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(node.path, forType: .string)
            }
        }
    }

    private var rowBackground: Color {
        selectedPath == node.path ? Color.accentColor.opacity(0.15) : Color.clear
    }
}
