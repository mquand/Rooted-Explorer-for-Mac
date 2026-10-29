# Rooted

File manager mã nguồn mở cho macOS, viết bằng SwiftUI. Hiển thị cả những file mà Finder ẩn và bổ sung các thao tác cần thiết cho lập trình viên.

## Tính năng

### Đã có

- **Sidebar dạng cây:** Favorites (Home, Desktop, Documents, Downloads), volumes + dung lượng trống, cây thư mục load lười (chỉ đọc thư mục con khi mở rộng).
- **Ba chế độ xem:** List (bảng), Icons (grid có thumbnail), Gallery (preview lớn + filmstrip).
- **Thumbnail:** ảnh, PDF, video, audio và icon hệ thống cho mọi file.
- **Điều hướng:** back/forward, lên thư mục cha, về Home, nhập đường dẫn trực tiếp trên thanh toolbar.
- **Hành vi click:** mặc định click để chọn, double-click để mở thư mục/file; có thể bật *Open folders with a single click* trong Settings.
- **Copy / Cut / Paste:** dùng clipboard chuẩn của Finder (`⌘C`, `⌘X`, `⌘V`), tự đổi tên khi trùng (`file copy.ext`).
- **Thao tác file:** double-click mở, context menu, Rename, Duplicate, Move to Trash, New Folder, Reveal in Finder, Open in Terminal.
- **Tính dung lượng thư mục:** tự tính ở background cho các thư mục đang xem, hoặc bấm *Calculate Size* trong context menu.
- **Git:** hiển thị branch hiện tại và badge trạng thái từng file (modified, untracked, staged, conflict).
- **Mở terminal/IDE:** Terminal, iTerm2, Warp, Ghostty; VS Code, Cursor, Xcode, WebStorm, IntelliJ.
- **Tìm kiếm:** theo tên qua Spotlight (`mdfind`) hoặc `find`, theo nội dung qua ripgrep/grep.
- **Phân tích dung lượng:** thông tin volume, kích thước thư mục, quét dev junk (`node_modules`, `.venv`, `__pycache__`, DerivedData...).
- **Tự động cập nhật:** kiểm tra GitHub Releases khi khởi động, tải và thay thế app khi chạy từ `/Applications`.

### Đang phát triển

- Tab, dual-pane, kéo thả giữa các pane.
- Quick Look (`Space`), undo/redo.
- Command palette (`⌘K`), chmod/chown GUI.
- File watcher (FSEvents), terminal nhúng, treemap dung lượng, workspaces.

## Phím tắt

| Phím | Chức năng |
|---|---|
| `⌘C` / `⌘X` / `⌘V` | Copy / Cut / Paste file |
| `⌘A` | Chọn tất cả |
| `⌘⌫` | Chuyển vào Trash |
| `⌘[` / `⌘]` | Back / Forward |
| `⌘↑` | Lên thư mục cha |
| `⇧⌘H` | Về Home |
| `⌘R` | Refresh |
| `⇧⌘N` | Tạo thư mục mới |
| `⌘,` | Settings |

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
│   ├── SidebarView.swift         # Sidebar cây thư mục + favorites
│   ├── FileListView.swift        # Toolbar, list/icons/gallery, thumbnail
│   ├── FileItemActions.swift     # Context menu dùng chung
│   ├── SettingsView.swift        # Settings (General / Updates / About)
│   └── UpdateBanner.swift        # Banner báo bản cập nhật
├── ViewModels/
│   ├── FileListViewModel.swift   # State file list, navigation, clipboard
│   └── SidebarViewModel.swift    # Cây thư mục load lười
├── Models/
│   ├── FileItem.swift            # File data model
│   └── AppSettings.swift         # Cài đặt lưu trong UserDefaults
├── Services/
│   ├── GitService.swift          # Git status, branch, diff
│   ├── TerminalService.swift     # Mở terminal/IDE
│   ├── SearchService.swift       # Tìm file và nội dung
│   ├── DiskUsageService.swift    # Dung lượng, dev junk
│   ├── FilePasteboard.swift      # Copy/cut/paste file
│   ├── ThumbnailService.swift    # QuickLook thumbnail + cache
│   └── UpdateService.swift       # GitHub Releases updater
├── Resources/
│   └── Assets.xcassets/          # AppIcon
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
git tag v0.2.0
git push origin v0.2.0
```

Workflow sẽ build, đóng gói và tạo GitHub Release kèm `.zip` + `.dmg`. Bản build dùng **ad-hoc signing**, chưa notarize, nên sau khi tải về cần chuột phải → **Open** hoặc chạy `xattr -dr com.apple.quarantine /Applications/Rooted.app`.

App tự kiểm tra bản mới qua GitHub Releases API khi khởi động (có thể tắt trong **Settings → Updates**). Nếu app đang nằm trong `/Applications` hoặc `~/Applications`, bấm **Update** sẽ tải, thay thế và mở lại app; nếu chạy từ thư mục build, app sẽ mở trang release để tải thủ công.

## Quyền và phân phối

- App không bật App Sandbox để truy cập được toàn hệ thống.
- Cần **Full Disk Access** để đọc `~/Desktop`, `~/Documents`, `~/Downloads` và iCloud Drive.
- Bundle ID: `com.rooted.explorer`.
- Bản phát hành trên GitHub dùng ad-hoc signing (Hardened Runtime bật, chưa notarize) và phát hành ngoài Mac App Store.

## Đóng góp

1. Fork repo và tạo nhánh từ `main`.
2. Giữ cấu trúc MVVM hiện tại: View → ViewModel → Service, service dùng singleton.
3. Mở pull request kèm mô tả thay đổi và cách kiểm tra.

Khi báo lỗi, ghi rõ phiên bản macOS, Xcode và các bước tái hiện.

## Giấy phép

[MIT](LICENSE)
