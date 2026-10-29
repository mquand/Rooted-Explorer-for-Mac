import SwiftUI

@main
struct RootedApp: App {
    @StateObject private var settings = AppSettings.shared
    @StateObject private var updates = UpdateService.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(settings)
                .environmentObject(updates)
        }
        .windowStyle(.hiddenTitleBar)
        .windowToolbarStyle(.unified)
        .commands {
            AppCommands()
        }

        Settings {
            SettingsView()
                .environmentObject(settings)
                .environmentObject(updates)
        }
    }
}

struct AppCommands: Commands {
    @FocusedValue(\.fileListViewModel) private var viewModel

    var body: some Commands {
        CommandGroup(replacing: .pasteboard) {
            Button("Cut") {
                viewModel?.copySelectedItems(cut: true)
            }
            .keyboardShortcut("x")
            .disabled(!hasSelection)

            Button("Copy") {
                viewModel?.copySelectedItems()
            }
            .keyboardShortcut("c")
            .disabled(!hasSelection)

            Button("Paste") {
                viewModel?.paste()
            }
            .keyboardShortcut("v")
            .disabled(!FilePasteboard.hasFiles)

            Divider()

            Button("Select All") {
                viewModel?.selectAll()
            }
            .keyboardShortcut("a")
            .disabled(viewModel == nil)

            Button("Move to Trash") {
                viewModel?.trashSelectedItems()
            }
            .keyboardShortcut(.delete, modifiers: [.command])
            .disabled(!hasSelection)
        }

        CommandGroup(after: .newItem) {
            Button("New Folder") {
                viewModel?.createNewFolder()
            }
            .keyboardShortcut("n", modifiers: [.command, .shift])
            .disabled(viewModel == nil)
        }

        CommandMenu("Go") {
            Button("Back") {
                viewModel?.goBack()
            }
            .keyboardShortcut("[")
            .disabled(!(viewModel?.canGoBack ?? false))

            Button("Forward") {
                viewModel?.goForward()
            }
            .keyboardShortcut("]")
            .disabled(!(viewModel?.canGoForward ?? false))

            Button("Enclosing Folder") {
                viewModel?.navigateToParent()
            }
            .keyboardShortcut(.upArrow, modifiers: [.command])
            .disabled(viewModel == nil)

            Divider()

            Button("Home") {
                viewModel?.navigateToHome()
            }
            .keyboardShortcut("h", modifiers: [.command, .shift])
            .disabled(viewModel == nil)

            Button("Refresh") {
                viewModel?.refresh()
            }
            .keyboardShortcut("r")
            .disabled(viewModel == nil)
        }

        CommandGroup(after: .appInfo) {
            Button("Check for Updates…") {
                Task { await UpdateService.shared.checkForUpdates(userInitiated: true) }
            }
        }
    }

    private var hasSelection: Bool {
        guard let viewModel else { return false }
        return !viewModel.selectedItems.isEmpty
    }
}
