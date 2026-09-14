import Foundation

/// A protocol that defines the requirements for a sortable type to be used with sorting UI components.
protocol SortableType: RawRepresentable, CaseIterable, Identifiable, Equatable where RawValue == String {
    var id: String { get }
    var displayName: String { get }
}
