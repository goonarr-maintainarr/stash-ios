import Foundation
import Combine

// MARK: - Root Error Type

/// The unified error type for the entire application.
/// All errors flow through this type for consistent handling across layers.
enum AppError: LocalizedError {
    // Layer-specific errors
    case network(NetworkError)
    case database(DatabaseError)
    case repository(RepositoryError)
    
    // API-specific errors
    case stashAPI(StashAPIError)
    case whisparrAPI(WhisparrAPIError)
    case stashDB(StashDBError)
    
    // Business logic
    case validation(ValidationError)
    case notFound(String)
    
    // Generic fallback
    case unknown(Error)
    
    // MARK: - User-Facing Messages
    
    var errorDescription: String? {
        switch self {
        case .network(let error):
            return error.userMessage
        case .database(let error):
            return error.userMessage
        case .repository(let error):
            return error.userMessage
        case .stashAPI(let error):
            return error.userMessage
        case .whisparrAPI(let error):
            return error.userMessage
        case .stashDB(let error):
            return error.userMessage
        case .validation(let error):
            return error.userMessage
        case .notFound(let resource):
            return "\(resource) not found"
        case .unknown(let error):
            return "An unexpected error occurred: \(error.localizedDescription)"
        }
    }
    
    var failureReason: String? {
        switch self {
        case .network(let error):
            return error.technicalReason
        case .database(let error):
            return error.technicalReason
        case .stashAPI(let error):
            return error.technicalReason
        case .whisparrAPI(let error):
            return error.technicalReason
        default:
            return nil
        }
    }
    
    var recoverySuggestion: String? {
        switch self {
        case .network(let error):
            return error.recoverySuggestion
        case .repository(let error):
            return error.recoverySuggestion
        case .stashAPI(let error):
            return error.recoverySuggestion
        case .whisparrAPI(let error):
            return error.recoverySuggestion
        case .validation(let error):
            return error.recoverySuggestion
        case .notFound:
            return "Try refreshing or check if the item was deleted."
        default:
            return "Please try again."
        }
    }
    
    // MARK: - Error Properties
    
    /// Whether this error is safe to retry
    var isRetryable: Bool {
        switch self {
        case .network(let error):
            return error.isRetryable
        case .stashAPI(.networkError(let netError)):
            return netError.isRetryable
        case .whisparrAPI(.networkError(let netError)):
            return netError.isRetryable
        case .database, .repository, .validation, .notFound:
            return false
        default:
            return false
        }
    }
    
    /// Whether this error should be logged (vs. silently handled)
    var shouldLog: Bool {
        switch self {
        case .notFound:
            return false // Expected in normal flow
        case .validation:
            return false // User input validation
        default:
            return true
        }
    }
}

// MARK: - Network Errors

enum NetworkError: LocalizedError {
    case noConnection
    case timeout
    case invalidURL(String)
    case httpError(statusCode: Int, response: Data?)
    case encodingFailed
    case decodingFailed(Error)
    case cancelled
    case unknown(URLError)
    
    var userMessage: String {
        switch self {
        case .noConnection:
            return "No internet connection"
        case .timeout:
            return "Request timed out"
        case .invalidURL:
            return "Invalid server URL"
        case .httpError(let code, _):
            return "Server error (\(code))"
        case .encodingFailed:
            return "Failed to prepare request"
        case .decodingFailed:
            return "Failed to parse server response"
        case .cancelled:
            return "Request was cancelled"
        case .unknown:
            return "Network error occurred"
        }
    }
    
    var technicalReason: String? {
        switch self {
        case .invalidURL(let url):
            return "Invalid URL: \(url)"
        case .httpError(let code, let data):
            let body = data.flatMap { String(data: $0, encoding: .utf8) } ?? "No response body"
            return "HTTP \(code): \(body)"
        case .decodingFailed(let error):
            return "Decoding error: \(error.localizedDescription)"
        case .unknown(let urlError):
            return urlError.localizedDescription
        default:
            return nil
        }
    }
    
    var recoverySuggestion: String? {
        switch self {
        case .noConnection:
            return "Check your internet connection and try again"
        case .timeout:
            return "Check your connection speed or try again later"
        case .invalidURL:
            return "Check your server settings"
        case .httpError(let code, _) where code >= 500:
            return "The server is experiencing issues. Try again later"
        case .httpError(let code, _) where code == 401:
            return "Check your API key in settings"
        case .httpError:
            return "Contact support if this persists"
        default:
            return "Try again"
        }
    }
    
