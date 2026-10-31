# Rooted 🌲

[![Build & Release](https://github.com/mquand/Rooted-Explorer-for-Mac/actions/workflows/build.yml/badge.svg)](https://github.com/mquand/Rooted-Explorer-for-Mac/actions/workflows/build.yml)
[![Release](https://img.shields.io/github/v/release/mquand/Rooted-Explorer-for-Mac?color=blue)](https://github.com/mquand/Rooted-Explorer-for-Mac/releases/latest)
[![macOS](https://img.shields.io/badge/macOS-13.0+-brightgreen.svg)](https://apple.com/macos)
[![Swift](https://img.shields.io/badge/Swift-6.0-orange.svg)](https://swift.org)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

File Manager mã nguồn mở, hiện đại và siêu tốc dành cho macOS, viết hoàn toàn bằng SwiftUI & AppKit native. Hiển thị toàn bộ tệp ẩn và tích hợp các tiện ích chuyên sâu cho lập trình viên.

---

## ✨ Tính năng nổi bật

### 🖥 Giao diện & Chế độ xem
- **3 Chế độ hiển thị linh hoạt:** List (bảng chi tiết), Icons (lưới thumbnail sắc nét), Gallery (xem trước khổ lớn + dải filmstrip).
- **Sidebar dạng cây thông minh:** Truy cập nhanh Favorites, phân vùng ổ đĩa và cây thư mục nạp lười (*lazy loading* con chỉ khi mở rộng).
- **Thanh đường dẫn Breadcrumb:** Bấm vào từng cấp thư mục để điều hướng nhanh, hoặc nhấn `⇧⌘G` để gõ trực tiếp đường dẫn (*Go to Folder*).
- **Sắp xếp kiểu Explorer:** Nhấp vào tiêu đề cột (`Name`, `Size`, `Kind`, `Modified`) để sắp xếp / đảo chiều; thư mục luôn ưu tiên đứng trước tệp.
- **Thanh trạng thái trực quan:** Theo dõi số lượng item, số mục đang chọn, tổng dung lượng, dung lượng trống của ổ cứng và Git branch hiện tại.

### ⚡️ Thao tác tệp chuyên nghiệp
- **Quick Look (`Space`):** Xem trước nội dung tệp tức thì bằng `QLPreviewPanel` chuẩn macOS (hỗ trợ nhiều tệp cùng lúc).
- **Finder Tags 7 màu:** Đọc và gắn tag màu chuẩn Finder qua thuộc tính mở rộng metadata (`xattr`), đồng bộ 100% với macOS Finder.
- **Clipboard & Thao tác an toàn:** Hỗ trợ chuẩn Copy / Cut / Paste (`⌘C`, `⌘X`, `⌘V`), tự động đổi tên khi trùng, bảo vệ chống lỗi khi di chuyển vào Trash hoặc đổi tên.
- **Điều hướng phím tắt nhanh:** Hỗ trợ *Type-to-select* (gõ chữ để nhảy tới tệp) và phím mũi tên trong chế độ Icons / Gallery.

### 🛠 Dành riêng cho Lập trình viên
- **Tích hợp Git trạng thái thực:** Hiển thị branch hiện tại và badge trực quan cho từng tệp (`M` Modified, `?` Untracked, `A` Staged, `!` Conflict).
- **Mở nhanh Terminal & IDE:** Khởi chạy tức thì thư mục hiện tại trong Terminal (iTerm2, Warp, Ghostty...) hoặc IDE (VS Code, Cursor, Xcode, WebStorm...).
- **Phân tích dung lượng & Dọn rác Dev:** Quét dung lượng phân vùng, phát hiện các thư mục nặng và dọn dẹp các thư mục rác phổ biến (`node_modules`, `.venv`, `DerivedData`, cache...).

---

## ⌨️ Phím tắt tiện dụng

| Thao tác | Phím tắt | Thao tác | Phím tắt |
|---|---|---|---|
| **Xem trước (Quick Look)** | `Space` / `Esc` | **Sao chép / Cắt / Dán** | `⌘C` / `⌘X` / `⌘V` |
| **Tìm kiếm (Search)** | `⌘F` | **Chuyển vào Thùng rác** | `⌘⌫` |
| **Đến thư mục (Go to Folder)** | `⇧⌘G` | **Chọn tất cả** | `⌘A` |
| **Lên thư mục cha** | `⌘↑` | **Tạo thư mục mới** | `⇧⌘N` |
| **Back / Forward** | `⌘[` / `⌘]` | **Làm mới danh sách** | `⌘R` |
| **Về thư mục Home** | `⇧⌘H` | **Cài đặt (Settings)** | `⌘,` |
| **Đổi chế độ xem** | `⌘1` (List) / `⌘2` (Icons) / `⌘3` (Gallery) | **Mở tệp/thư mục** | `Enter` / Double Click |

---

## 🚀 Cài đặt & Bắt đầu

### Tải ứng dụng (Đã đóng gói)
Tải bản `.dmg` hoặc `.zip` mới nhất từ [GitHub Releases](https://github.com/mquand/Rooted-Explorer-for-Mac/releases/latest).

> [!NOTE]
> Do ứng dụng sử dụng ad-hoc signing (chưa đăng ký chứng chỉ trả phí Apple Developer), trong lần mở đầu tiên:
> - Chuột phải vào ứng dụng trong Applications → Chọn **Open**.
> - Hoặc chạy lệnh sau trong Terminal:
>   ```bash
>   xattr -dr com.apple.quarantine /Applications/Rooted.app
>   ```

> [!IMPORTANT]
> **Cấp quyền Full Disk Access:**  
> Vào **System Settings** → **Privacy & Security** → **Full Disk Access** và bật **Rooted** để ứng dụng có quyền đọc các thư mục hệ thống, Desktop, Downloads và Documents.

---

### Biên dịch từ mã nguồn (Developers)

**Yêu cầu môi trường:**
- macOS 13.0+
- Xcode 16.0+
- Swift 6.0+

```bash
# 1. Clone repository
git clone https://github.com/mquand/Rooted-Explorer-for-Mac.git Rooted
cd Rooted

# 2. Cài đặt XcodeGen và tạo Xcode project
brew install xcodegen
xcodegen generate

# 3. Mở và biên dịch dự án
open Rooted.xcodeproj
```

---

## 🏗 Cấu trúc kiến trúc

Dự án áp dụng kiến trúc **MVVM (Model-View-ViewModel)** kết hợp nguyên tắc Swift 6 Strict Concurrency an toàn luồng:

```
Rooted/
├── App/           # Điểm khởi chạy ứng dụng SwiftUI (RootedApp)
├── Models/        # Dữ liệu đối tượng: FileItem, FinderTag, AppSettings
├── ViewModels/    # Quản lý trạng thái logic: FileListViewModel, SidebarViewModel
├── Views/         # Giao diện người dùng: FileListView, SidebarView, PathBar, Sheets...
├── Services/      # Tầng dịch vụ nền: GitService, QuickLook, Search, Thumbnails...
├── Resources/     # Tài nguyên hình ảnh, biểu tượng (Assets.xcassets)
├── Tools/         # Công cụ bổ trợ: makeicon.py (tạo icon từ ảnh gốc)
└── Utils/         # Các tiện ích mở rộng SwiftUI & AppKit
```

---

## 📦 Phát hành (Release Workflow)

Dự án sử dụng GitHub Actions tự động hóa hoàn toàn quy trình đóng gói. Để tạo bản phát hành mới:

```bash
git tag v0.3.1
git push origin v0.3.1
```
Workflow sẽ tự động biên dịch universal binary (`arm64` & `x86_64`), ký ad-hoc, tạo file `.dmg` / `.zip` và đăng tải lên GitHub Releases.

---

## 📄 Giấy phép

Phát hành theo giấy phép [MIT License](LICENSE).
