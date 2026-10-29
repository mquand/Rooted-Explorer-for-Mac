import Foundation
import SwiftUI

/// Chế độ hiển thị danh sách file.
enum ViewMode: String, CaseIterable, Identifiable {
    case list
    case icons
    case gallery

    var id: String { rawValue }

    var title: String {
        switch self {
        case .list: return "List"
        case .icons: return "Icons"
        case .gallery: return "Gallery"
        }
    }

    var systemImage: String {
        switch self {
        case .list: return "list.bullet"
        case .icons: return "square.grid.2x2"
        case .gallery: return "photo.on.rectangle"
        }
    }
}

/// Cài đặt người dùng, lưu trong UserDefaults.
@MainActor
final class AppSettings: ObservableObject {
    static let shared = AppSettings()

    @Published var showHiddenFiles: Bool {
        didSet { defaults.set(showHiddenFiles, forKey: Keys.showHiddenFiles) }
    }

    @Published var viewMode: ViewMode {
        didSet { defaults.set(viewMode.rawValue, forKey: Keys.viewMode) }
    }

    @Published var iconSize: Double {
        didSet { defaults.set(iconSize, forKey: Keys.iconSize) }
    }

    /// Mở thư mục bằng một lần click (chỉ áp dụng cho chế độ Icons/Gallery).
    @Published var singleClickOpen: Bool {
        didSet { defaults.set(singleClickOpen, forKey: Keys.singleClickOpen) }
    }

    @Published var automaticallyChecksForUpdates: Bool {
        didSet { defaults.set(automaticallyChecksForUpdates, forKey: Keys.autoUpdate) }
    }

    private let defaults: UserDefaults

    private enum Keys {
        static let showHiddenFiles = "showHiddenFiles"
        static let viewMode = "viewMode"
        static let iconSize = "iconSize"
        static let singleClickOpen = "singleClickOpen"
        static let autoUpdate = "automaticallyChecksForUpdates"
        static let skippedVersion = "skippedUpdateVersion"
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        showHiddenFiles = defaults.bool(forKey: Keys.showHiddenFiles)
        viewMode = ViewMode(rawValue: defaults.string(forKey: Keys.viewMode) ?? "") ?? .list
        let storedIconSize = defaults.double(forKey: Keys.iconSize)
        iconSize = storedIconSize > 0 ? storedIconSize : 96
        singleClickOpen = defaults.bool(forKey: Keys.singleClickOpen)
        automaticallyChecksForUpdates = defaults.object(forKey: Keys.autoUpdate) as? Bool ?? true
    }

    var skippedVersion: String? {
        get { defaults.string(forKey: Keys.skippedVersion) }
        set { defaults.set(newValue, forKey: Keys.skippedVersion) }
    }

    var currentVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.0.0"
    }
}
