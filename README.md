# Rooted

File manager mã nguồn mở cho macOS, viết bằng SwiftUI. Hiển thị cả những file mà Finder ẩn và bổ sung các thao tác cần thiết cho lập trình viên.

## Tính năng

### Đã có

- **Sidebar dạng cây:** volumes, dung lượng trống, cây thư mục mở rộng/thu gọn; bấm để điều hướng.
- **Danh sách file:** sắp xếp theo tên, kích thước, ngày sửa, loại; bật/tắt hiển thị file ẩn; làm mờ file ẩn; double-click để mở file/thư mục.
- **Git:** hiển thị branch hiện tại và badge trạng thái từng file (modified, untracked, staged, conflict).
- **Mở terminal/IDE:** Terminal, iTerm2, Warp, Ghostty; VS Code, Cursor, Xcode, WebStorm, IntelliJ.
- **Tìm kiếm:** theo tên qua Spotlight (`mdfind`) hoặc `find`, theo nội dung qua ripgrep/grep.
- **Phân tích dung lượng:** thông tin volume, kích thước thư mục, quét dev junk (`node_modules`, `.venv`, `__pycache__`, DerivedData...).
- **Icon theo loại file**, hiển thị symlink.

Các thao tác copy, move, rename, xoá, tạo file/thư mục đã có ở tầng service/ViewModel; giao diện cho các thao tác này đang được hoàn thiện.

### Đang phát triển

- Tab, dual-pane, kéo thả giữa các pane.
- Cut/paste file thực sự.
- Quick Look, context menu trên danh sách file.
- Command palette (`⌘K`).
- Chmod/chown GUI, copy path, tạo file từ template.
- File watcher (FSEvents), undo/redo.
- Terminal nhúng, treemap dung lượng, workspaces.

## Yêu cầu

- macOS 13.0+
- Xcode 15.0+
- Swift 5.9+

## Cấu trúc dự án

```
Rooted/
├── App/
│   └── RootedApp.swift           # SwiftUI App entry point
├── Views/
│   ├── ContentView.swift         # NavigationSplitView (sidebar + main)
│   ├── SidebarView.swift         # Sidebar tree view (volumes + folders)
│   └── FileListView.swift        # Breadcrumb, toolbar, file table
├── ViewModels/
│   ├── FileListViewModel.swift   # State cho file list
│   └── SidebarViewModel.swift    # State cho sidebar
├── Models/
│   └── FileItem.swift            # File data model
├── Services/
│   ├── GitService.swift          # Git status, branch, diff
│   ├── TerminalService.swift     # Mở terminal/IDE
│   ├── SearchService.swift       # Tìm file và nội dung
│   └── DiskUsageService.swift    # Dung lượng, dev junk
└── Utils/
    └── Extensions.swift          # String, Date, Color, View extensions
```

## Bắt đầu

Cần macOS 13.0+ và Xcode 15.0+.

```bash
git clone <repo-url> Rooted
cd Rooted
brew install xcodegen
xcodegen generate
open Rooted.xcodeproj
```

File `.xcodeproj` được sinh từ `project.yml` nên không commit vào repo. Nếu không dùng XcodeGen, xem hướng dẫn tạo project thủ công trong [SETUP.md](SETUP.md).

Build từ command line:

```bash
xcodebuild -project Rooted.xcodeproj -scheme Rooted -configuration Debug build
```

## Build & Release

[![Build & Release](https://github.com/mquand/Rooted-Explorer-for-Mac/actions/workflows/build.yml/badge.svg)](https://github.com/mquand/Rooted-Explorer-for-Mac/actions/workflows/build.yml)

Mỗi lần push hoặc mở pull request, GitHub Actions sẽ build app trên macOS runner và upload `.zip`/`.dmg` vào tab **Actions**.

Để tạo release, push một tag:

```bash
git tag v0.1.0
git push origin v0.1.0
```

Workflow sẽ build, đóng gói và tạo GitHub Release kèm `.zip` + `.dmg`. Bản build dùng ad-hoc signing, chưa notarize, nên sau khi tải về cần chuột phải → **Open** hoặc chạy `xattr -dr com.apple.quarantine Rooted.app`.

## Quyền và phân phối

- App không bật App Sandbox để truy cập được toàn hệ thống.
- Cần **Full Disk Access** để đọc `~/Desktop`, `~/Documents`, `~/Downloads` và iCloud Drive.
- Bundle ID: `com.rooted.explorer`.
- Bản phát hành dùng Hardened Runtime, ký bằng Developer ID và notarize; phát hành ngoài Mac App Store.

## Đóng góp

1. Fork repo và tạo nhánh từ `main`.
2. Giữ cấu trúc MVVM hiện tại: View → ViewModel → Service, service dùng singleton.
3. Mở pull request kèm mô tả thay đổi và cách kiểm tra.

Khi báo lỗi, ghi rõ phiên bản macOS, Xcode và các bước tái hiện.

## Giấy phép

[MIT](LICENSE)
