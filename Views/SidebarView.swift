import SwiftUI
import AppKit

struct SidebarView: View {
    @StateObject private var viewModel = SidebarViewModel()
    @ObservedObject var fileListViewModel: FileListViewModel

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

            if !viewModel.volumes.isEmpty {
                Section("Locations") {
                    ForEach(viewModel.volumes) { volume in
                        HStack(spacing: 8) {
                            Image(systemName: volume.path == "/" ? "internaldrive" : "externaldrive")
                                .foregroundColor(volume.path == "/" ? .primary : .secondary)

                            Text(volume.name)
                                .lineLimit(1)

                            Spacer(minLength: 4)

                            if volume.path != "/" {
                                Button {
                                    viewModel.ejectVolume(at: volume.path)
                                } label: {
                                    Image(systemName: "eject")
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                }
                                .buttonStyle(.plain)
                                .help("Eject")
                            }
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            fileListViewModel.navigateTo(path: volume.path)
                        }
                        .listRowBackground(rowBackground(for: volume.path))
                    }
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
                    .help("Search files with this tag")
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
