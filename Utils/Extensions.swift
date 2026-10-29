import Foundation
import SwiftUI
import AppKit

// MARK: - String Extensions

extension String {
    /// Lấy file extension
    var fileExtension: String {
        (self as NSString).pathExtension
    }
    
    /// Lấy filename (không có path)
    var fileName: String {
        (self as NSString).lastPathComponent
    }
    
    /// Lấy parent directory
    var parentDirectory: String {
        (self as NSString).deletingLastPathComponent
    }
    
    /// Append path component
    func appendingPathComponent(_ component: String) -> String {
        (self as NSString).appendingPathComponent(component)
    }
    
    /// Kiểm tra có phải hidden file không
    var isHidden: Bool {
        self.hasPrefix(".")
    }
    
    /// Kiểm tra có phải thư mục không
    var isDirectory: Bool {
        var isDir: ObjCBool = false
        FileManager.default.fileExists(atPath: self, isDirectory: &isDir)
        return isDir.boolValue
    }
    
    /// Kiểm tra có phải symlink không
    var isSymlink: Bool {
        let attributes = try? FileManager.default.attributesOfItem(atPath: self)
        return (attributes?[.type] as? FileAttributeType) == .typeSymbolicLink
    }
    
    /// Normalize path (để lại trên macOS có NFC/NFD)
    var normalizedPath: String {
        self.precomposedStringWithCanonicalMapping
    }
    
    /// Get file size
    var fileSize: UInt64? {
        let attributes = try? FileManager.default.attributesOfItem(atPath: self)
        return attributes?[.size] as? UInt64
    }
    
    /// Get modification date
    var modificationDate: Date? {
        let attributes = try? FileManager.default.attributesOfItem(atPath: self)
        return attributes?[.modificationDate] as? Date
    }
    
    /// Format file size
    var formattedFileSize: String {
        guard let size = fileSize else { return "--" }
        return ByteCountFormatter.string(fromByteCount: Int64(size), countStyle: .file)
    }
    
    /// Format date
    var formattedDate: String {
        guard let date = modificationDate else { return "--" }
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
    
    /// Get icon SF Symbol cho file
    var fileIcon: String {
        if isSymlink { return "arrow.turn.right" }
        if isDirectory { return "folder.fill" }
        
        let ext = fileExtension.lowercased()
        switch ext {
        case "swift", "m", "h": return "swift"
        case "js", "ts", "jsx", "tsx": return "doc.text"
        case "json", "plist": return "doc.text"
        case "md": return "doc.text"
        case "png", "jpg", "jpeg", "gif", "svg", "webp": return "photo"
        case "mp4", "mov", "avi", "mkv": return "video"
        case "mp3", "wav", "flac", "m4a": return "music.note"
        case "zip", "tar", "gz", "bz2", "7z", "rar": return "archivebox"
        case "pdf": return "doc.richtext"
        case "txt", "rtf": return "doc.text"
        case "html", "htm": return "doc.text"
        case "css": return "doc.text"
        case "xcodeproj", "xcworkspace": return "folder.badge.gearshape"
        default: return "doc"
        }
    }
    
    /// Get color cho icon
    var fileIconColor: Color {
        if isSymlink { return .purple }
        if isDirectory { return .blue }
        
        let ext = fileExtension.lowercased()
        switch ext {
        case "swift", "m", "h": return .orange
        case "js", "ts", "jsx", "tsx": return .yellow
        case "json", "plist": return .gray
        case "md": return .blue
        case "png", "jpg", "jpeg", "gif", "svg", "webp": return .green
        case "mp4", "mov", "avi", "mkv": return .red
        case "mp3", "wav", "flac", "m4a": return .pink
        case "zip", "tar", "gz", "bz2", "7z", "rar": return .brown
        case "pdf": return .red
        case "html", "htm", "css": return .orange
        case "xcodeproj", "xcworkspace": return .blue
        default: return .gray
        }
    }
}

// MARK: - Date Extensions

extension Date {
    /// Format date thành string ngắn
    var shortString: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .none
        return formatter.string(from: self)
    }
    
