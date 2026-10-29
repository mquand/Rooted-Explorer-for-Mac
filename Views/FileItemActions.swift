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
}
