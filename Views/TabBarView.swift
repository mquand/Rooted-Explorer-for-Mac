import SwiftUI

/// Thanh Tab và điều khiển Dual-Pane phía trên cửa sổ
struct TabBarView: View {
    @ObservedObject var tabManager: TabManager

    var body: some View {
        HStack(spacing: 0) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 4) {
                    ForEach(tabManager.tabs) { tab in
                        TabButton(
                            tab: tab,
                            isActive: tab.id == tabManager.activeTabId,
                            canClose: tabManager.tabs.count > 1,
                            onSelect: {
                                tabManager.activeTabId = tab.id
                            },
                            onClose: {
                                tabManager.closeTab(id: tab.id)
                            }
                        )
                    }

                    // Nút thêm tab mới (+)
                    Button {
                        tabManager.newTab()
                    } label: {
                        Image(systemName: "plus")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(.secondary)
                            .frame(width: 24, height: 24)
                            .background(
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(Color.primary.opacity(0.04))
                            )
                    }
                    .buttonStyle(.plain)
                    .help("Tab mới (⌘T)")
                    .padding(.leading, 2)
                }
                .padding(.leading, 78) // Chừa khoảng trống cho 3 nút điều khiển cửa sổ macOS (Traffic Lights)
                .padding(.trailing, 8)
                .padding(.vertical, 5)
            }

            Spacer(minLength: 8)

            // Nút bật/tắt Dual-Pane (chia 2 khung trái/phải)
            Button {
                withAnimation(.easeInOut(duration: 0.18)) {
                    tabManager.activeTab.toggleDualPane()
                }
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: tabManager.activeTab.isDualPane ? "rectangle.split.2x1.fill" : "rectangle.split.2x1")
                        .font(.system(size: 13))
                    Text("2 Khung")
                        .font(.system(size: 11, weight: .medium))
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(tabManager.activeTab.isDualPane ? Color.accentColor.opacity(0.18) : Color.primary.opacity(0.04))
                )
                .foregroundColor(tabManager.activeTab.isDualPane ? .accentColor : .secondary)
            }
            .buttonStyle(.plain)
            .help("Chia 2 khung song song (Dual-Pane) (⌘⌥D)")
            .padding(.trailing, 10)
        }
        .frame(height: 34)
        .background(Color(nsColor: .windowBackgroundColor))
    }
}

private struct TabButton: View {
    @ObservedObject var tab: TabItem
    let isActive: Bool
    let canClose: Bool
    let onSelect: () -> Void
    let onClose: () -> Void

    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: tab.isDualPane ? "square.split.2x1" : "folder.fill")
                .font(.system(size: 11))
                .foregroundColor(isActive ? .accentColor : .secondary)

            Text(tab.title)
                .font(.system(size: 12, weight: isActive ? .semibold : .regular))
                .foregroundColor(isActive ? .primary : .secondary)
                .lineLimit(1)
                .truncationMode(.middle)
                .frame(maxWidth: 130)

            if canClose {
                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(.secondary)
                        .frame(width: 14, height: 14)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .opacity(isHovered || isActive ? 1 : 0)
                .help("Đóng tab (⌘W)")
            }
        }
        .padding(.leading, 10)
        .padding(.trailing, canClose ? 6 : 10)
        .padding(.vertical, 5)
        .background(
            RoundedRectangle(cornerRadius: 7)
                .fill(isActive ? Color(nsColor: .controlBackgroundColor) : (isHovered ? Color.primary.opacity(0.05) : Color.clear))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 7)
                .stroke(isActive ? Color.secondary.opacity(0.2) : Color.clear, lineWidth: 1)
        )
        .contentShape(Rectangle())
        .onHover { isHovered = $0 }
        .onTapGesture {
            onSelect()
        }
    }
}
