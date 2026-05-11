import Foundation

// MARK: - Safe Collection Operations

extension Collection where Element: BinaryFloatingPoint {
    /// Safe average that returns 0 for empty collections instead of crashing with division by zero
    var safeAverage: Element {
        isEmpty ? 0 : reduce(0, +) / Element(count)
    }
}

extension Collection {
    /// Safe index access — returns nil instead of crashing on out-of-bounds
    func safe(at index: Index) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}

// MARK: - Safe Calendar Operations

extension Calendar {
    /// Safe date(byAdding:) that returns the original date on failure instead of crashing
    func safeDate(byAdding component: Calendar.Component, value: Int, to date: Date) -> Date {
        self.date(byAdding: component, value: value, to: date) ?? date
    }

    /// Safe date(from:) that returns current date on failure instead of crashing
    func safeDate(from components: DateComponents) -> Date {
        self.date(from: components) ?? Date()
    }
}
