import Foundation
import AppKit
import QuickLookThumbnailing

/// Tạo và cache thumbnail cho file/thư mục.
final class ThumbnailService {
    static let shared = ThumbnailService()

    private let cache = NSCache<NSString, NSImage>()
    private let queue = DispatchQueue(label: "com.rooted.thumbnails", qos: .userInitiated, attributes: .concurrent)

    private init() {
        cache.countLimit = 300
        cache.totalCostLimit = 120 * 1024 * 1024
    }

    func thumbnail(for path: String, size: CGFloat) async -> NSImage? {
        let cacheKey = key(for: path, size: size)
        if let cached = cache.object(forKey: cacheKey) {
            return cached
        }

        let image: NSImage?
        if Self.supportsPreview(path) {
            image = await quickLookThumbnail(for: path, size: size)
        } else {
            // File thường: icon hệ thống — cache theo đuôi file để không
            // phải hỏi lại NSWorkspace mỗi lần cuộn qua lại.
            image = iconForFile(path)
        }

        let result = image ?? NSWorkspace.shared.icon(forFile: path)
        cache.setObject(result, forKey: cacheKey, cost: Int(size * size * 4))
        return result
    }

    private func iconForFile(_ path: String) -> NSImage {
        let attributes = try? FileManager.default.attributesOfItem(atPath: path)
        let isDirectory = (attributes?[.type] as? FileAttributeType) == .typeDirectory

        // Không cache thư mục: icon thư mục có thể được người dùng tuỳ biến riêng.
        guard !isDirectory else { return NSWorkspace.shared.icon(forFile: path) }

        let ext = (path as NSString).pathExtension.lowercased()
        let key = "icon|\(ext)" as NSString

        if let cached = cache.object(forKey: key) {
            return cached
        }

        let icon = NSWorkspace.shared.icon(forFile: path)
        cache.setObject(icon, forKey: key, cost: 64 * 64 * 4)
        return icon
    }

    private func quickLookThumbnail(for path: String, size: CGFloat) async -> NSImage? {
        await withCheckedContinuation { continuation in
            let request = QLThumbnailGenerator.Request(
                fileAt: URL(fileURLWithPath: path),
                size: CGSize(width: size, height: size),
                scale: NSScreen.main?.backingScaleFactor ?? 2,
                representationTypes: .thumbnail
            )

            QLThumbnailGenerator.shared.generateBestRepresentation(for: request) { representation, _ in
                continuation.resume(returning: representation?.nsImage)
            }
        }
    }

    private func key(for path: String, size: CGFloat) -> NSString {
        "\(path)|\(Int(size))" as NSString
    }

    static func supportsPreview(_ path: String) -> Bool {
        let ext = (path as NSString).pathExtension.lowercased()
        let previewable: Set<String> = [
            "png", "jpg", "jpeg", "gif", "heic", "heif", "webp", "tiff", "bmp", "svg",
            "pdf", "mp4", "mov", "m4v", "avi", "mkv", "mp3", "wav", "m4a", "aiff"
        ]
        return previewable.contains(ext)
    }
}
