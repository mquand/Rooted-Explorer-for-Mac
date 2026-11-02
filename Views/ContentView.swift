import SwiftUI

struct ContentView: View {
    @StateObject private var tabManager = TabManager()
    @State private var columnVisibility: NavigationSplitViewVisibility = .all
    @EnvironmentObject private var settings: AppSettings
    @EnvironmentObject private var updates: UpdateService

    var body: some View {
        VStack(spacing: 0) {
            if let release = updates.availableRelease {
                UpdateBanner(release: release)
            }

            TabBarView(tabManager: tabManager)
            Divider()

            NavigationSplitView(columnVisibility: $columnVisibility) {
                SidebarView(fileListViewModel: tabManager.activeTab.activeViewModel)
                    .frame(minWidth: 210, idealWidth: 260)
            } detail: {
                tabDetailView
            }
        }
        .navigationTitle("Rooted")
        .focusedSceneValue(\.fileListViewModel, tabManager.activeTab.activeViewModel)
        .background(
            Group {
                Button("") { tabManager.newTab() }
                    .keyboardShortcut("t", modifiers: .command)
                Button("") { tabManager.closeActiveTab() }
                    .keyboardShortcut("w", modifiers: .command)
                Button("") { tabManager.activeTab.toggleDualPane() }
                    .keyboardShortcut("d", modifiers: [.command, .option])
                Button("") { tabManager.selectNextTab() }
                    .keyboardShortcut("}", modifiers: .command)
                Button("") { tabManager.selectPreviousTab() }
                    .keyboardShortcut("{", modifiers: .command)
            }
            .opacity(0)
            .allowsHitTesting(false)
        )
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

    @ViewBuilder
    private var tabDetailView: some View {
        let tab = tabManager.activeTab
        if tab.isDualPane, let rightVM = tab.rightViewModel {
            HStack(spacing: 0) {
                FileListView(
                    viewModel: tab.leftViewModel,
                    columnVisibility: $columnVisibility
                )
                .overlay(alignment: .top) {
                    if tab.activePane == .left {
                        Rectangle()
                            .fill(Color.accentColor)
                            .frame(height: 2)
                    }
                }

                Divider()

                FileListView(
                    viewModel: rightVM,
                    columnVisibility: .constant(.detailOnly)
                )
                .overlay(alignment: .top) {
                    if tab.activePane == .right {
                        Rectangle()
                            .fill(Color.accentColor)
                            .frame(height: 2)
                    }
                }
            }
        } else {
            FileListView(
                viewModel: tab.leftViewModel,
                columnVisibility: $columnVisibility
            )
        }
    }
}
