import SwiftUI

struct FileListView: View {
    @ObservedObject var viewModel: FileListViewModel

    var body: some View {
        VStack(spacing: 0) {
            // Breadcrumb
            breadcrumbBar
            
            Divider()
            
            // Toolbar
            toolbar
            
            Divider()
            
            // File list
            if viewModel.isLoading {
                ProgressView("Loading...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let error = viewModel.errorMessage {
                VStack {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.largeTitle)
                    Text(error)
                        .foregroundColor(.secondary)
                    Button("Retry") {
                        viewModel.refresh()
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                fileList
            }
        }
    }

    private var breadcrumbBar: some View {
        HStack {
            Image(systemName: "chevron.left")
                .foregroundColor(.secondary)
                .onTapGesture {
                    viewModel.navigateToParent()
                }
            
            Text(viewModel.currentPath)
                .font(.system(.body, design: .monospaced))
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.accentColor.opacity(0.1))
                .cornerRadius(6)
            
            Spacer()
            
            if let branch = viewModel.gitBranch {
                HStack(spacing: 4) {
                    Image(systemName: "arrow.triangle.branch")
                    Text(branch)
                }
                .font(.caption)
                .foregroundColor(.secondary)
            }
        }
        .padding(8)
    }

    private var toolbar: some View {
        HStack {
            Toggle("Show Hidden", isOn: $viewModel.showHiddenFiles)
                .toggleStyle(.switch)
            
            Picker("Sort", selection: $viewModel.sortOption) {
                ForEach(FileListViewModel.SortOption.allCases, id: \.self) { option in
                    Text(option.rawValue).tag(option)
                }
            }
            .pickerStyle(.menu)
            
            Spacer()
            
            Button(action: { TerminalService.shared.openTerminal(at: viewModel.currentPath) }) {
                Label("Terminal", systemImage: "terminal")
            }
            
            Button(action: { TerminalService.shared.openIDE(at: viewModel.currentPath, ide: .vscode) }) {
                Label("VS Code", systemImage: "chevron.left.forwardslash.chevron.right")
            }
            
            Button(action: viewModel.refresh) {
                Image(systemName: "arrow.clockwise")
            }
        }
        .padding(8)
    }

    private var fileList: some View {
        Table(viewModel.files, selection: $viewModel.selectedItems) {
            TableColumn("Name") { file in
                openableCell(for: file) {
                    HStack {
                        Image(systemName: file.icon)
                            .foregroundColor(file.iconColor)
                        Text(file.name)
                            .foregroundColor(file.isHidden ? .secondary : .primary)

                        if file.gitStatus != .none {
                            Text(file.gitStatus.rawValue)
                                .font(.caption)
                                .padding(.horizontal, 4)
                                .padding(.vertical, 2)
                                .background(gitStatusColor(file.gitStatus))
                                .cornerRadius(4)
                        }
                    }
                }
            }
            .width(min: 200, max: 400)

            TableColumn("Size") { file in
                openableCell(for: file) {
                    Text(file.formattedSize)
                }
            }
            .width(min: 80, max: 120)

            TableColumn("Modified") { file in
                openableCell(for: file) {
                    Text(file.formattedDate)
                }
            }
            .width(min: 120, max: 150)
        }
        .tableStyle(.inset(alternatesRowBackgrounds: true))
        .tableColumnHeaders(.hidden)
    }

    /// Cho phép double-click vào bất kỳ ô nào để mở file/thư mục.
    private func openableCell<Content: View>(
        for file: FileItem,
        @ViewBuilder content: () -> Content
    ) -> some View {
        content()
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
            .onDoubleClick {
                viewModel.openItem(file)
            }
    }
    
    private func gitStatusColor(_ status: GitStatus) -> Color {
        switch status {
        case .modified: return .orange
        case .untracked: return .green
        case .staged: return .blue
        case .conflict: return .red
        case .none: return .clear
        }
    }
}
