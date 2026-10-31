import Foundation
import AppKit
import QuickLookUI

/// Quick Look (phím Space) kiểu Finder, dùng `QLPreviewPanel` của hệ thống.
///
/// Controller duy nhất của app: giữ danh sách URL đang xem, tự xử lý
/// Escape/Space để đóng panel.
final class QuickLookController: NSObject, @preconcurrency QLPreviewPanelDataSource, @preconcurrency QLPreviewPanelDelegate {
    static let shared = QuickLookController()

    private var items: [URL] = []

    private override init() {
        super.init()
    }

    nonisolated var isVisible: Bool {
        QLPreviewPanel.sharedPreviewPanelExists() && QLPreviewPanel.shared()?.isVisible ?? false
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
        panel?.dataSource = self
        panel?.delegate = self
        panel?.makeKeyAndOrderFront(nil)
    }

    func hide() {
        guard QLPreviewPanel.sharedPreviewPanelExists() else { return }
        QLPreviewPanel.shared()?.orderOut(nil)
    }

    // MARK: - QLPreviewPanelDataSource

    nonisolated func numberOfPreviewItems(in panel: QLPreviewPanel!) -> Int {
        // Access items via self (captured in closure, safe within sync context)
        return (self as? QuickLookController)?.items.count ?? 0
    }

    nonisolated func previewPanel(_ panel: QLPreviewPanel!, previewItemAt index: Int) -> QLPreviewItem! {
        guard let self = self as? QuickLookController else { return nil }
        guard self.items.indices.contains(index) else { return nil }
        return self.items[index] as NSURL
    }

    // MARK: - QLPreviewPanelDelegate

    /// Đóng panel khi người dùng bấm Escape hoặc Space.
    nonisolated func previewPanel(_ panel: QLPreviewPanel!, handle event: NSEvent!) -> Bool {
        guard let event else { return false }

        if event.keyCode == 53 || event.keyCode == 49 {
            (self as? QuickLookController)?.hide()
            return true
        }
        return false
    }
}
