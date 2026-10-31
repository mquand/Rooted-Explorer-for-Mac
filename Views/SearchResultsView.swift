import SwiftUI
import AppKit

/// Danh sách kết quả tìm kiếm, thay thế bảng file trong lúc đang tìm.
struct SearchResultsView: View {
    @ObservedObject var viewModel: FileListViewModel

    @State private var selection: Set<String> = []

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()

            if viewModel.searchHits.isEmpty {
                if viewModel.isSearching {
                    ProgressView("Searching…")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    emptyState
                }
            } else {
                table
            }
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.secondary)

            Text(title)
                .lineLimit(1)
                .truncationMode(.middle)

            Text("\(viewModel.searchHits.count) results")
                .foregroundColor(.secondary)

            if viewModel.isSearching {
                ProgressView()
                    .controlSize(.small)
            }

            Spacer()

            Button("Done") {
                viewModel.leaveSearch()
            }
        }
        .font(.callout)
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
    }

    private var title: String {
        if let searchTitle = viewModel.searchTitle {
            return searchTitle
        }

        let folder = FileManager.default.displayName(atPath: viewModel.currentPath)
        let scope = viewModel.searchScope == .content ? "contents" : "name"
        return "\"\(viewModel.searchQuery)\" in \(scope) — \(folder)"
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.largeTitle)
                .foregroundColor(.secondary)
            Text("No results")
                .font(.headline)
            Text(hint)
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var hint: String {
        if viewModel.searchTitle != nil {
            return "No files with this tag (Spotlight indexes your home folder)."
        }
        if viewModel.searchScope == .content {
            return "Content search uses ripgrep if installed, otherwise grep."
        }
        return "Try a shorter query, or switch the scope menu next to the search field."
    }

    // MARK: - Bảng kết quả

    private var table: some View {
        Table(viewModel.searchHits, selection: $selection) {
            TableColumn("Name") { hit in
                HStack(spacing: 6) {
                    Image(systemName: hit.file.icon)
                        .foregroundColor(hit.file.iconColor)
                        .frame(width: 16)

                    VStack(alignment: .leading, spacing: 1) {
                        Text(hit.file.name)
                            .lineLimit(1)
                        if let text = hit.text {
                            Text(text)
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                                .truncationMode(.middle)
                                .monospaced()
                        }
                    }

                    TagDots(tags: hit.file.tags)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
                .onDoubleClick { viewModel.openItem(hit.file) }
                .contextMenu { menu(for: hit) }
            }
            .width(min: 240, max: 620)

            TableColumn("Folder") { hit in
                Text((hit.file.path as NSString).deletingLastPathComponent)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            .width(min: 160, max: 380)
        }
        .tableStyle(.inset(alternatesRowBackgrounds: true))
    }

    private func menu(for hit: SearchHit) -> some View {
        Group {
            Button("Open") {
                viewModel.openItem(hit.file)
            }

            Button("Quick Look") {
                QuickLookController.shared.toggle(urls: [URL(fileURLWithPath: hit.file.path)])
            }

            Divider()

            Button("Reveal in Finder") {
                NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: hit.file.path)])
            }

            Button("Copy Path") {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(hit.file.path, forType: .string)
            }

            Button("Open in Terminal") {
                viewModel.openTerminal(for: hit.file)
            }
        }
    }
}
