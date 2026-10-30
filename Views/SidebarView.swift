import SwiftUI

struct SidebarView: View {
    @StateObject private var viewModel = SidebarViewModel()
    @ObservedObject var fileListViewModel: FileListViewModel

    private var selectedPath: String {
        fileListViewModel.currentPath
    }

    var body: some View {
        List {
            Section("Volumes") {
                ForEach(viewModel.volumes) { volume in
                    HStack {
                        Image(systemName: "externaldrive.fill")
                        Text(volume.name)
                        Spacer()
                        Text(volume.formattedFreeSpace)
                            .foregroundColor(.secondary)
                            .font(.caption)
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        fileListViewModel.navigateTo(path: volume.path)
                    }
                    .listRowBackground(rowBackground(for: volume.path))
                }
            }

            Section("Root") {
                ForEach(viewModel.rootTree) { node in
                    DirectoryTreeRow(
                        node: node,
                        selectedPath: selectedPath,
                        onSelect: { fileListViewModel.navigateTo(path: $0) },
                        onToggle: { viewModel.toggleNode(at: $0) }
                    )
                }
            }
        }
        .listStyle(.sidebar)
        .onAppear {
            viewModel.loadVolumes()
            viewModel.loadRootTree()
        }
    }

    private func rowBackground(for path: String) -> Color {
        selectedPath == path ? Color.accentColor.opacity(0.15) : Color.clear
    }
}

private struct DirectoryTreeRow: View {
    let node: DirectoryNode
    let selectedPath: String
    let onSelect: (String) -> Void
    let onToggle: (String) -> Void

    var body: some View {
        if node.hasChildren {
            DisclosureGroup(isExpanded: Binding(
                get: { node.isExpanded },
                set: { _ in onToggle(node.path) }
            )) {
                ForEach(node.children) { child in
                    DirectoryTreeRow(
                        node: child,
                        selectedPath: selectedPath,
                        onSelect: onSelect,
                        onToggle: onToggle
                    )
                }
            } label: {
                label
            }
        } else {
            label
        }
    }

    private var label: some View {
        Label(node.name, systemImage: node.path.fileIcon)
            .foregroundColor(selectedPath == node.path ? .accentColor : .primary)
            .contentShape(Rectangle())
            .onTapGesture {
                onSelect(node.path)
            }
            .contextMenu {
                Button("Open in Terminal") {
                    TerminalService.shared.openTerminal(at: node.path)
                }
            }
    }
}
