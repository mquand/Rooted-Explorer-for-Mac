import Foundation
import SwiftUI
import AppKit

/// ViewModel quản lý các mục ổ đĩa / thiết bị (Locations) cho sidebar.
@MainActor
final class SidebarViewModel: ObservableObject {
    @Published var volumes: [VolumeInfo] = []
    @Published var isLoading: Bool = false

    init() {
        loadVolumes()
    }

    func loadVolumes() {
        Task.detached(priority: .utility) {
            let loaded = DiskUsageService.shared.getAllVolumes()
            await MainActor.run {
                self.volumes = loaded
            }
        }
    }

    func refreshVolumes() {
        loadVolumes()
    }

    func ejectVolume(at path: String) {
        let url = URL(fileURLWithPath: path)
        try? NSWorkspace.shared.unmountAndEjectDevice(at: url)
        Task {
            try? await Task.sleep(nanoseconds: 600_000_000)
            self.refreshVolumes()
        }
    }
}
