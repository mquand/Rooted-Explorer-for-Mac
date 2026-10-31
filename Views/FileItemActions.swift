import SwiftUI

/// Menu chuột phải dùng chung cho table, icon grid và gallery.
struct FileItemActions: View {
    @ObservedObject var viewModel: FileListViewModel
    let file: FileItem
    var onRename: (FileItem) -> Void

    var body: some View {
        Group {
            Button("Open") {
                viewModel.openItem(file)
            }

            Button("Quick Look") {
                QuickLookController.shared.toggle(urls: [URL(fileURLWithPath: file.path)])
            }

            Divider()

            Button("Copy") {
                viewModel.ensureSelected(file.path)
                viewModel.copySelectedItems()
            }

            Button("Cut") {
                viewModel.ensureSelected(file.path)
                viewModel.copySelectedItems(cut: true)
            }

            Button("Paste") {
                viewModel.paste()
            }
            .disabled(!FilePasteboard.hasFiles)

            Button("Duplicate") {
                viewModel.ensureSelected(file.path)
                viewModel.duplicateSelectedItems()
            }

            Divider()

            Button("Rename…") {
                viewModel.ensureSelected(file.path)
                onRename(file)
            }

            Button("Move to Trash") {
                viewModel.ensureSelected(file.path)
                viewModel.trashSelectedItems()
            }

            Divider()

            tagsMenu
            ideMenu

            if file.isDirectory {
                Button(viewModel.folderSizes[file.path] == nil ? "Calculate Size" : "Size Calculated") {
                    viewModel.calculateSize(for: file)
                }
                .disabled(viewModel.folderSizes[file.path] != nil)
            }

            Button("Reveal in Finder") {
                viewModel.ensureSelected(file.path)
                viewModel.reveal([file])
            }

            Button("Open in Terminal") {
                viewModel.openTerminal(for: file)
            }
        }
    }

    // MARK: - Tags (Finder)

    private var tagsMenu: some View {
        Menu("Tags") {
            ForEach(FinderTag.standard) { tag in
                Button {
                    viewModel.ensureSelected(file.path)
                    viewModel.toggleTag(tag)
                } label: {
                    if file.tags.contains(where: { $0.name == tag.name }) {
                        Label(tag.name, systemImage: "checkmark.circle.fill")
                            .foregroundColor(tag.color)
                    } else {
                        Label(tag.name, systemImage: "circle")
                            .foregroundColor(tag.color)
                    }
                }
            }

            if !file.tags.isEmpty {
                Divider()
                Button("Remove All Tags") {
                    viewModel.ensureSelected(file.path)
                    viewModel.removeTagsFromSelection()
                }
            }
        }
    }

    // MARK: - IDE

    private var ideMenu: some View {
        let installed = TerminalService.shared.getInstalledIDEs()

        return Menu("Open in IDE") {
            if installed.isEmpty {
                Text("No supported IDE found")
            } else {
                ForEach(installed, id: \.self) { ide in
                    Button(ide.displayName) {
                        let path = file.isDirectory
                            ? file.path
                            : (file.path as NSString).deletingLastPathComponent
                        TerminalService.shared.openIDE(at: path, ide: ide)
                    }
                }
            }
        }
    }
}
