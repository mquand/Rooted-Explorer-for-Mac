import Foundation
import AppKit

/// Đọc/ghi file trên clipboard theo chuẩn của Finder.
enum FilePasteboard {
    static let cutType = NSPasteboard.PasteboardType("com.rooted.cut-paths")

    static func write(urls: [URL], cut: Bool) {
        guard !urls.isEmpty else { return }

        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.writeObjects(urls.map { $0 as NSURL })

        if cut {
            let paths = urls.map(\.path).joined(separator: "\n")
            pasteboard.setString(paths, forType: cutType)
        }
    }

    static func read() -> (urls: [URL], isCut: Bool) {
        let pasteboard = NSPasteboard.general
        let objects = pasteboard.readObjects(
            forClasses: [NSURL.self],
            options: [.urlReadingFileURLsOnly: true]
        ) as? [NSURL] ?? []

        let urls = objects.map { $0 as URL }
        let cutPaths = pasteboard.string(forType: cutType)?
            .components(separatedBy: "\n")
            .filter { !$0.isEmpty } ?? []

        let isCut = !cutPaths.isEmpty
            && Set(cutPaths) == Set(urls.map(\.path))

        return (urls, isCut)
    }

    static var hasFiles: Bool {
        !read().urls.isEmpty
    }

    static func clear() {
        NSPasteboard.general.clearContents()
    }
}
