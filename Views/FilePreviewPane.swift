import SwiftUI
import AppKit

/// Khung xem trước file bên phải cửa sổ (Preview Pane - Alt+P kiểu Windows Explorer)
struct FilePreviewPane: View {
    @ObservedObject var viewModel: FileListViewModel
    @ObservedObject var settings: AppSettings

    @State private var textPreview: String?
    @State private var imagePreview: NSImage?
    @State private var imageDimensions: String?
    @State private var isLoadingContent = false

    private var targetFile: FileItem? {
        viewModel.selectedFileItems.first ?? viewModel.focusedFile
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()

            ScrollView {
                VStack(spacing: 16) {
                    if let file = targetFile {
                        previewSection(for: file)
                        Divider()
                        quickActions(for: file)
                        Divider()
                        metadataSection(for: file)
                    } else {
                        emptyFolderSummary
                    }
                }
                .padding(14)
            }
        }
        .frame(width: 290)
        .background(Color(nsColor: .windowBackgroundColor))
        .task(id: targetFile?.path) {
            await loadPreviewContent()
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            Label("Preview", systemImage: "eye")
                .font(.headline)
                .foregroundColor(.primary)

            Spacer()

            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    viewModel.showPreviewPane = false
                }
            } label: {
                Image(systemName: "xmark")
                    .font(.caption.weight(.semibold))
                    .foregroundColor(.secondary)
                    .padding(4)
            }
            .buttonStyle(.plain)
            .help("Close Preview Pane (⌥P)")
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }

    // MARK: - Preview Section

    @ViewBuilder
    private func previewSection(for file: FileItem) -> some View {
        VStack(spacing: 10) {
            if let image = imagePreview {
                Image(nsImage: image)
                    .resizable()
                    .interpolation(.high)
                    .aspectRatio(contentMode: .fit)
                    .frame(maxHeight: 200)
                    .cornerRadius(6)
                    .shadow(radius: 2)

                if let dims = imageDimensions {
                    Text(dims)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            } else if let text = textPreview {
                VStack(alignment: .leading, spacing: 4) {
                    ScrollView(.horizontal, showsIndicators: false) {
                        Text(text)
                            .font(.system(size: 11, design: .monospaced))
                            .lineSpacing(2)
                            .foregroundColor(.primary)
                            .padding(8)
                    }
                    .frame(maxHeight: 220)
                    .background(Color(nsColor: .controlBackgroundColor))
                    .cornerRadius(6)
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
                    )
                }
            } else if isLoadingContent {
                ProgressView()
                    .controlSize(.small)
                    .frame(height: 100)
            } else {
                Image(systemName: file.icon)
                    .font(.system(size: 64))
                    .foregroundColor(file.iconColor)
                    .frame(height: 100)
            }

            VStack(spacing: 3) {
                Text(file.name)
                    .font(.system(.body, weight: .semibold))
                    .multilineTextAlignment(.center)
                    .lineLimit(2)

                Text(file.kind)
                    .font(.caption)
                    .foregroundColor(.secondary)

                TagDots(tags: file.tags)
            }
        }
    }

    // MARK: - Quick Actions

    private func quickActions(for file: FileItem) -> some View {
        HStack(spacing: 8) {
            Button {
                viewModel.openItem(file)
            } label: {
                Label("Open", systemImage: "arrow.up.forward.app")
                    .font(.caption)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)

            Button {
                let path = file.isDirectory ? file.path : (file.path as NSString).deletingLastPathComponent
                TerminalService.shared.openIDE(at: path, ide: .vscode)
            } label: {
                Label("Code", systemImage: "chevron.left.forwardslash.chevron.right")
                    .font(.caption)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)

            Button {
                QuickLookController.shared.toggle(urls: [URL(fileURLWithPath: file.path)])
            } label: {
                Image(systemName: "space")
                    .font(.caption)
            }
            .buttonStyle(.bordered)
            .help("Quick Look (Space)")
        }
    }

    // MARK: - Metadata Section

    private func metadataSection(for file: FileItem) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Information")
                .font(.caption.weight(.bold))
                .foregroundColor(.secondary)

            metaRow(title: "Size", value: viewModel.sizeText(for: file))
            metaRow(title: "Modified", value: file.formattedDate)
            metaRow(title: "Full Path", value: file.path, copyable: true)

            if let permissions = getPermissions(for: file.path) {
                metaRow(title: "Permissions", value: permissions)
            }

            if file.gitStatus != .none {
                metaRow(title: "Git Status", value: file.gitStatus.rawValue)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func metaRow(title: String, value: String, copyable: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.caption2)
                .foregroundColor(.secondary)

            HStack {
                Text(value)
                    .font(.caption)
                    .foregroundColor(.primary)
                    .lineLimit(copyable ? 2 : 1)
                    .truncationMode(.middle)

                if copyable {
                    Spacer()
                    Button {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(value, forType: .string)
                    } label: {
                        Image(systemName: "doc.on.doc")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                    .help("Copy")
                }
            }
        }
    }

    // MARK: - Empty State (Folder info)

    private var emptyFolderSummary: some View {
        VStack(spacing: 12) {
            Image(systemName: "folder")
                .font(.system(size: 48))
                .foregroundColor(.accentColor)

            Text(FileManager.default.displayName(atPath: viewModel.currentPath))
                .font(.headline)
                .multilineTextAlignment(.center)

            Text("\(viewModel.files.count) items in this folder")
                .font(.caption)
                .foregroundColor(.secondary)

            if let free = viewModel.volumeFreeSpace {
                Text("Free space: \(FileListView.sizeFormatter.string(fromByteCount: Int64(free)))")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 30)
    }

    // MARK: - Loader

    private func loadPreviewContent() async {
        textPreview = nil
        imagePreview = nil
        imageDimensions = nil

        guard let file = targetFile, !file.isDirectory else { return }

        let ext = (file.name as NSString).pathExtension.lowercased()
        let imageExts = ["png", "jpg", "jpeg", "gif", "webp", "svg", "bmp", "ico", "heic", "tiff"]
        let textExts = [
            "txt", "swift", "js", "ts", "jsx", "tsx", "json", "py", "ex", "exs",
            "html", "css", "md", "markdown", "yml", "yaml", "xml", "sh", "zsh",
            "env", "rs", "go", "c", "cpp", "h", "rb", "php", "sql", "toml", "ini"
        ]

        if imageExts.contains(ext) {
            isLoadingContent = true
            let img = await ThumbnailService.shared.thumbnail(for: file.path, size: 600)
            isLoadingContent = false
            imagePreview = img
            if let img {
                imageDimensions = "\(Int(img.size.width)) × \(Int(img.size.height)) px"
            }
        } else if textExts.contains(ext) || file.size < 500_000 {
            isLoadingContent = true
            let url = URL(fileURLWithPath: file.path)
            if let content = try? String(contentsOf: url, encoding: .utf8) {
                let lines = content.components(separatedBy: .newlines)
                let previewLines = lines.prefix(120).joined(separator: "\n")
                textPreview = previewLines + (lines.count > 120 ? "\n\n... (\(lines.count) dòng)" : "")
            }
            isLoadingContent = false
        }
    }

    private func getPermissions(for path: String) -> String? {
        guard let attrs = try? FileManager.default.attributesOfItem(atPath: path),
              let posix = attrs[.posixPermissions] as? NSNumber else {
            return nil
        }
        return String(format: "%o", posix.intValue)
    }
}
