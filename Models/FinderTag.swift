import SwiftUI

/// Một tag Finder: tên + chỉ số màu lưu trong metadata của file.
///
/// Finder lưu `com.apple.metadata:_kMDItemUserTags` dạng mảng chuỗi
/// `"Tên\n-chỉ số màu"`. Thang màu chuẩn của macOS:
/// 0 = không màu, 1 = xám, 2 = xanh lá, 3 = tím, 4 = xanh dương, 5 = vàng,
/// 6 = đỏ, 7 = cam.
struct FinderTag: Identifiable, Hashable {
    let name: String
    let colorIndex: Int

    var id: String { name }

    var color: Color {
        switch colorIndex {
        case 1: return .gray
        case 2: return .green
        case 3: return .purple
        case 4: return .blue
        case 5: return .yellow
        case 6: return .red
        case 7: return .orange
        default: return .secondary
        }
    }

    /// 7 tag mặc định của Finder (đúng thứ tự trong menu Tags của Finder).
    static let standard: [FinderTag] = [
        FinderTag(name: "Red", colorIndex: 6),
        FinderTag(name: "Orange", colorIndex: 7),
        FinderTag(name: "Yellow", colorIndex: 5),
        FinderTag(name: "Green", colorIndex: 2),
        FinderTag(name: "Blue", colorIndex: 4),
        FinderTag(name: "Purple", colorIndex: 3),
        FinderTag(name: "Gray", colorIndex: 1)
    ]
}
