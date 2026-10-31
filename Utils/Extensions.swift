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

// MARK: - Array Extensions

extension Array {
    /// Map song song trên các phần tử với concurrency limit.
    func concurrentMap<T>(_ transform: @escaping (Element) async -> T) async -> [T] {
        await withTaskGroup(of: (Int, T).self) { group in
            for (index, element) in self.enumerated() {
                group.addTask {
                    let result = await transform(element)
                    return (index, result)
                }
            }

            var results: [(Int, T)] = []
            for await (index, result) in group {
                results.append((index, result))
            }

            results.sort { $0.0 < $1.0 }
            return results.map { $0.1 }
        }
    }

    /// Map song song cho transform không async (dùng Thread Pool).
    func concurrentMap<T>(_ transform: @escaping (Element) -> T) -> [T] {
        let lock = NSLock()
        var results: [(Int, T)] = []

        DispatchQueue.concurrentPerform(iterations: count) { index in
            let result = transform(self[index])
            lock.lock()
            results.append((index, result))
            lock.unlock()
        }

        results.sort { $0.0 < $1.0 }
        return results.map { $0.1 }
    }
}
