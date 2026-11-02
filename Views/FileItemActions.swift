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

            if file.isDirectory {
                Button("Open in New Tab") {
                    viewModel.onOpenNewTab?(file.path)
                }
            }

            Button("Open in VS Code") {
                let path = file.isDirectory ? file.path : (file.path as NSString).deletingLastPathComponent
                TerminalService.shared.openIDE(at: path, ide: .vscode)
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

            Menu("Copy Special") {
                Button("Copy Full Path") {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(file.path, forType: .string)
                }
                Button("Copy Relative Path") {
                    viewModel.copyRelativePath(for: file)
                }
                if !file.isDirectory {
                    Button("Copy File Content") {
                        viewModel.copyFileContent(for: file)
                    }
                }
            }

            Divider()

            Button("Rename…") {
                viewModel.ensureSelected(file.path)
                onRename(file)
            }

            if viewModel.selectedItems.count > 1 {
                Button("Batch Rename (\(viewModel.selectedItems.count) items)…") {
                    viewModel.showBatchRename = true
                }
            }

            Button("Compress to ZIP") {
                viewModel.ensureSelected(file.path)
                viewModel.compressSelection()
            }

            if file.name.lowercased().hasSuffix(".zip") {
                Button("Extract Archive") {
                    viewModel.extractArchive(at: file.path)
                }
            }

            if !file.isDirectory {
                Button("Calculate Checksum (MD5 / SHA-256)…") {
                    viewModel.calculateChecksum(for: file)
                }
            }

            Button("Move to Trash") {
                viewModel.ensureSelected(file.path)
                viewModel.trashSelectedItems()
            }

            Button("Delete Immediately…") {
                viewModel.ensureSelected(file.path)
                viewModel.requestDeleteImmediately()
            }

            Divider()

            tagsMenu
            ideMenu

            if file.isDirectory {
                Button(viewModel.isFavorite(path: file.path) ? "Unpin from Favorites" : "Pin to Favorites") {
                    viewModel.toggleFavorite(path: file.path)
                }

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
