import SwiftUI
import AppKit

/// Sheet phân tích dung lượng thư mục hiện tại: tổng quan, thư mục con lớn nhất
/// và các mục rác dev (node_modules, .venv, DerivedData…).
///
/// Quét chạy nền và hủy được — đóng sheet là quét dừng thật.
struct StorageAnalysisSheet: View {
    let path: String

    @Environment(\.dismiss) private var dismiss

    @State private var usage: DirectoryUsage?
    @State private var junk: [DevJunkItem] = []
    @State private var isRunning = true
    @State private var errorMessage: String?

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            content
            Divider()
            footer
        }
        .frame(width: 580, height: 460)
        .task {
            await analyze()
        }
    }

    private var displayName: String {
        FileManager.default.displayName(atPath: path)
    }

    private var header: some View {
        HStack(spacing: 8) {
            Image(systemName: "chart.bar.doc.horizontal")
                .foregroundColor(.secondary)
            Text("Storage Analysis")
                .font(.headline)
            Text(displayName)
                .foregroundColor(.secondary)
                .lineLimit(1)
            Spacer()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }

    private var footer: some View {
        HStack {
            Text("Sizes include hidden files (.git, .venv…).")
                .font(.caption)
                .foregroundColor(.secondary)
            Spacer()
            Button("Close") {
                dismiss()
            }
            .keyboardShortcut(.defaultAction)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }

    // MARK: - Nội dung

    @ViewBuilder
    private var content: some View {
        if isRunning {
            VStack(spacing: 12) {
                ProgressView()
                Text("Scanning \(displayName)…")
                    .foregroundColor(.secondary)
                Button("Cancel Scanning") {
                    dismiss()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if let errorMessage {
            VStack(spacing: 8) {
                Image(systemName: "exclamationmark.triangle")
                    .font(.largeTitle)
                    .foregroundColor(.secondary)
                Text(errorMessage)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            List {
                if let usage {
                    Section("Total") {
                        row(label: "Size", value: usage.formattedSize)
                        row(label: "Files", value: "\(usage.fileCount)")
                        row(label: "Folders", value: "\(usage.folderCount)")
                    }

                    if !usage.subdirectories.isEmpty {
                        Section("Largest folders") {
                            ForEach(Array(usage.subdirectories.prefix(6))) { sub in
                                itemRow(
                                    name: sub.name,
                                    detail: sub.path,
                                    size: sub.formattedSize,
                                    reveal: sub.path
                                )
                            }
                        }
                    }
                }

                Section("Dev junk") {
                    if junk.isEmpty {
                        Text("No dev junk folders found here.")
                            .foregroundColor(.secondary)
                    } else {
                        ForEach(junk) { item in
                            itemRow(
                                name: item.name,
                                detail: "\(item.type.rawValue) — \(item.path)",
                                size: item.formattedSize,
                                reveal: item.path
                            )
                        }
                    }
                }
            }
            .listStyle(.inset)
        }
    }

    private func row(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .monospacedDigit()
        }
    }

    private func itemRow(name: String, detail: String, size: String, reveal: String) -> some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 1) {
                Text(name)
                    .lineLimit(1)
                Text(detail)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }

            Spacer()

            Text(size)
                .monospacedDigit()
                .foregroundColor(.secondary)

            Button("Reveal") {
                NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: reveal)])
            }
            .buttonStyle(.borderless)
            .help("Hiện trong Finder")
        }
    }

    // MARK: - Quét

    private func analyze() async {
        isRunning = true
        defer { isRunning = false }

        do {
            async let junkTask = DiskUsageService.shared.scanDevJunk(at: path)
            async let usageTask = DiskUsageService.shared.analyzeDirectory(at: path)
            junk = try await junkTask
            usage = try await usageTask
        } catch is CancellationError {
            // Người dùng đã đóng sheet — không hiển thị lỗi.
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
