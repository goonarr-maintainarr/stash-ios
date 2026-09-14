import Foundation
import Combine

/// Protocol for managers that need to manage error state.
///
/// Provides a standardized way to handle and clear errors across different managers.
/// Conform to this protocol to get automatic error state management with a simple API.
///
/// Example usage:
/// ```swift
/// @MainActor
/// class MyManager: ObservableObject, ErrorStateManaging {
///     @Published var errorMessage: String?
///
///     func performOperation() async {
///         do {
///             // ... operation
///         } catch {
///             setError(error)
///         }
///     }
/// }
/// ```
protocol ErrorStateManaging: AnyObject {
    /// The current error message, if any.
    var errorMessage: String? { get set }
}

extension ErrorStateManaging {
    /// Clears the current error message.
    func clearError() {
        errorMessage = nil
    }
    
    /// Sets an error message from an Error object.
    /// - Parameter error: The error to convert to a message.
    func setError(_ error: Error) {
        errorMessage = error.localizedDescription
    }
    
    /// Sets an error message from a string.
    /// - Parameter message: The error message to set.
    func setError(_ message: String) {
        errorMessage = message
    }
    
    /// Returns whether there is currently an error.
    var hasError: Bool {
        errorMessage != nil
    }
}
