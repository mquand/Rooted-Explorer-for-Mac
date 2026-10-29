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
                    treeItem(node: node)
                }
            }
        }
        .listStyle(.sidebar)
        .onAppear {
            viewModel.loadVolumes()
            viewModel.loadRootTree()
        }
    }

    @ViewBuilder
    private func treeItem(node: DirectoryNode) -> some View {
        if node.hasChildren {
            DisclosureGroup(isExpanded: Binding(
                get: { node.isExpanded },
                set: { isExpanded in
                    viewModel.toggleNode(at: node.path)
                }
            )) {
                ForEach(node.children) { child in
                    treeItem(node: child)
                }
            } label: {
                Label(node.name, systemImage: node.path.fileIcon)
                    .foregroundColor(selectedPath == node.path ? .accentColor : .primary)
                    .tag(node.path)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        fileListViewModel.navigateTo(path: node.path)
                    }
                    .contextMenu {
                        Button("Open in Terminal") {
                            TerminalService.shared.openTerminal(at: node.path)
                        }
                    }
            }
        } else {
            Label(node.name, systemImage: node.path.fileIcon)
                .foregroundColor(selectedPath == node.path ? .accentColor : .primary)
                .tag(node.path)
                .contentShape(Rectangle())
                .onTapGesture {
                    fileListViewModel.navigateTo(path: node.path)
                }
                .contextMenu {
                    Button("Open in Terminal") {
                        TerminalService.shared.openTerminal(at: node.path)
                    }
                }
        }
    }

    private func rowBackground(for path: String) -> Color {
        selectedPath == path ? Color.accentColor.opacity(0.15) : Color.clear
    }
}
