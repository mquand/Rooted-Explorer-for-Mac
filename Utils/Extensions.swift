import SwiftUI

// MARK: - View Extensions

extension View {
    /// Gọi action khi double-click, không chặn selection của control bên dưới.
    func onDoubleClick(perform action: @escaping () -> Void) -> some View {
        simultaneousGesture(TapGesture(count: 2).onEnded(action))
    }

    /// Áp dụng modifier có điều kiện.
    @ViewBuilder
    func `if`<Content: View>(_ condition: Bool, transform: (Self) -> Content) -> some View {
        if condition {
            transform(self)
        } else {
            self
        }
    }
}
