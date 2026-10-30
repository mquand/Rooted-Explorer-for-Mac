# Setup Guide

## Cách nhanh (khuyến nghị)

Nếu đã cài Homebrew:

```bash
brew install xcodegen
xcodegen generate
open Rooted.xcodeproj
```

Project Xcode được sinh từ `project.yml`. Các bước dưới đây dành cho trường hợp muốn tạo project thủ công.

## Bước 1: Tạo Xcode project

1. **File > New > Project**
2. Chọn **macOS** → **App**
3. Điền thông tin:
   - Product Name: `Rooted`
   - Team: Apple Developer ID của bạn (hoặc None khi phát triển)
   - Organization Identifier: `com.rooted`
   - Bundle Identifier: `com.rooted.explorer`
   - Interface: **SwiftUI**
   - Language: **Swift**
   - Storage: **None**
   - Minimum Deployments: **macOS 13.0**
4. Lưu project vào thư mục repo này.
5. Có thể bỏ chọn **Create Git repository** vì repo đã có sẵn.

## Bước 2: Cấu hình project

1. Chọn project **Rooted** ở navigator.
2. Chọn target **Rooted**.
3. Tab **General**:
   - Bundle Identifier: `com.rooted.explorer`
   - Deployment Target: **macOS 13.0**
4. Tab **Signing & Capabilities**:
   - Bỏ chọn **App Sandbox**.
5. Tab **Build Settings**:
   - Swift Language Version: **Swift 5**.

## Bước 3: Thêm source files

Thêm các file sau vào project, giữ nguyên cấu trúc thư mục:

```
App/RootedApp.swift
Views/ContentView.swift
Views/SidebarView.swift
Views/FileListView.swift
ViewModels/FileListViewModel.swift
ViewModels/SidebarViewModel.swift
Models/FileItem.swift
Services/GitService.swift
Services/TerminalService.swift
Services/SearchService.swift
Services/DiskUsageService.swift
Utils/Extensions.swift
```

Trong Xcode:

1. Right-click vào project → **Add Files to "Rooted"...**
2. Chọn các file/thư mục trên.
3. Bỏ chọn **Copy items if needed** nếu file đã nằm trong thư mục repo.
4. Chọn target **Rooted** → **Add**.

Lưu ý: `App/RootedApp.swift` thay thế file `RootedApp.swift` mặc định do Xcode tạo. Xoá file mặc định và `ContentView.swift` mặc định nếu còn.

## Bước 4: Build & Run

Mở `Rooted.xcodeproj`, nhấn `⌘R`, hoặc:

```bash
xcodebuild -project Rooted.xcodeproj -scheme Rooted -configuration Debug build
```

## Bước 5: Cấp Full Disk Access

App cần quyền này để truy cập `~/Desktop`, `~/Documents`, `~/Downloads` và iCloud Drive.

1. Mở **System Settings** → **Privacy & Security** → **Full Disk Access**.
2. Nhấn **+** và chọn `Rooted.app` (trong `~/Library/Developer/Xcode/DerivedData/...` khi chạy từ Xcode).
3. Khởi động lại app.

## Kiểm tra

Sau khi chạy, bạn sẽ thấy:

- Sidebar bên trái với volumes và cây thư mục.
- Danh sách file bên phải với breadcrumb, toolbar, cột kích thước/ngày sửa.
- Toggle **Show Hidden** để hiện/ẩn file ẩn.
- Nút **Terminal** và **VS Code** để mở thư mục hiện tại.

## Lỗi thường gặp

### "The file couldn't be opened because you don't have permission"

App chưa có Full Disk Access. Cấp quyền theo Bước 5.

### Build error: "No such module 'SwiftUI'"

Xcode quá cũ hoặc deployment target quá thấp. Dùng Xcode 15+ và macOS 13.0+.

### Sidebar không hiển thị

Kiểm tra các file trong `Views/` đã được thêm vào target **Rooted** và có `import SwiftUI`.
