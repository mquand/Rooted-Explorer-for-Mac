import SwiftUI

/// Hộp thoại Đổi tên hàng loạt (Batch Rename)
struct BatchRenameSheet: View {
    @ObservedObject var viewModel: FileListViewModel
    let files: [FileItem]
    @Environment(\.dismiss) private var dismiss

    enum RenameMode: String, CaseIterable, Identifiable {
        case replace = "Thay thế từ"
        case addText = "Thêm tiền tố / hậu tố"
        case format = "Đánh số thứ tự"

        var id: String { rawValue }
    }

    @State private var mode: RenameMode = .replace

    // Replace mode
    @State private var findText = ""
    @State private var replaceText = ""
    @State private var matchCase = false

    // Add text mode
    @State private var prefix = ""
    @State private var suffix = ""

    // Format mode
    @State private var customName = ""
    @State private var startNumber = 1
    @State private var digitsCount = 3 // e.g. 001

    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Đổi tên hàng loạt (\(files.count) mục)")
                    .font(.headline)
                Spacer()
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }

            Picker("Chế độ", selection: $mode) {
                ForEach(RenameMode.allCases) { m in
                    Text(m.rawValue).tag(m)
                }
            }
            .pickerStyle(.segmented)

            // Configuration Form
            Group {
                switch mode {
                case .replace:
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Tìm:")
                                .frame(width: 80, alignment: .trailing)
                            TextField("Từ cần tìm", text: $findText)
                                .textFieldStyle(.roundedBorder)
                        }
                        HStack {
                            Text("Thay bằng:")
                                .frame(width: 80, alignment: .trailing)
                            TextField("Từ thay thế", text: $replaceText)
                                .textFieldStyle(.roundedBorder)
                        }
                        Toggle("Phân biệt chữ hoa / thường", isOn: $matchCase)
                            .padding(.leading, 88)
                    }

                case .addText:
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Tiền tố:")
                                .frame(width: 80, alignment: .trailing)
                            TextField("Thêm vào đầu tên", text: $prefix)
                                .textFieldStyle(.roundedBorder)
                        }
                        HStack {
                            Text("Hậu tố:")
                                .frame(width: 80, alignment: .trailing)
                            TextField("Thêm vào cuối tên (trước đuôi file)", text: $suffix)
                                .textFieldStyle(.roundedBorder)
                        }
                    }

                case .format:
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Tên gốc:")
                                .frame(width: 80, alignment: .trailing)
                            TextField("Tên chung", text: $customName)
                                .textFieldStyle(.roundedBorder)
                        }
                        HStack {
                            Text("Bắt đầu từ:")
                                .frame(width: 80, alignment: .trailing)
                            Stepper("\(startNumber)", value: $startNumber, in: 0...9999)
                            Spacer()
                            Text("Số chữ số:")
                            Picker("", selection: $digitsCount) {
                                Text("1, 2, 3").tag(1)
                                Text("01, 02").tag(2)
                                Text("001, 002").tag(3)
                            }
                            .frame(width: 100)
                        }
                    }
                }
            }
            .padding(12)
            .background(Color(nsColor: .controlBackgroundColor))
            .cornerRadius(8)

            // Live Preview Table
            VStack(alignment: .leading, spacing: 4) {
                Text("Xem trước kết quả:")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Table(previewItems) {
                    TableColumn("Tên hiện tại", value: \.oldName)
                    TableColumn("Tên mới", value: \.newName)
                }
                .frame(height: 180)
                .cornerRadius(6)
            }

            HStack {
                Spacer()
                Button("Hủy", role: .cancel) {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)

                Button("Đổi tên \(files.count) mục") {
                    applyRename()
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(20)
        .frame(width: 520, height: 480)
    }

    private struct PreviewItem: Identifiable {
        let id: String
        let oldName: String
        let newName: String
        let oldPath: String
    }

    private var previewItems: [PreviewItem] {
        files.enumerated().map { index, file in
            let ext = (file.name as NSString).pathExtension
            let nameWithoutExt = (file.name as NSString).deletingPathExtension

            var newBase = nameWithoutExt

            switch mode {
            case .replace:
                if !findText.isEmpty {
                    let options: NSString.CompareOptions = matchCase ? [] : [.caseInsensitive]
                    newBase = nameWithoutExt.replacingOccurrences(of: findText, with: replaceText, options: options)
                }

            case .addText:
                newBase = prefix + nameWithoutExt + suffix

            case .format:
                let num = startNumber + index
                let formatStr = "%0\(digitsCount)d"
                let numStr = String(format: formatStr, num)
                newBase = customName.isEmpty ? numStr : "\(customName)_\(numStr)"
            }

            let newFullName = ext.isEmpty ? newBase : "\(newBase).\(ext)"
            return PreviewItem(id: file.path, oldName: file.name, newName: newFullName, oldPath: file.path)
        }
    }

    private func applyRename() {
        for item in previewItems {
            if item.oldName != item.newName {
                viewModel.renameItem(at: item.oldPath, to: item.newName)
            }
        }
        viewModel.refresh()
    }
}
