import SwiftUI
import AppKit

struct SettingsView: View {
    @EnvironmentObject private var settings: AppSettings
    @EnvironmentObject private var updates: UpdateService

    var body: some View {
        TabView {
            general
                .tabItem {
                    Label("General", systemImage: "gearshape")
                }

            updateSettings
                .tabItem {
                    Label("Updates", systemImage: "arrow.triangle.2.circlepath")
                }

            about
                .tabItem {
                    Label("About", systemImage: "info.circle")
                }
        }
        .frame(width: 500, height: 340)
    }

    private var general: some View {
        Form {
            Picker("Default view", selection: $settings.viewMode) {
                ForEach(ViewMode.allCases) { mode in
                    Label(mode.title, systemImage: mode.systemImage)
                        .tag(mode)
                }
            }
            .pickerStyle(.segmented)

            HStack {
                Text("Icon size")
                Slider(value: $settings.iconSize, in: 64...160, step: 8)
                Text("\(Int(settings.iconSize))")
                    .monospacedDigit()
                    .foregroundColor(.secondary)
                    .frame(width: 32, alignment: .trailing)
            }

            Toggle("Show hidden files", isOn: $settings.showHiddenFiles)

            Toggle("Open folders with a single click", isOn: $settings.singleClickOpen)

            Text("Khi tắt, click để chọn và double-click để mở thư mục.")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(24)
    }

    private var updateSettings: some View {
        Form {
            Toggle("Automatically check for updates", isOn: $settings.automaticallyChecksForUpdates)

            HStack {
                Button("Check for Updates…") {
                    Task { await updates.checkForUpdates(userInitiated: true) }
                }
                .disabled(updates.isBusy)

                if updates.isBusy {
                    ProgressView()
                        .controlSize(.small)
                }

                Spacer()

                Text("Current: \(updates.currentVersion)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            if let release = updates.availableRelease {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Version \(release.displayVersion) is available")
                            .font(.headline)
                        Text(release.summary)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(2)
                    }
                    Spacer()
                    Button("Update Now") {
                        Task { await updates.downloadAndInstall(release) }
                    }
                    .disabled(updates.isBusy)
                }
            }

            if let message = updates.status.message {
                Text(message)
                    .font(.caption)
                    .foregroundColor(statusColor)
            }

            if let date = updates.lastChecked {
                Text("Last checked: \(date.formatted(date: .abbreviated, time: .shortened))")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Link("Open GitHub Releases", destination: URL(string: "https://github.com/mquand/Rooted-Explorer-for-Mac/releases")!)
                .font(.caption)
        }
        .padding(24)
    }

    private var about: some View {
        VStack(spacing: 10) {
            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .frame(width: 96, height: 96)

            Text("Rooted")
                .font(.title2.bold())

            Text("Version \(updates.currentVersion)")
                .foregroundColor(.secondary)

            Text("A native macOS file explorer built with SwiftUI.")
                .font(.callout)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }

    private var statusColor: Color {
        if case .failed = updates.status { return .red }
        return .secondary
    }
}
