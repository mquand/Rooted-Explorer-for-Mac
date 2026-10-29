import SwiftUI

struct ContentView: View {
    @StateObject private var fileListViewModel = FileListViewModel()

    var body: some View {
        NavigationSplitView {
            // Sidebar
            SidebarView(fileListViewModel: fileListViewModel)
                .frame(minWidth: 200, idealWidth: 250)
        } detail: {
            // Main content
            FileListView(viewModel: fileListViewModel)
        }
        .navigationTitle("Rooted")
    }
}