    var isRetryable: Bool {
        switch self {
        case .noConnection, .timeout:
            return true
        case .httpError(let code, _) where code >= 500:
            return true
        case .cancelled, .invalidURL, .encodingFailed:
            return false
        case .httpError(let code, _) where code == 401:
            return false // Auth error
        case .httpError:
            return true // Other HTTP errors are retryable
        case .decodingFailed:
            return false // Data format issue
        case .unknown:
            return true
        }
    }
}

// MARK: - Database Errors

enum DatabaseError: LocalizedError {
    case notInitialized
    case migrationFailed(String)
    case queryFailed(String)
    case corruptedData(String)
    case diskFull
    
    var userMessage: String {
        switch self {
        case .notInitialized:
            return "Database not ready"
        case .migrationFailed:
            return "Failed to upgrade database"
        case .queryFailed:
            return "Failed to access local data"
        case .corruptedData:
            return "Local data is corrupted"
        case .diskFull:
            return "Device storage is full"
        }
    }
    
    var technicalReason: String? {
        switch self {
        case .migrationFailed(let details):
            return "Migration failed: \(details)"
        case .queryFailed(let details):
            return "Query failed: \(details)"
        case .corruptedData(let details):
            return "Corrupted data: \(details)"
        default:
            return nil
        }
    }
    
    var recoverySuggestion: String? {
        switch self {
        case .notInitialized:
            return "Restart the app"
        case .migrationFailed:
            return "You may need to reinstall the app"
        case .diskFull:
            return "Free up storage space on your device"
        case .corruptedData:
            return "Try clearing app data in Settings"
        default:
            return "Try refreshing from the server"
        }
    }
}

// MARK: - Repository Errors

enum RepositoryError: LocalizedError {
    case invalidConfiguration
    case notFound
    case alreadyExists
    case concurrencyConflict
    case syncFailed(String)
    
    var userMessage: String {
        switch self {
        case .invalidConfiguration:
            return "App configuration is invalid"
        case .notFound:
            return "Item not found"
        case .alreadyExists:
            return "Item already exists"
        case .concurrencyConflict:
            return "Data was modified elsewhere"
        case .syncFailed:
            return "Failed to sync data"
        }
    }
    
    var technicalReason: String? {
        switch self {
        case .syncFailed(let reason):
            return reason
        default:
            return nil
        }
    }
    
    var recoverySuggestion: String? {
        switch self {
        case .invalidConfiguration:
            return "Check your server URL and API key in Settings"
        case .notFound:
            return "The item may have been deleted"
        case .alreadyExists:
            return "Try refreshing the list"
        case .concurrencyConflict:
            return "Refresh and try again"
        case .syncFailed:
            return "Pull to refresh or check your connection"
        }
    }
}

// MARK: - Validation Errors

enum ValidationError: LocalizedError {
    case emptyField(String)
    case invalidFormat(String)
    case outOfRange(String, min: Int?, max: Int?)
    case custom(String)
    
    var userMessage: String {
        switch self {
        case .emptyField(let field):
            return "\(field) cannot be empty"
        case .invalidFormat(let field):
            return "\(field) format is invalid"
        case .outOfRange(let field, let min, let max):
            if let min = min, let max = max {
                return "\(field) must be between \(min) and \(max)"
            } else if let min = min {
                return "\(field) must be at least \(min)"
            } else if let max = max {
                return "\(field) must be at most \(max)"
            }
            return "\(field) is out of range"
        case .custom(let message):
            return message
        }
    }
    
    var recoverySuggestion: String? {
        return "Please correct the input and try again"
    }
}

// MARK: - API-Specific Errors

enum StashAPIError: LocalizedError {
    case invalidResponse
    case graphQLErrors([String])
    case unauthorizedAPIKey
    case networkError(NetworkError)
    
    var userMessage: String {
        switch self {
        case .invalidResponse:
            return "Invalid server response"
        case .graphQLErrors(let messages):
            return messages.first ?? "Server error"
        case .unauthorizedAPIKey:
            return "Invalid API key"
        case .networkError(let error):
            return error.userMessage
        }
    }
    
