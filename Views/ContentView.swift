import SwiftUI

struct ContentView: View {
    @StateObject private var fileListViewModel = FileListViewModel()
    @State private var columnVisibility: NavigationSplitViewVisibility = .all
    @EnvironmentObject private var settings: AppSettings
    @EnvironmentObject private var updates: UpdateService

    var body: some View {
        VStack(spacing: 0) {
            if let release = updates.availableRelease {
                UpdateBanner(release: release)
            }

            NavigationSplitView(columnVisibility: $columnVisibility) {
                SidebarView(fileListViewModel: fileListViewModel)
                    .frame(minWidth: 210, idealWidth: 260)
            } detail: {
                FileListView(
                    viewModel: fileListViewModel,
                    columnVisibility: $columnVisibility
                )
            }
        }
        .navigationTitle("Rooted")
        .focusedSceneValue(\.fileListViewModel, fileListViewModel)
        .task {
            await updates.checkOnLaunch()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            Task {
                if let last = updates.lastChecked, Date().timeIntervalSince(last) < 900 {
                    return
                }
                await updates.checkForUpdates(userInitiated: false)
            }
        }
    }
}
