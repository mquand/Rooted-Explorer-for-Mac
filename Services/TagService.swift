import Foundation

/// Đọc/ghi tag Finder (thẻ màu) của file.
///
/// Nguồn sự thật là xattr `com.apple.metadata:_kMDItemUserTags`, dạng binary
/// plist của mảng chuỗi `"Tên\n-chỉ số màu"`. API `NSURLTagNamesKey` của
/// Foundation chỉ đọc được tên (mất màu) nên ta đọc/ghi xattr trực tiếp —
/// đúng định dạng mà chính Foundation ghi ra.
enum TagService {
    static let xattrName = "com.apple.metadata:_kMDItemUserTags"

    /// Đọc tag của một file. Trả về mảng rỗng nếu file không có tag.
    static func tags(for path: String) -> [FinderTag] {
        let size = getxattr(path, xattrName, nil, 0, 0, 0)
        guard size > 0 else { return [] }

        var data = Data(count: size)
        let read = data.withUnsafeMutableBytes { buffer -> Int in
            getxattr(path, xattrName, buffer.baseAddress, size, 0, 0)
        }
        guard read == size else { return [] }

        guard let list = try? PropertyListSerialization.propertyList(from: data, options: [], format: nil)
                as? [String] else {
            return []
        }

        return list.compactMap { entry in
            let parts = entry.components(separatedBy: "\n")
            let name = parts[0]
            guard !name.isEmpty else { return nil }

            let colorIndex = parts.count > 1 ? (Int(parts[1]) ?? 0) : 0
            return FinderTag(name: name, colorIndex: colorIndex)
        }
    }

    /// Ghi đè danh sách tag của file. Danh sách rỗng = gỡ toàn bộ tag.
    static func setTags(_ tags: [FinderTag], for path: String) {
        guard !tags.isEmpty else {
            _ = removexattr(path, xattrName, 0)
            return
        }

        let entries = tags.map { "\($0.name)\n\($0.colorIndex)" }
        guard let data = try? PropertyListSerialization.data(
            fromPropertyList: entries,
            format: .binary,
            options: 0
        ) else { return }

        _ = data.withUnsafeBytes { buffer in
            setxattr(path, xattrName, buffer.baseAddress, data.count, 0, 0)
        }
    }

    static func removeTags(for path: String) {
        _ = removexattr(path, xattrName, 0)
    }
}