    /// Format date thành string dài
    var longString: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .long
        formatter.timeStyle = .short
        return formatter.string(from: self)
    }
    
    /// Format relative time (e.g., "2 hours ago")
    var relativeString: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return formatter.localizedString(for: self, relativeTo: Date())
    }
    
    /// Kiểm tra có phải hôm nay không
    var isToday: Bool {
        Calendar.current.isDateInToday(self)
    }
    
    /// Kiểm tra có phải hôm qua không
    var isYesterday: Bool {
        Calendar.current.isDateInYesterday(self)
    }
    
    /// Kiểm tra có phải tuần này không
    var isThisWeek: Bool {
        Calendar.current.isDate(self, equalTo: Date(), toGranularity: .weekOfYear)
    }
    
    /// Kiểm tra có phải năm nay không
    var isThisYear: Bool {
        Calendar.current.isDate(self, equalTo: Date(), toGranularity: .year)
    }
}

// MARK: - Color Extensions

extension Color {
    /// Tạo color từ hex string
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }
        
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue:  Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
    
    /// Convert to hex string
    func toHex() -> String? {
        #if os(macOS)
        let color = NSColor(self)
        guard let components = color.cgColor.components, components.count >= 3 else {
            return nil
        }
        
        let r = Float(components[0])
        let g = Float(components[1])
        let b = Float(components[2])
        
        return String(format: "#%02lX%02lX%02lX",
                      lroundf(r * 255),
                      lroundf(g * 255),
                      lroundf(b * 255))
        #else
        return nil
        #endif
    }
    
    /// Darker variant
    func darker(by percentage: CGFloat = 0.2) -> Color {
        #if os(macOS)
        let color = NSColor(self)
        var hue: CGFloat = 0
        var saturation: CGFloat = 0
        var brightness: CGFloat = 0
        var alpha: CGFloat = 0
        
        color.getHue(&hue, saturation: &saturation, brightness: &brightness, alpha: &alpha)
        
        return Color(
            NSColor(
                hue: hue,
                saturation: saturation,
                brightness: brightness * (1 - percentage),
                alpha: alpha
            )
        )
        #else
        return self
        #endif
    }
    
    /// Lighter variant
    func lighter(by percentage: CGFloat = 0.2) -> Color {
        #if os(macOS)
        let color = NSColor(self)
        var hue: CGFloat = 0
        var saturation: CGFloat = 0
        var brightness: CGFloat = 0
        var alpha: CGFloat = 0
        
        color.getHue(&hue, saturation: &saturation, brightness: &brightness, alpha: &alpha)
        
        return Color(
            NSColor(
                hue: hue,
                saturation: saturation,
                brightness: brightness + (1 - brightness) * percentage,
                alpha: alpha
            )
        )
        #else
        return self
        #endif
    }
}

// MARK: - View Extensions

extension View {
    /// Gọi action khi double-click, không chặn selection của control bên dưới.
    func onDoubleClick(perform action: @escaping () -> Void) -> some View {
        simultaneousGesture(TapGesture(count: 2).onEnded(action))
    }

    /// Conditional modifier
    @ViewBuilder
    func `if`<Content: View>(_ condition: Bool, transform: (Self) -> Content) -> some View {
        if condition {
            transform(self)
        } else {
            self
        }
    }
    
    /// Apply modifier if condition is true
    @ViewBuilder
    func modifier<T: ViewModifier>(_ modifier: T, if condition: Bool) -> some View {
        if condition {
            self.modifier(modifier)
        } else {
            self
        }
    }
    
    /// Hide view
    @ViewBuilder
    func hidden(_ shouldHide: Bool) -> some View {
        if shouldHide {
            self.hidden()
        } else {
            self
        }
    }
}

// MARK: - Array Extensions

extension Array where Element: Hashable {
    /// Remove duplicates
    func removingDuplicates() -> [Element] {
        var addedDict = [Element: Bool]()
        
        return filter {
            addedDict.updateValue(true, forKey: $0) == nil
        }
    }
}

// MARK: - Optional Extensions

extension Optional {
    /// Return wrapped value or default
    func or(_ defaultValue: Wrapped) -> Wrapped {
        self ?? defaultValue
    }
}
