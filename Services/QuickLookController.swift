import Foundation
import AppKit
import QuickLookUI

/// Quick Look (phím Space) kiểu Finder, dùng `QLPreviewPanel` của hệ thống.
///
/// Controller duy nhất của app: giữ danh sách URL đang xem, tự xử lý
/// Escape/Space để đóng panel.
final class QuickLookController: NSObject, QLPreviewPanelDataSource, QLPreviewPanelDelegate {
    static let shared = QuickLookController()

    private var items: [URL] = []

    private override init() {
        super.init()
    }

    var isVisible: Bool {
        QLPreviewPanel.sharedPreviewPanelExists() && QLPreviewPanel.shared().isVisible
    }

    /// Bật/tắt Quick Look cho danh sách URL. Nếu đang mở thì đóng lại.
    func toggle(urls: [URL]) {
        if isVisible {
            hide()
        } else {
            show(urls: urls)
        }
    }

    func show(urls: [URL]) {
        guard !urls.isEmpty else { return }

        items = urls
        let panel = QLPreviewPanel.shared()
        panel.dataSource = self
        panel.delegate = self
        panel.makeKeyAndOrderFront(nil)
    }

    func hide() {
        guard QLPreviewPanel.sharedPreviewPanelExists() else { return }
        QLPreviewPanel.shared().orderOut(nil)
    }

    // MARK: - QLPreviewPanelDataSource

    func numberOfPreviewItems(in panel: QLPreviewPanel!) -> Int {
        items.count
    }

    func previewPanel(_ panel: QLPreviewPanel!, previewItemAt index: Int) -> QLPreviewItem! {
        guard items.indices.contains(index) else { return nil }
        return items[index] as NSURL
    }

    // MARK: - QLPreviewPanelDelegate

    /// Đóng panel khi người dùng bấm Escape hoặc Space.
    func previewPanel(_ panel: QLPreviewPanel!, handleEvent event: NSEvent!) -> Bool {
        guard let event else { return false }

        if event.keyCode == 53 || event.keyCode == 49 {
            hide()
            return true
        }
        return false
    }
}
