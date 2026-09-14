import Foundation

/// A protocol defining the core states that a view can be in.
/// Provides a standardized approach to view state management across the app.
protocol ViewStateProtocol: Equatable {
    associatedtype Content
    
    /// The view is in an idle state, not yet loaded
    static var idle: Self { get }
    
    /// The view is loading content
    static var loading: Self { get }
    
    /// The view has successfully loaded content
    static func content(_ content: Content) -> Self
    
    /// The view has no content to display (empty state)
    static var empty: Self { get }
    
    /// The view encountered an error
    static func error(_ message: String) -> Self
}

/// Standard ViewState implementation for single item views (e.g., detail views)
enum ViewState<T>: Equatable where T: Equatable {
    case idle
    case loading
    case content(T)
    case empty
    case error(String)
    
    /// Returns the content if in content state, nil otherwise
    var content: T? {
        if case .content(let value) = self {
            return value
        }
        return nil
    }
    
    /// Returns true if currently in loading state
    var isLoading: Bool {
        if case .loading = self { return true }
        return false
    }
    
    /// Returns the error message if in error state, nil otherwise
    var errorMessage: String? {
        if case .error(let message) = self {
            return message
        }
        return nil
    }
    
    /// Returns true if in empty state
    var isEmpty: Bool {
        if case .empty = self { return true }
        return false
    }
}

/// Standard ViewState implementation for list views
enum ListViewState<T>: Equatable where T: Equatable {
    case idle
    case loading
    case content([T])
    case empty
    case error(String)
    
    /// Returns the items if in content state, empty array otherwise
    var items: [T] {
        if case .content(let items) = self {
            return items
        }
        return []
    }
    
    /// Returns true if currently in loading state
    var isLoading: Bool {
        if case .loading = self { return true }
        return false
    }
    
    /// Returns the error message if in error state, nil otherwise
    var errorMessage: String? {
        if case .error(let message) = self {
            return message
        }
        return nil
    }
    
    /// Returns true if in empty state
    var isEmpty: Bool {
        if case .empty = self { return true }
        return false
    }
}

/// ViewState for views with sync/progress capabilities
enum SyncViewState: Equatable {
    case idle
    case loading
    case syncing(progress: Double, message: String)
    case loaded
    case error(String)
    
    /// Returns true if currently syncing
    var isSyncing: Bool {
        if case .syncing = self { return true }
        return false
    }
    
    /// Returns the sync progress if syncing, nil otherwise
    var syncProgress: (progress: Double, message: String)? {
        if case .syncing(let progress, let message) = self {
            return (progress, message)
        }
        return nil
    }
    
    /// Returns true if currently in loading state
    var isLoading: Bool {
        if case .loading = self { return true }
        return false
    }
    
    /// Returns the error message if in error state, nil otherwise
    var errorMessage: String? {
        if case .error(let message) = self {
            return message
        }
        return nil
    }
}

// MARK: - ViewState Extensions for Common Operations

extension ViewState {
    /// Updates to content state if the optional value is non-nil, otherwise sets empty state
    mutating func setContent(_ value: T?) {
        if let value = value {
            self = .content(value)
        } else {
            self = .empty
        }
    }
    
    /// Mutates the content in place using a closure, if in content state.
    /// - Parameter transform: A closure that modifies the content.
    /// - Returns: True if the mutation was applied (content existed), false otherwise.
    @discardableResult
    mutating func mutateContent(_ transform: (inout T) -> Void) -> Bool {
        guard case .content(var content) = self else { return false }
        transform(&content)
        self = .content(content)
        return true
    }
    
    /// Mutates the content in place using a closure, if in content state.
    /// Convenience for read-only access without copying.
    /// - Parameter transform: A closure that receives the current content.
    func withContent<Result>(_ transform: (T) -> Result) -> Result? {
        guard case .content(let content) = self else { return nil }
        return transform(content)
    }
}

extension ListViewState {
    /// Updates to content state if array is non-empty, otherwise sets empty state
    mutating func setContent(_ items: [T]) {
        if items.isEmpty {
            self = .empty
        } else {
            self = .content(items)
        }
    }
}
