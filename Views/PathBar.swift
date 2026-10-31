import SwiftUI

/// Thanh đường dẫn dạng breadcrumb kiểu Windows Explorer: mỗi cấp là một nút
/// bấm được, có nút sửa để gõ đường dẫn trực tiếp (hoặc phím ⇧⌘G).
struct PathBar: View {
    @ObservedObject var viewModel: FileListViewModel

    @State private var isEditing = false
    @FocusState private var isFieldFocused: Bool

    var body: some View {
        Group {
            if isEditing {
                TextField("Path", text: $viewModel.pathInput)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(.body, design: .monospaced))
                    .focused($isFieldFocused)
                    .onSubmit {
                        viewModel.submitPathInput()
                        isEditing = false
                    }
                    .onExitCommand {
                        viewModel.pathInput = viewModel.currentPath
                        isEditing = false
                    }
            } else {
                breadcrumbs
            }
        }
        .onChange(of: isEditing) { editing in
            if editing {
                isFieldFocused = true
            }
        }
        .onChange(of: viewModel.focusPathField) { shouldFocus in
            guard shouldFocus else { return }
            viewModel.focusPathField = false
            isEditing = true
        }
    }

    // MARK: - Breadcrumb

    private var breadcrumbs: some View {
        HStack(spacing: 2) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 2) {
                    ForEach(Array(components.enumerated()), id: \.element.path) { index, component in
                        if index > 0 {
                            Image(systemName: "chevron.right")
                                .font(.system(size: 9))
                                .foregroundColor(.secondary)
                        }

                        crumbButton(for: component, isCurrent: index == components.count - 1)
                    }
                }
            }

            Button {
                isEditing = true
            } label: {
                Image(systemName: "pencil")
                    .font(.system(size: 11))
                    .frame(width: 18, height: 18)
            }
            .buttonStyle(.borderless)
            .help("Edit path (⇧⌘G)")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func crumbButton(for component: Crumb, isCurrent: Bool) -> some View {
        Button {
            viewModel.navigateTo(path: component.path)
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
        .disabled(isCurrent)
        .help(component.path)
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
