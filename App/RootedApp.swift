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
            AppCommands(settings: settings)
        }

        Settings {
            SettingsView()
                .environmentObject(settings)
                .environmentObject(updates)
        }
    }
}

struct AppCommands: Commands {
    @ObservedObject var settings: AppSettings
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

            Button("Deselect All") {
                viewModel?.deselectAll()
            }
            .keyboardShortcut("d")
            .disabled(!hasSelection)

            Button("Select All Folders") {
                viewModel?.selectAllFolders()
            }
            .disabled(viewModel == nil)

            Button("Select All Files") {
                viewModel?.selectAllFiles()
            }
            .disabled(viewModel == nil)

            Button("Move to Trash") {
                viewModel?.trashSelectedItems()
            }
            .keyboardShortcut(.delete, modifiers: [.command])
            .disabled(!hasSelection)

            Button("Delete Immediately…") {
                viewModel?.requestDeleteImmediately()
            }
            .keyboardShortcut(.delete, modifiers: [.command, .option])
            .disabled(!hasSelection)
        }

        CommandGroup(after: .pasteboard) {
            Button("Find…") {
                viewModel?.focusSearchField = true
            }
            .keyboardShortcut("f")
            .disabled(viewModel == nil)
        }

        CommandGroup(after: .newItem) {
            Button("New Folder") {
                viewModel?.createNewFolder()
            }
            .keyboardShortcut("n", modifiers: [.command, .shift])
            .disabled(viewModel == nil)
        }

        CommandGroup(after: .sidebar) {
            Divider()

            Button {
                settings.viewMode = .list
            } label: {
                if settings.viewMode == .list {
                    Label("List", systemImage: "checkmark")
                } else {
                    Text("List")
                }
            }
            .keyboardShortcut("1", modifiers: .command)

            Button {
                settings.viewMode = .icons
            } label: {
                if settings.viewMode == .icons {
                    Label("Icons", systemImage: "checkmark")
                } else {
                    Text("Icons")
                }
            }
            .keyboardShortcut("2", modifiers: .command)

            Button {
                settings.viewMode = .gallery
            } label: {
                if settings.viewMode == .gallery {
                    Label("Gallery", systemImage: "checkmark")
                } else {
                    Text("Gallery")
                }
            }
            .keyboardShortcut("3", modifiers: .command)
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

            Button("Go to Folder…") {
                viewModel?.focusPathField = true
            }
            .keyboardShortcut("g", modifiers: [.command, .shift])
            .disabled(viewModel == nil)

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
