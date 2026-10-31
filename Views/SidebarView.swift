import SwiftUI
import AppKit

struct SidebarView: View {
    @StateObject private var viewModel = SidebarViewModel()
    @ObservedObject var fileListViewModel: FileListViewModel

    /// Tính một lần khi sidebar mở — tránh kiểm tra fileExists mỗi lần render.
    @State private var favorites: [FavoriteLocation] = []

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
                name: "Documents",
                path: (home as NSString).appendingPathComponent("Documents"),
                icon: "doc"
            ),
            FavoriteLocation(
                name: "Downloads",
                path: (home as NSString).appendingPathComponent("Downloads"),
                icon: "arrow.down.circle"
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

    var body: some View {
        List {
            Section("Favorites") {
                ForEach(favorites) { item in
                    sidebarRow(name: item.name, path: item.path, icon: item.icon)
                }
            }

            Section("Volumes") {
                ForEach(viewModel.volumes) { volume in
                    HStack {
                        Image(systemName: "externaldrive.fill")
                        Text(volume.name)
                            .lineLimit(1)
                        Spacer(minLength: 4)
                        Text(volume.formattedFreeSpace)
                            .foregroundColor(.secondary)
                            .font(.caption)

                        if volume.path != "/" {
                            Button {
                                viewModel.ejectVolume(at: volume.path)
                            } label: {
                                Image(systemName: "eject")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                            .buttonStyle(.plain)
                            .help("Eject volume")
                        }
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        fileListViewModel.navigateTo(path: volume.path)
                    }
                    .listRowBackground(rowBackground(for: volume.path))
                }
            }

            Section("Folders") {
                ForEach(viewModel.rootNodes) { node in
                    DirectoryTreeRow(
                        node: node,
                        selectedPath: selectedPath,
                        sidebarViewModel: viewModel,
                        onSelect: { fileListViewModel.navigateTo(path: $0) }
                    )
                }
            }

            Section("Tags") {
                ForEach(FinderTag.standard) { tag in
                    HStack(spacing: 8) {
                        Image(systemName: "circle.fill")
                            .font(.system(size: 10))
                            .foregroundColor(tag.color)
                        Text(tag.name)
                            .lineLimit(1)
                        Spacer(minLength: 4)
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        fileListViewModel.startTagSearch(tag)
                    }
                    .help("Tìm tất cả file gắn tag này")
                }
            }
        }
        .listStyle(.sidebar)
        .onAppear {
            loadFavorites()
            viewModel.refreshVolumes()
        }
    }

    private func sidebarRow(name: String, path: String, icon: String) -> some View {
        Label(name, systemImage: icon)
            .lineLimit(1)
            .contentShape(Rectangle())
            .onTapGesture {
                fileListViewModel.navigateTo(path: path)
            }
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
        if node.hasChildren || !node.isLoaded {
            DisclosureGroup(isExpanded: isExpanded) {
                ForEach(node.children) { child in
                    DirectoryTreeRow(
                        node: child,
                        selectedPath: selectedPath,
                        sidebarViewModel: sidebarViewModel,
                        onSelect: onSelect
                    )
                }

                if sidebarViewModel.loadingPaths.contains(node.path) {
                    HStack {
                        ProgressView()
                            .controlSize(.small)
                        Text("Loading…")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.leading, 16)
                }
            } label: {
                label
            }
            .listRowBackground(rowBackground)
        } else {
            label
                .listRowBackground(rowBackground)
        }
    }

    private var label: some View {
        Label(node.name, systemImage: node.isExpanded ? "folder.fill" : "folder")
            .foregroundColor(selectedPath == node.path ? .accentColor : .primary)
            .lineLimit(1)
            .contentShape(Rectangle())
            .onTapGesture {
                onSelect(node.path)
            }
            .contextMenu {
                Button("Open") {
                    onSelect(node.path)
                }
                Button("Open in Terminal") {
                    TerminalService.shared.openTerminal(at: node.path)
                }
                Button("Reveal in Finder") {
                    NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: node.path)])
                }
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
