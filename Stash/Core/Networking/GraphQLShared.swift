import Foundation
import os

// MARK: - Shared GraphQL Types

/// Generic encodable wrapper for GraphQL variable values.
/// Supports encoding of common Swift types (Int, Double, String, Bool, Array, Dictionary).
struct AnyEncodable: Encodable {
    let value: Any
    
    init(_ value: Any) {
        self.value = value
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        
        if let intVal = value as? Int {
            try container.encode(intVal)
        } else if let doubleVal = value as? Double {
            try container.encode(doubleVal)
        } else if let stringVal = value as? String {
            try container.encode(stringVal)
        } else if let boolVal = value as? Bool {
            try container.encode(boolVal)
        } else if let arrayVal = value as? [Any] {
            try container.encode(arrayVal.map { AnyEncodable($0) })
        } else if let dictVal = value as? [String: Any] {
            try container.encode(dictVal.mapValues { AnyEncodable($0) })
        } else {
            throw EncodingError.invalidValue(
                value,
                EncodingError.Context(codingPath: [], debugDescription: "Value cannot be encoded")
            )
        }
    }
}

/// Standard GraphQL response wrapper.
struct GraphQLResponse<T: Decodable>: Decodable {
    let data: T?
    let errors: [GraphQLErrorMessage]?
}

/// GraphQL error message structure.
struct GraphQLErrorMessage: Decodable {
    let message: String
}

// MARK: - Common Error Types

/// Base protocol for GraphQL client errors.
protocol GraphQLClientError: LocalizedError {
    static func invalidURL() -> Self
    static func encodingError() -> Self
    static func httpError(statusCode: Int) -> Self
    static func decodingError(_ error: Error) -> Self
    static func apiError(_ messages: [String]) -> Self
}

/// Extension to provide default error descriptions.
extension GraphQLClientError {
    var errorDescription: String? {
        // Self already conforms to LocalizedError, so just return nil to use default
        // The concrete type should override this property
        return nil
    }
}

// MARK: - URL Session Configuration

/// Provides standard URLSession configurations for GraphQL clients.
enum GraphQLClientConfiguration {
    /// Standard configuration for Stash client (60s request, 300s resource timeout).
    static func stashConfiguration() -> URLSessionConfiguration {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 60
        config.timeoutIntervalForResource = 300
        config.urlCache = URLCache(
            memoryCapacity: 10 * 1024 * 1024,  // 10 MB
            diskCapacity: 50 * 1024 * 1024       // 50 MB
        )
        return config
    }
    
    /// Standard configuration for StashDB client (30s request timeout).
    static func stashDBConfiguration() -> URLSessionConfiguration {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.urlCache = URLCache(
            memoryCapacity: 10 * 1024 * 1024,  // 10 MB
            diskCapacity: 50 * 1024 * 1024       // 50 MB
        )
        return config
    }
    
    /// Standard configuration for Whisparr client (30s request timeout).
    static func whisparrConfiguration() -> URLSessionConfiguration {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 300
        return config
    }
}

// MARK: - JSON Decoding Utilities

extension JSONDecoder {
    /// Decoder configured for Whisparr/Radarr API responses (ISO8601 dates).
    static var whisparrDecoder: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
    
    /// Standard decoder for GraphQL responses.
    static var graphQLDecoder: JSONDecoder {
        let decoder = JSONDecoder()
        return decoder
    }
}

// MARK: - Shared GraphQL Executor

/// Shared GraphQL request executor for both Stash and StashDB clients.
/// Eliminates code duplication by providing a common execution path.
struct GraphQLExecutor {
    private let session: URLSession
    private let logger: Logger
    
    init(session: URLSession, logger: Logger) {
        self.session = session
        self.logger = logger
    }
    
    /// Executes a GraphQL query and returns the decoded response.
    /// - Parameters:
    ///   - query: GraphQL query string
    ///   - variables: Query variables  
    ///   - url: GraphQL endpoint URL
    ///   - apiKey: API key for authentication
    ///   - acceptedStatusCodes: HTTP status codes to accept (default: 200-299)
    ///   - createEncodingError: Closure to create encoding error
    ///   - createInvalidResponseError: Closure to create invalid response error
    ///   - createHttpError: Closure to create HTTP error
    ///   - createDecodingError: Closure to create decoding error
    ///   - createApiError: Closure to create API error
    /// - Returns: Decoded response of type T
    func execute<T: Decodable, E: Error>(
        query: String,
        variables: [String: Any],
        url: URL,
        apiKey: String,
        acceptedStatusCodes: ClosedRange<Int> = 200...299,
        createEncodingError: () -> E,
        createInvalidResponseError: () -> E,
        createHttpError: (Int) -> E,
        createDecodingError: (Error) -> E,
        createApiError: ([String]) -> E
    ) async throws -> T {
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "ApiKey")
        
        let body: [String: Any] = [
            "query": query,
            "variables": variables
        ]
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        } catch {
            logger.error("Failed to encode request body: \(error.localizedDescription, privacy: .public)")
            throw createEncodingError()
        }
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            logger.error("Invalid HTTP response")
            throw createInvalidResponseError()
        }
        
        guard acceptedStatusCodes.contains(httpResponse.statusCode) else {
            logger.error("HTTP Error: \(httpResponse.statusCode, privacy: .public)")
            if let responseString = String(data: data, encoding: .utf8) {
                logger.error("Response body: \(String(responseString.prefix(500)), privacy: .public)")
            }
            throw createHttpError(httpResponse.statusCode)
        }
        
        do {
            let response = try JSONDecoder().decode(GraphQLResponse<T>.self, from: data)
            if let errors = response.errors {
                logger.error("GraphQL API Errors: \(errors.map { $0.message }.joined(separator: ", "), privacy: .public)")
                throw createApiError(errors.map { $0.message })
            }
            guard let responseData = response.data else {
                logger.error("GraphQL response missing data field")
                throw createDecodingError(NSError(domain: "Missing Data", code: 0))
            }
            return responseData
        } catch let decodingError {
            logger.error("Decoding error: \(decodingError.localizedDescription, privacy: .public)")
            if let jsonString = String(data: data, encoding: .utf8) {
                logger.error("Raw response (truncated): \(String(jsonString.prefix(1000)), privacy: .public)")
            }
            throw createDecodingError(decodingError)
        }
    }
}
