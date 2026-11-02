import SwiftUI
import AppKit

/// Thanh đường dẫn dạng breadcrumb kiểu Windows Explorer & VS Code: mỗi cấp là một nút
/// bấm được, có mũi tên `>` mở danh sách thư mục con, có nút sửa để gõ đường dẫn trực tiếp (hoặc phím ⇧⌘G).
struct PathBar: View {
    @ObservedObject var viewModel: FileListViewModel

    @FocusState private var isFieldFocused: Bool
    @State private var wasFocused = false

    var body: some View {
        Group {
            if viewModel.isEditingPath {
                HStack(spacing: 4) {
                    Image(systemName: "folder")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)

                    TextField("Path", text: $viewModel.pathInput)
                        .textFieldStyle(.plain)
                        .font(.system(.body, design: .monospaced))
                        .focused($isFieldFocused)
                        .onSubmit {
                            viewModel.submitPathInput()
                            wasFocused = false
                            isFieldFocused = false
                            NSApp.keyWindow?.makeFirstResponder(nil)
                        }
                        .onExitCommand {
                            viewModel.cancelPathEditing()
                            wasFocused = false
                            isFieldFocused = false
                            NSApp.keyWindow?.makeFirstResponder(nil)
                        }

                    Button {
                        viewModel.cancelPathEditing()
                        wasFocused = false
                        isFieldFocused = false
                        NSApp.keyWindow?.makeFirstResponder(nil)
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.borderless)
                    .help("Cancel editing (Esc)")
                }
                .padding(.horizontal, 7)
                .padding(.vertical, 3)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color(nsColor: .controlBackgroundColor))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(Color.accentColor, lineWidth: 1.5)
                )
            } else {
                breadcrumbs
            }
        }
        .onChange(of: isFieldFocused) { focused in
            if focused {
                wasFocused = true
            } else if wasFocused {
                wasFocused = false
                viewModel.cancelPathEditing()
            }
        }
        .onChange(of: viewModel.isEditingPath) { editing in
            if editing {
                DispatchQueue.main.async {
                    isFieldFocused = true
                }
            } else {
                wasFocused = false
                isFieldFocused = false
            }
        }
        .onChange(of: viewModel.focusPathField) { shouldFocus in
            guard shouldFocus else { return }
            viewModel.focusPathField = false
            startEditing()
        }
    }

    private func startEditing() {
        viewModel.pathInput = viewModel.currentPath
        viewModel.isEditingPath = true
        DispatchQueue.main.async {
            isFieldFocused = true
        }
    }

    // MARK: - Breadcrumb

    private var breadcrumbs: some View {
        HStack(spacing: 2) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 1) {
                    ForEach(Array(components.enumerated()), id: \.element.path) { index, component in
                        crumbButton(for: component, isCurrent: index == components.count - 1)
                        chevronMenu(for: component)
                    }
                }
            }

            Spacer(minLength: 8)
                .contentShape(Rectangle())
                .onTapGesture {
                    startEditing()
                }

            Button {
                startEditing()
            } label: {
                Image(systemName: "pencil")
                    .font(.system(size: 11))
                    .frame(width: 18, height: 18)
            }
            .buttonStyle(.borderless)
            .help("Edit path (⇧⌘G)")
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(Color(nsColor: .controlBackgroundColor).opacity(0.4))
        )
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
        .onTapGesture(count: 2) {
            startEditing()
        }
    }

    private func crumbButton(for component: Crumb, isCurrent: Bool) -> some View {
        Button {
            if isCurrent {
                startEditing()
            } else {
                viewModel.navigateTo(path: component.path)
            }
        } label: {
            Text(component.name)
                .lineLimit(1)
                .truncationMode(.middle)
                .padding(.horizontal, 5)
                .padding(.vertical, 2)
                .background(
                    RoundedRectangle(cornerRadius: 5)
                        .fill(isCurrent ? Color.primary.opacity(0.08) : Color.clear)
                )
        }
        .buttonStyle(.borderless)
        .help(isCurrent ? "Click to edit path" : component.path)
    }

    private func chevronMenu(for component: Crumb) -> some View {
        Menu {
            let subdirs = Self.subdirectories(at: component.path)
            if subdirs.isEmpty {
                Text("Không có thư mục con")
            } else {
                ForEach(subdirs, id: \.path) { item in
                    Button {
                        viewModel.navigateTo(path: item.path)
                    } label: {
                        Label(item.name, systemImage: "folder")
                    }
                }
            }
        } label: {
            Image(systemName: "chevron.right")
                .font(.system(size: 9, weight: .semibold))
                .foregroundColor(.secondary)
                .frame(width: 14, height: 20)
                .contentShape(Rectangle())
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .fixedSize()
        .help("Thư mục con của \(component.name)")
    }

    // MARK: - Quét danh sách thư mục con

    static func subdirectories(at path: String) -> [(name: String, path: String)] {
        let url = URL(fileURLWithPath: path, isDirectory: true)
        let keys: Set<URLResourceKey> = [.isDirectoryKey, .isPackageKey]
        guard let contents = try? FileManager.default.contentsOfDirectory(
            at: url,
            includingPropertiesForKeys: Array(keys),
            options: [.skipsHiddenFiles, .skipsPackageDescendants]
        ) else {
            return []
        }

        var result: [(name: String, path: String)] = []
        for item in contents {
            guard let values = try? item.resourceValues(forKeys: keys),
                  values.isDirectory == true,
                  values.isPackage != true else {
                continue
            }
            result.append((name: item.lastPathComponent, path: item.path))
        }

        let sorted = result.sorted {
            $0.name.localizedStandardCompare($1.name) == .orderedAscending
        }

        if sorted.count > 60 {
            return Array(sorted.prefix(60))
        }
        return sorted
    }

    // MARK: - Đường dẫn -> các cấp

    private struct Crumb {
        let name: String
        let path: String
    }

    private var components: [Crumb] {
        let path = viewModel.currentPath
        var result: [Crumb] = [
            Crumb(name: FileManager.default.displayName(atPath: "/"), path: "/")
        ]

        var accumulated = ""
        for part in path.split(separator: "/") {
            accumulated += "/" + part
            result.append(Crumb(name: String(part), path: accumulated))
        }

        return result
    }
}