    var technicalReason: String? {
        switch self {
        case .graphQLErrors(let messages):
            return "GraphQL errors: \(messages.joined(separator: ", "))"
        case .networkError(let error):
            return error.technicalReason
        default:
            return nil
        }
    }
    
    var recoverySuggestion: String? {
        switch self {
        case .unauthorizedAPIKey:
            return "Check your API key in Settings"
        case .networkError(let error):
            return error.recoverySuggestion
        default:
            return "Try again or contact support"
        }
    }
}

enum WhisparrAPIError: LocalizedError {
    case invalidResponse
    case notFound
    case unauthorizedAPIKey
    case validationErrors([WhisparrValidationError])
    case networkError(NetworkError)
    
    var userMessage: String {
        switch self {
        case .invalidResponse:
            return "Invalid Whisparr response"
        case .notFound:
            return "Not found in Whisparr"
        case .unauthorizedAPIKey:
            return "Invalid Whisparr API key"
        case .validationErrors(let errors):
            return errors.first?.errorMessage ?? "Validation error"
        case .networkError(let error):
            return error.userMessage
        }
    }
    
    var technicalReason: String? {
        switch self {
        case .validationErrors(let errors):
            let messages = errors.map { "\($0.propertyName): \($0.errorMessage)" }
            return "Validation errors: \(messages.joined(separator: ", "))"
        case .networkError(let error):
            return error.technicalReason
        default:
            return nil
        }
    }
    
    var recoverySuggestion: String? {
        switch self {
        case .unauthorizedAPIKey:
            return "Check your Whisparr API key in Settings"
        case .notFound:
            return "Make sure the item exists in Whisparr"
        case .validationErrors:
            return "Check the input data and try again"
        case .networkError(let error):
            return error.recoverySuggestion
        default:
            return "Check your Whisparr configuration"
        }
    }
}

enum StashDBError: LocalizedError {
    case invalidResponse
    case unauthorizedAPIKey
    case rateLimited
    case networkError(NetworkError)
    
    var userMessage: String {
        switch self {
        case .invalidResponse:
            return "Invalid StashDB response"
        case .unauthorizedAPIKey:
            return "Invalid StashDB API key"
        case .rateLimited:
            return "StashDB rate limit exceeded"
        case .networkError(let error):
            return error.userMessage
        }
    }
    
    var technicalReason: String? {
        switch self {
        case .networkError(let error):
            return error.technicalReason
        default:
            return nil
        }
    }
    
    var recoverySuggestion: String? {
        switch self {
        case .unauthorizedAPIKey:
            return "Check your StashDB API key in Settings"
        case .rateLimited:
            return "Wait a few minutes before trying again"
        case .networkError(let error):
            return error.recoverySuggestion
        default:
            return "Try again later"
        }
    }
}

// MARK: - Supporting Types

struct WhisparrValidationError: Codable {
    let propertyName: String
    let errorMessage: String
    let severity: String
    let attemptedValue: AnyCodable?
}

// Minimal AnyCodable for validation errors
struct AnyCodable: Codable {
    let value: Any
    
    init(_ value: Any) {
        self.value = value
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let boolVal = try? container.decode(Bool.self) { value = boolVal }
        else if let intVal = try? container.decode(Int.self) { value = intVal }
        else if let doubleVal = try? container.decode(Double.self) { value = doubleVal }
        else if let stringVal = try? container.decode(String.self) { value = stringVal }
        else { value = "unsupported" }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        if let boolVal = value as? Bool { try container.encode(boolVal) }
        else if let intVal = value as? Int { try container.encode(intVal) }
        else if let doubleVal = value as? Double { try container.encode(doubleVal) }
        else if let stringVal = value as? String { try container.encode(stringVal) }
    }
}

// MARK: - Error Conversion Extensions

extension URLError {
    func toNetworkError() -> NetworkError {
        switch self.code {
        case .notConnectedToInternet, .networkConnectionLost:
            return .noConnection
        case .timedOut:
            return .timeout
        case .cancelled:
            return .cancelled
        default:
            return .unknown(self)
        }
    }
}

extension Error {
    /// Convert any error to AppError for consistent handling
    func toAppError() -> AppError {
        if let appError = self as? AppError {
            return appError
        }
        
        if let urlError = self as? URLError {
            return .network(urlError.toNetworkError())
        }
        
        if let decodingError = self as? DecodingError {
            return .network(.decodingFailed(decodingError))
        }
        
        return .unknown(self)
    }
}
